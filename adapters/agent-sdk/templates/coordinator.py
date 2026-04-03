"""Coordinator agent template for the V2 work harness.

This template manages the step sequence, spawns specialist sub-agents
per plan.json wave assignments, and handles state transitions.

Usage:
    Customize the TODO sections for your project, then run:
    $ python coordinator.py --work-dir .furrow/rows/<name>
"""

import json
import logging
import subprocess
import sys
from pathlib import Path

# TODO: customize — replace with your actual SDK import
try:
    from anthropic import Agent, Anthropic  # noqa: F401
except ImportError:
    print("Install anthropic SDK: pip install anthropic", file=sys.stderr)
    sys.exit(1)

from callbacks.state_mutation import StateMutator
from config import HarnessConfig, STEP_SEQUENCE

logger = logging.getLogger("harness.coordinator")

# --- Coordinator Agent ---

class CoordinatorAgent:
    """Manages row lifecycle and specialist dispatch."""

    def __init__(self, work_dir: str):
        self.work_dir = Path(work_dir)
        self.config = HarnessConfig(work_dir)
        self.state_mutator = StateMutator(self.work_dir / "state.json")
        self.definition = self.config.load_definition()
        self.state = self.config.load_state()

    def run(self) -> None:
        """Main coordinator loop: advance through steps."""
        current_step = self.state["step"]
        step_idx = STEP_SEQUENCE.index(current_step)

        for step in STEP_SEQUENCE[step_idx:]:
            logger.info(f"--- Step: {step} ---")
            self._execute_step(step)

            if step != "review":
                self._handle_gate(step, STEP_SEQUENCE[STEP_SEQUENCE.index(step) + 1])

        logger.info("Work unit complete.")

    def _execute_step(self, step: str) -> None:
        """Execute a single step."""
        self.state_mutator.update({"step": step, "step_status": "in_progress"})

        if step in ("implement", "review"):
            self._dispatch_specialists(step)
        else:
            # TODO: customize — implement step-specific logic
            # For steps like ideate, research, plan, spec, decompose:
            # call the appropriate agent or logic for this step.
            logger.info(f"  Execute {step} step logic here")

        self.state_mutator.update({"step_status": "completed"})

    def _dispatch_specialists(self, step: str) -> None:
        """Spawn specialist sub-agents per plan.json wave assignments."""
        plan_path = self.work_dir / "plan.json"
        if not plan_path.exists():
            logger.info("  No plan.json found — single-agent execution")
            return

        with open(plan_path) as f:
            plan = json.load(f)

        for wave in plan["waves"]:
            wave_num = wave["wave"]
            logger.info(f"  Wave {wave_num}: {wave['deliverables']}")

            # TODO: customize — spawn specialist agents per wave assignment
            # Each specialist receives:
            # - Task assignment and file ownership
            # - Curated context from specialist template
            # - Skill injection per docs/skill-injection-order.md
            for deliverable_name, assignment in wave["assignments"].items():
                specialist_type = assignment["specialist"]
                file_ownership = assignment.get("file_ownership", [])
                logger.info(f"    Dispatching {specialist_type} for {deliverable_name}")
                logger.info(f"    File ownership: {file_ownership}")

                # TODO: customize — create and run specialist agent
                # specialist = SpecialistAgent(
                #     work_dir=self.work_dir,
                #     deliverable=deliverable_name,
                #     specialist_type=specialist_type,
                #     file_ownership=file_ownership,
                # )
                # specialist.run()

            logger.info(f"  Wave {wave_num} complete — inspecting outputs")

    def _handle_gate(self, from_step: str, to_step: str) -> None:
        """Record gate decision and advance to next step."""
        # Validate gate via shared hook
        boundary = f"{from_step}->{to_step}"
        self._validate_step_boundary(from_step, to_step)

        # TODO: customize — implement gate decision logic
        # For autonomous: use evaluator verdict directly
        # For delegated: present to supervisory agent
        # For supervised: raise (use Claude Code adapter instead)
        from callbacks.gate_callback import decide_gate
        gate_policy = self.definition.get("gate_policy", "supervised")
        gate_record = decide_gate(gate_policy, boundary, evidence="Step completed")

        self.state_mutator.append_gate(gate_record)
        logger.info(f"  Gate {boundary}: {gate_record['outcome']}")

    def _validate_step_boundary(self, from_step: str, to_step: str) -> None:
        """Call hooks/lib/validate.sh for step boundary validation."""
        result = subprocess.run(
            [str(self.config.root / "hooks" / "lib" / "validate.sh"), "validate_step_boundary", from_step, to_step],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            raise RuntimeError(
                f"Step boundary validation failed: {result.stderr.strip()}"
            )

    def _regenerate_summary(self) -> None:
        """Regenerate summary.md at step boundaries."""
        # TODO: customize — implement summary regeneration
        pass


def main() -> None:
    """Entry point."""
    if len(sys.argv) < 3 or sys.argv[1] != "--work-dir":
        print(f"Usage: {sys.argv[0]} --work-dir .furrow/rows/<name>", file=sys.stderr)
        sys.exit(1)

    work_dir = sys.argv[2]
    coordinator = CoordinatorAgent(work_dir)
    coordinator.run()


if __name__ == "__main__":
    main()
