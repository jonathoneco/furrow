# Definition Shape and Complexity Mapping

## Overview

In V2, the definition.yaml shape drives downstream depth. There are no explicit tiers.
The number of deliverables, their dependencies, and specialist assignments determine
how much work each step produces. This replaces V1's 4-tier classification system
(Fix, Feature, Initiative, Research).

## How Shape Drives Depth

| Shape Signal | Effect |
|-------------|--------|
| Deliverable count | More deliverables = more plan/decompose/review output |
| Dependency chains | Deeper chains = more waves, sequential constraints |
| Specialist diversity | More specialist types = more team coordination |
| File ownership breadth | Broader ownership = more review surface area |
| Gate policy | `supervised` = more human interaction at every boundary |

## Examples

### Minimal: 1 deliverable, no dependencies, no specialist

```yaml
objective: "Fix the login redirect bug"
deliverables:
  - name: login-fix
    acceptance_criteria:
      - "Login redirects to /dashboard after auth"
context_pointers:
  - path: internal/handlers/auth.go
    note: "Contains the redirect logic"
constraints: []
gate_policy: delegated
```

**Downstream effect**: Steps auto-advance trivially. Research confirms the fix is
straightforward. Plan adds nothing beyond the definition. Spec, decompose, and
implement resolve in a single pass. Review checks one deliverable.

### Moderate: 3 deliverables, 1 dependency chain, 2 specialists

```yaml
objective: "Add rate limiting to the public API"
deliverables:
  - name: rate-limiter-middleware
    acceptance_criteria:
      - "Enforces 100 req/min per API key"
      - "Returns 429 with Retry-After header"
    specialist: api-designer
    file_ownership: ["internal/middleware/ratelimit/**"]
  - name: rate-limit-config
    acceptance_criteria:
      - "Configurable limits per endpoint"
    specialist: api-designer
  - name: rate-limit-tests
    acceptance_criteria:
      - "Table-driven tests cover all status codes"
    depends_on: [rate-limiter-middleware]
    specialist: test-engineer
    file_ownership: ["internal/middleware/ratelimit/*_test.go"]
context_pointers:
  - path: internal/middleware/auth.go
    symbols: [AuthMiddleware]
    note: "Follow same middleware pattern"
constraints:
  - "Must not add external dependencies"
gate_policy: supervised
```

**Downstream effect**: Research investigates rate limiting patterns. Plan produces
architecture decisions and a 2-wave execution plan. Spec defines middleware interface.
Decompose assigns 2 specialists across 2 waves (middleware first, tests second).
Implement runs 2 agents. Review evaluates 3 deliverables.

### Complex: 8+ deliverables, multi-wave dependencies, diverse specialists

```yaml
objective: "Migrate authentication from session-based to JWT with OAuth2 providers"
deliverables:
  - name: jwt-token-service
    acceptance_criteria:
      - "Issues and validates RS256 JWTs"
      - "Token rotation with configurable TTL"
    specialist: auth-specialist
    file_ownership: ["internal/auth/jwt/**"]
  - name: oauth2-google
    acceptance_criteria:
      - "Google OAuth2 login flow"
    specialist: auth-specialist
    depends_on: [jwt-token-service]
  - name: oauth2-github
    acceptance_criteria:
      - "GitHub OAuth2 login flow"
    specialist: auth-specialist
    depends_on: [jwt-token-service]
  - name: session-migration
    acceptance_criteria:
      - "Migrates existing sessions to JWT"
      - "Zero-downtime cutover"
    specialist: database-architect
    depends_on: [jwt-token-service]
  - name: middleware-update
    acceptance_criteria:
      - "Auth middleware accepts JWT and legacy session"
    specialist: api-designer
    depends_on: [jwt-token-service]
  - name: api-tests
    acceptance_criteria:
      - "Integration tests for all auth flows"
    specialist: test-engineer
    depends_on: [oauth2-google, oauth2-github, middleware-update]
  - name: migration-tests
    acceptance_criteria:
      - "Migration rollback test"
    specialist: test-engineer
    depends_on: [session-migration]
  - name: auth-docs
    acceptance_criteria:
      - "Updated API documentation for JWT auth"
    specialist: docs-writer
    depends_on: [middleware-update]
context_pointers:
  - path: internal/auth/
    note: "Current auth implementation"
  - path: internal/middleware/auth.go
    note: "Auth middleware to update"
constraints:
  - "Must support both auth methods during migration"
  - "No external auth services (self-hosted)"
gate_policy: supervised
```

**Downstream effect**: Research investigates JWT libraries, OAuth2 patterns, migration
strategies. Plan produces substantial architecture decisions with 4+ waves. Spec
defines interfaces for each component. Decompose creates a detailed wave map with
5 specialists. Implement runs multiple waves sequentially. Review evaluates 8
deliverables across multiple quality dimensions.

## Key Insight

The same 7-step sequence handles all complexity levels. Simple definitions resolve
steps trivially (auto-advance). Complex definitions produce substantial output at
every step. The definition shape IS the complexity signal.
