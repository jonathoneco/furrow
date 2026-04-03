"""SDK configuration and initialization for the Agent SDK adapter.

Handles:
- Row discovery (find active .furrow/rows/ directory)
- Schema validation at startup
- Specialist template loading
- Dimension definition loading
- Logging configuration
"""

import json
import logging
import subprocess
import sys
from pathlib import Path

import yaml  # TODO: customize — install pyyaml: pip install pyyaml


logger = logging.getLogger("harness")

STEP_SEQUENCE = [
    "ideate", "research", "plan", "spec", "decompose", "implement", "review"
]


class ConfigError(Exception):
    """Raised when harness configuration is invalid."""
    pass


def _project_root() -> Path:
    """Compute the harness project root directory.

    Returns the parent of the adapters/agent-sdk/ directory tree,
    so relative paths resolve against the project root rather than CWD.
    """
    return Path(__file__).resolve().parent.parent.parent


class HarnessConfig:
    """Work harness configuration and initialization."""

    def __init__(self, work_dir: str | None = None):
        """Initialize harness configuration.

        Args:
            work_dir: Path to the row directory. If None, auto-discovers.

        Raises:
            ConfigError: If no active row found or validation fails.
        """
        self.root = _project_root()
        self.work_dir = Path(work_dir) if work_dir else self._discover_work()
        self._setup_logging()
        self._validate_at_startup()

    def _discover_work(self) -> Path:
        """Find active row by scanning .furrow/rows/*/state.json.

        Returns:
            Path to the active row directory.

        Raises:
            ConfigError: If no active row found.
        """
        work_root = self.root / ".furrow" / "rows"
        if not work_root.exists():
            raise ConfigError("No .furrow/rows/ directory found")

        active_units = []
        for state_file in work_root.glob("*/state.json"):
            try:
                with open(state_file) as f:
                    state = json.load(f)
            except json.JSONDecodeError:
                logger.warning(f"Skipping malformed state file: {state_file}")
                continue
            if state.get("archived_at") is None:
                active_units.append(state_file.parent)

        if not active_units:
            raise ConfigError("No active rows found (all archived)")
        if len(active_units) > 1:
            names = [u.name for u in active_units]
            raise ConfigError(f"Multiple active rows found: {names}")

        return active_units[0]

    def _validate_at_startup(self) -> None:
        """Validate definition.yaml and state.json at startup.

        Calls hooks/lib/validate.sh via subprocess (AC-6.2a).

        Raises:
            ConfigError: If validation fails.
        """
        # Validate definition.yaml
        definition_path = self.work_dir / "definition.yaml"
        if definition_path.exists():
            result = subprocess.run(
                [str(self.root / "hooks" / "lib" / "validate.sh"), "validate_definition", str(definition_path)],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                raise ConfigError(
                    f"definition.yaml validation failed: {result.stderr.strip()}"
                )

        # Validate state.json
        state_path = self.work_dir / "state.json"
        if state_path.exists():
            result = subprocess.run(
                [str(self.root / "hooks" / "lib" / "validate.sh"), "validate_state_json", str(state_path)],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                raise ConfigError(
                    f"state.json validation failed: {result.stderr.strip()}"
                )

    def load_definition(self) -> dict:
        """Load and return definition.yaml."""
        path = self.work_dir / "definition.yaml"
        if not path.exists():
            raise ConfigError(f"definition.yaml not found at {path}")
        try:
            with open(path) as f:
                return yaml.safe_load(f)
        except yaml.YAMLError as e:
            raise ConfigError(f"Malformed YAML in {path}: {e}")

    def load_state(self) -> dict:
        """Load and return state.json."""
        path = self.work_dir / "state.json"
        if not path.exists():
            raise ConfigError(f"state.json not found at {path}")
        try:
            with open(path) as f:
                return json.load(f)
        except json.JSONDecodeError as e:
            raise ConfigError(f"Malformed JSON in {path}: {e}")

    def load_specialists(self) -> dict[str, dict]:
        """Scan specialists/ directory and load all specialist templates.

        Returns:
            Dict mapping domain name to template metadata.
        """
        specialists = {}
        specialists_dir = self.root / "specialists"
        if not specialists_dir.exists():
            logger.warning("No specialists/ directory found")
            return specialists

        for template_path in specialists_dir.glob("*.md"):
            if template_path.name.startswith("_"):
                continue
            # TODO: customize — parse YAML frontmatter from markdown
            domain = template_path.stem  # By convention, filename matches domain
            specialists[domain] = {
                "path": str(template_path),
                "domain": domain,
            }
            logger.info(f"Loaded specialist template: {domain}")

        return specialists

    def load_dimensions(self) -> dict[str, list]:
        """Load eval dimension definitions from evals/dimensions/.

        Returns:
            Dict mapping artifact type to list of dimension definitions.
        """
        dimensions = {}
        dims_dir = self.root / "evals" / "dimensions"
        if not dims_dir.exists():
            logger.warning("No evals/dimensions/ directory found")
            return dimensions

        for dim_file in dims_dir.glob("*.yaml"):
            artifact_type = dim_file.stem
            try:
                with open(dim_file) as f:
                    dims = yaml.safe_load(f)
            except yaml.YAMLError:
                logger.warning(f"Skipping malformed dimension file: {dim_file}")
                continue
            dimensions[artifact_type] = dims if isinstance(dims, list) else []
            logger.info(f"Loaded dimensions for: {artifact_type}")

        return dimensions

    def _setup_logging(self) -> None:
        """Configure logging for the harness."""
        logging.basicConfig(
            level=logging.INFO,
            format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
            stream=sys.stderr,
        )
