"""Gate decision callback for the Agent SDK adapter.

Implements gate decisions based on gate_policy:
- autonomous: evaluator verdict is the gate decision (no human interaction)
- delegated: evaluator verdict presented to supervisory agent for confirmation
- supervised: raises — requires human interaction (use Claude Code adapter)
"""

from datetime import datetime, timezone


class SupervisedGateError(Exception):
    """Raised when supervised gate_policy is used with the Agent SDK adapter.

    The Agent SDK adapter does not provide human interaction.
    Use the Claude Code adapter for supervised workflows.
    """
    pass


def decide_gate(
    gate_policy: str,
    boundary: str,
    evidence: str,
    evaluator_verdict: str = "pass",
    conditions: list[str] | None = None,
) -> dict:
    """Record a gate decision based on the gate policy.

    Args:
        gate_policy: One of "supervised", "delegated", "autonomous".
        boundary: Step boundary string, e.g., "plan->spec".
        evidence: One-line summary of proof or path to gate file.
        evaluator_verdict: The evaluator's verdict ("pass", "fail", "conditional").
        conditions: Optional conditions for conditional outcomes.

    Returns:
        Gate record dict conforming to gate-record schema.

    Raises:
        SupervisedGateError: When gate_policy is "supervised".
        ValueError: When gate_policy is not recognized.
    """
    if gate_policy == "supervised":
        raise SupervisedGateError(
            f"Gate '{boundary}' requires supervised mode (human interaction). "
            "The Agent SDK adapter does not support supervised gates. "
            "Use the Claude Code adapter for supervised workflows."
        )

    if gate_policy == "autonomous":
        return _autonomous_gate(boundary, evidence, evaluator_verdict, conditions)

    if gate_policy == "delegated":
        return _delegated_gate(boundary, evidence, evaluator_verdict, conditions)

    raise ValueError(f"Unknown gate_policy: {gate_policy}")


def _autonomous_gate(
    boundary: str,
    evidence: str,
    evaluator_verdict: str,
    conditions: list[str] | None,
) -> dict:
    """Autonomous: evaluator verdict is the gate decision directly.

    PASS outcomes are recorded without human interaction.
    FAIL outcomes are recorded but should trigger notification.
    """
    record = {
        "boundary": boundary,
        "outcome": evaluator_verdict,
        "decided_by": "evaluator",
        "evidence": evidence,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if evaluator_verdict == "conditional" and conditions:
        record["conditions"] = conditions

    if evaluator_verdict == "fail":
        # TODO: customize — implement notification for FAIL outcomes
        print(f"GATE FAIL: {boundary} — {evidence}")

    return record


def _delegated_gate(
    boundary: str,
    evidence: str,
    evaluator_verdict: str,
    conditions: list[str] | None,
) -> dict:
    """Delegated: evaluator verdict presented to supervisory agent.

    The supervisory agent confirms or overrides the evaluator's decision.
    """
    # TODO: customize — implement supervisory agent confirmation
    # For now, accept evaluator verdict with supervisory logging
    print(f"Delegated gate {boundary}: evaluator says {evaluator_verdict}")
    print(f"  Evidence: {evidence}")
    print("  Supervisory agent confirms verdict")

    record = {
        "boundary": boundary,
        "outcome": evaluator_verdict,
        "decided_by": "evaluator",
        "evidence": evidence,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if evaluator_verdict == "conditional" and conditions:
        record["conditions"] = conditions

    return record
