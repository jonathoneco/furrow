"""State mutation utility for the Agent SDK adapter.

Provides safe state.json mutation with:
- Read-modify-write with file locking (prevents concurrent corruption)
- Post-mutation validation via bin/frw.d/lib/validate.sh
- Append-only gate records (never modifies existing records)
- Automatic updated_at timestamp on every write
"""

import fcntl  # Unix-only (Linux/macOS); Windows requires msvcrt or portalocker
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


class StateMutationError(Exception):
    """Raised when a state mutation fails validation."""
    pass


class StateMutator:
    """Thread-safe state.json mutator with file locking."""

    def __init__(self, state_path: str | Path):
        self.state_path = Path(state_path)
        self.root = Path(__file__).resolve().parent.parent.parent

    def update(self, changes: dict) -> dict:
        """Apply changes to state.json with file locking.

        Args:
            changes: Dict of fields to update. Keys must be valid state.json fields.

        Returns:
            The updated state dict.

        Raises:
            StateMutationError: If post-mutation validation fails.
            FileNotFoundError: If state.json does not exist.
        """
        with open(self.state_path, "r+") as f:
            # Acquire exclusive lock — blocks until available
            fcntl.flock(f, fcntl.LOCK_EX)
            try:
                state = json.load(f)

                # Apply changes
                for key, value in changes.items():
                    if key == "gates":
                        raise StateMutationError(
                            "Use append_gate() to modify gates — gates are append-only"
                        )
                    state[key] = value

                # Always update timestamp
                state["updated_at"] = datetime.now(timezone.utc).isoformat()

                # Write back
                f.seek(0)
                f.truncate()
                json.dump(state, f, indent=2)
                f.write("\n")
            finally:
                # Release lock
                fcntl.flock(f, fcntl.LOCK_UN)

        # Validate after mutation
        self._validate_state()
        return state

    def append_gate(self, gate_record: dict) -> dict:
        """Append a gate record to state.json gates array.

        Gate records are append-only — existing records are never modified.

        Args:
            gate_record: Dict conforming to gate record schema.

        Returns:
            The updated state dict.

        Raises:
            StateMutationError: If post-mutation validation fails.
        """
        with open(self.state_path, "r+") as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            try:
                state = json.load(f)

                # Append only — never modify existing records
                if "gates" not in state:
                    state["gates"] = []
                state["gates"].append(gate_record)

                # Always update timestamp
                state["updated_at"] = datetime.now(timezone.utc).isoformat()

                # Write back
                f.seek(0)
                f.truncate()
                json.dump(state, f, indent=2)
                f.write("\n")
            finally:
                fcntl.flock(f, fcntl.LOCK_UN)

        # Validate after mutation
        self._validate_state()
        return state

    def read(self) -> dict:
        """Read state.json with shared lock.

        Returns:
            The current state dict.
        """
        with open(self.state_path, "r") as f:
            fcntl.flock(f, fcntl.LOCK_SH)
            try:
                return json.load(f)
            finally:
                fcntl.flock(f, fcntl.LOCK_UN)

    def _validate_state(self) -> None:
        """Validate state.json after mutation via bin/frw.d/lib/validate.sh.

        Calls the shared validation script via subprocess (AC-6.2a).

        Raises:
            StateMutationError: If validation fails.
        """
        result = subprocess.run(
            [str(self.root / "bin" / "frw.d" / "lib" / "validate.sh"), "validate_state_json", str(self.state_path)],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            raise StateMutationError(
                f"State validation failed after mutation: {result.stderr.strip()}"
            )
