"""Step transition callback for the Agent SDK adapter.

Handles step advancement:
- Validates gate record exists
- Updates state.json step and step_status
- Regenerates summary.md auto-generated sections
- Loads next step's configuration
"""

import subprocess
import sys
from pathlib import Path

from callbacks.state_mutation import StateMutator


STEP_SEQUENCE = [
    "ideate", "research", "plan", "spec", "decompose", "implement", "review"
]


def advance_step(
    work_dir: str,
    from_step: str,
    to_step: str,
) -> None:
    """Advance from one step to the next.

    Args:
        work_dir: Path to the work unit directory.
        from_step: The step being completed.
        to_step: The step to advance to.

    Raises:
        RuntimeError: If gate validation fails or step sequence is invalid.
    """
    work_path = Path(work_dir)
    state_path = work_path / "state.json"

    # Validate step sequence
    if from_step not in STEP_SEQUENCE or to_step not in STEP_SEQUENCE:
        raise RuntimeError(f"Invalid step: {from_step} or {to_step}")

    from_idx = STEP_SEQUENCE.index(from_step)
    to_idx = STEP_SEQUENCE.index(to_step)
    if to_idx != from_idx + 1:
        raise RuntimeError(
            f"Invalid transition: {from_step} -> {to_step} "
            f"(expected {from_step} -> {STEP_SEQUENCE[from_idx + 1]})"
        )

    # Validate gate record exists via shared hook
    validate_step_boundary(from_step, to_step)

    # Update state.json
    mutator = StateMutator(state_path)
    mutator.update({
        "step": to_step,
        "step_status": "not_started",
    })

    # Regenerate summary.md
    regenerate_summary(work_path)

    print(f"Advanced: {from_step} -> {to_step}")


def validate_step_boundary(from_step: str, to_step: str) -> None:
    """Validate gate record exists for the step boundary.

    Calls hooks/lib/validate.sh via subprocess (AC-6.2a).
    """
    result = subprocess.run(
        ["hooks/lib/validate.sh", "validate_step_boundary", from_step, to_step],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Gate validation failed for {from_step}->{to_step}: "
            f"{result.stderr.strip()}"
        )


def regenerate_summary(work_path: Path) -> None:
    """Regenerate summary.md auto-generated sections.

    TODO: customize — implement summary regeneration.
    The summary should include:
    - Task objective (from definition.yaml)
    - Current state (step, status, deliverable progress)
    - Artifact paths
    - Settled decisions (from gates[] array)
    - Context budget usage
    """
    summary_path = work_path / "summary.md"
    # TODO: customize — read state.json and definition.yaml to regenerate
    print(f"  Summary regeneration: {summary_path}")


def load_next_step_config(to_step: str) -> dict:
    """Load configuration for the next step.

    Returns:
        Dict with step skill path and reference skill paths.

    TODO: customize — implement step config loading from progressive-loading.yaml.
    """
    return {
        "primary": f"skills/{to_step}.md",
        "reference": [],
    }
