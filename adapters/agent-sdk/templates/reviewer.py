"""Reviewer agent template for the V2 work harness.

This template implements the two-phase review protocol:
- Phase A: artifact validation (structural completeness)
- Phase B: quality review (dimension rubric evaluation)

Usage:
    Instantiated by the coordinator agent — not run directly.
"""

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# TODO: customize — replace with your actual SDK import
try:
    from anthropic import Agent, Anthropic  # noqa: F401
except ImportError:
    print("Install anthropic SDK: pip install anthropic", file=sys.stderr)
    sys.exit(1)

from config import HarnessConfig


class ReviewerAgent:
    """Evaluates deliverables using the two-phase review protocol."""

    def __init__(
        self,
        work_dir: str,
        deliverable: str,
        specialist_type: str,
        correction_cycle: int = 0,
    ):
        self.work_dir = Path(work_dir)
        self.deliverable = deliverable
        self.specialist_type = specialist_type
        self.correction_cycle = correction_cycle
        self.config = HarnessConfig(str(work_dir))

    def run(self) -> dict:
        """Execute two-phase review and write result.

        Returns:
            Review result dict conforming to review-result.schema.json.
        """
        definition = self.config.load_definition()
        deliverable_def = self._find_deliverable(definition)

        # Phase A: artifact validation
        phase_a = self._run_phase_a(deliverable_def)

        # Phase B: quality review (only runs if Phase A passes)
        if phase_a["verdict"] == "pass":
            phase_b = self._run_phase_b()
        else:
            phase_b = {"dimensions": [], "verdict": "fail"}

        # Overall verdict
        overall = "pass" if (
            phase_a["verdict"] == "pass" and phase_b["verdict"] == "pass"
        ) else "fail"

        result = {
            "deliverable": self.deliverable,
            "phase_a": phase_a,
            "phase_b": phase_b,
            "overall": overall,
            "corrections": self.correction_cycle,
            "reviewer": f"reviewer-{self.specialist_type}",
            "cross_model": False,  # TODO: customize — set True for cross-model review
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        self._write_review_result(result)
        return result

    def _run_phase_a(self, deliverable_def: dict) -> dict:
        """Phase A: artifact validation — check structural completeness."""
        acceptance_criteria = deliverable_def.get("acceptance_criteria", [])

        # TODO: customize — implement artifact presence check
        artifacts_present = True  # Check that expected output files exist

        # TODO: customize — evaluate each acceptance criterion
        criteria_results = []
        for criterion in acceptance_criteria:
            criteria_results.append({
                "criterion": criterion,
                "met": True,  # TODO: customize — evaluate criterion
                "evidence": "TODO: provide evidence",
            })

        # TODO: customize — check plan completion
        plan_completion = {
            "planned_files_touched": True,
            "unplanned_changes": [],  # TODO: customize — detect unplanned changes
        }

        all_criteria_met = all(c["met"] for c in criteria_results)
        verdict = "pass" if (artifacts_present and all_criteria_met) else "fail"

        return {
            "artifacts_present": artifacts_present,
            "acceptance_criteria": criteria_results,
            "plan_completion": plan_completion,
            "verdict": verdict,
        }

    def _run_phase_b(self) -> dict:
        """Phase B: quality review — evaluate dimension rubrics."""
        dimensions = self._load_dimensions()

        # TODO: customize — evaluate each dimension
        dimension_results = []
        for dim in dimensions:
            dimension_results.append({
                "name": dim.get("name", "unknown"),
                "verdict": "pass",  # TODO: customize — evaluate dimension
                "evidence": "TODO: provide evidence",
            })

        all_pass = all(d["verdict"] == "pass" for d in dimension_results)

        return {
            "dimensions": dimension_results,
            "verdict": "pass" if all_pass else "fail",
        }

    def _load_dimensions(self) -> list[dict]:
        """Load dimension definitions for the implement step.

        TODO: customize — load from evals/dimensions/{artifact-type}.yaml
        """
        dim_path = self.config.root / "evals" / "dimensions" / "implement.yaml"
        if dim_path.exists():
            # TODO: customize — parse YAML dimensions
            return [{"name": "correctness"}, {"name": "completeness"}]
        return [{"name": "correctness"}, {"name": "completeness"}]

    def _find_deliverable(self, definition: dict) -> dict:
        """Find deliverable definition by name."""
        for d in definition.get("deliverables", []):
            if d["name"] == self.deliverable:
                return d
        raise ValueError(f"Deliverable '{self.deliverable}' not found in definition")

    def _write_review_result(self, result: dict) -> None:
        """Write review result to reviews/ directory atomically."""
        reviews_dir = self.work_dir / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)
        result_path = reviews_dir / f"{self.deliverable}.json"
        tmp_path = result_path.with_suffix(".tmp")
        tmp_path.write_text(json.dumps(result, indent=2))
        tmp_path.rename(result_path)
