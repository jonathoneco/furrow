"""Specialist agent template for the V2 work harness.

This template receives a task assignment, file ownership scope, and curated
context, then executes the deliverable(s) assigned to it.

Usage:
    Instantiated by the coordinator agent — not run directly.
"""

import json
import sys
from pathlib import Path

# TODO: customize — replace with your actual SDK import
try:
    from anthropic import Agent, Anthropic  # noqa: F401
except ImportError:
    print("Install anthropic SDK: pip install anthropic", file=sys.stderr)
    sys.exit(1)


class SpecialistAgent:
    """Executes deliverables within file ownership boundaries."""

    def __init__(
        self,
        work_dir: str,
        deliverable: str,
        specialist_type: str,
        file_ownership: list[str],
        context: dict | None = None,
    ):
        self.work_dir = Path(work_dir)
        self.deliverable = deliverable
        self.specialist_type = specialist_type
        self.file_ownership = file_ownership
        self.context = context or {}

    def run(self) -> dict:
        """Execute the assigned deliverable and return completion status.

        Returns:
            dict with keys: deliverable, status, files_modified, errors
        """
        print(f"Specialist [{self.specialist_type}]: starting {self.deliverable}")

        # Load specialist template for domain priming
        template = self._load_specialist_template()
        if template:
            print(f"  Loaded template: specialists/{self.specialist_type}.md")

        # TODO: customize — implement deliverable execution
        # The specialist should:
        # 1. Read the curated context provided by the coordinator
        # 2. Execute the deliverable per acceptance criteria
        # 3. Write output files atomically (complete files, not partial)
        # 4. Stay within file_ownership boundaries
        # 5. Report completion via return value (filesystem-based)

        result = {
            "deliverable": self.deliverable,
            "status": "completed",  # TODO: customize — set based on execution
            "files_modified": [],   # TODO: customize — list files touched
            "errors": [],           # TODO: customize — list any errors
        }

        # Write result to work directory for coordinator to inspect
        self._write_result(result)
        return result

    def _load_specialist_template(self) -> str | None:
        """Load specialist template from specialists/ directory."""
        template_path = Path(f"specialists/{self.specialist_type}.md")
        if template_path.exists():
            return template_path.read_text()
        print(f"  Warning: no template found for {self.specialist_type}")
        return None

    def _write_result(self, result: dict) -> None:
        """Write completion result atomically."""
        result_path = self.work_dir / f".agent-results/{self.deliverable}.json"
        result_path.parent.mkdir(parents=True, exist_ok=True)
        # Atomic write: write to temp file then rename
        tmp_path = result_path.with_suffix(".tmp")
        tmp_path.write_text(json.dumps(result, indent=2))
        tmp_path.rename(result_path)

    def _check_file_ownership(self, file_path: str) -> bool:
        """Check if a file path falls within the ownership globs.

        TODO: customize — implement glob matching against file_ownership.
        """
        from fnmatch import fnmatch
        return any(fnmatch(file_path, pattern) for pattern in self.file_ownership)
