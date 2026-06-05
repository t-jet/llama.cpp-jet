# Stage 10 implementation plan review gate

Source: [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)
Review date: 2026-06-02
Reviewer: Architect agent
Gate: Implementation plan review
Verdict: REWORK

## Scope and gate status

This review covers the Stage 10 implementation plan only. It does not approve
code changes, test execution, benchmark execution, coverage execution, security
review execution, QA execution, commits, PR text, or reviewer responses.

Implementation remains closed. Manager implementation-plan approval cannot open
until the blocking finding below is corrected and re-reviewed.

## Documents reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-architecture/part-01-method.md`
- `._design_docs/cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `._design_docs/cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-requirements/part-01-status.md`
- `._design_docs/cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- `._design_docs/cache-handling-phase10-design.md`
- `._design_docs/cache-handling-phase10-design/part-01-scope-surfaces-and-prerequisites.md`
- `._design_docs/cache-handling-phase10-design/part-02-observability-security-and-hardening.md`
- `._design_docs/cache-handling-phase10-design/part-03-validation-traceability-and-readiness.md`
- `._design_docs/cache-handling-phase10-design/design-review-gate-01.md`
- `._design_docs/cache-handling-phase10-design/part-04-manager-design-gate.md`
- `._design_docs/cache-handling-phase10-implementation.md`
- `._design_docs/cache-handling-phase10-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase10-implementation/part-02-evidence-plan-and-risks.md`

## Gate checks

| Check | Result | Notes |
| --- | --- | --- |
| Approved design baseline is referenced | PASS | Part 1 binds implementation to the accepted Stage 10 design, design review PASS, and Manager design gate PASS. |
| Implementation remains closed | PASS | Entry doc and parts keep production code, test code, benchmark execution, coverage execution, security review execution, and QA execution closed. |
| Plan can execute without missing decisions | FAIL | See B1. The coverage denominator is defined, but the coverage tool is left as a later selection. |
| Ordered steps cover Stage 10 scope | PASS | Steps cover metric audit, metric completion, diagnostics, startup validation, marker handling, cold-store hardening, descriptor hardening, abuse tests, benchmarks, determinism, coverage, and operator docs. |
| Affected code, doc, and test surfaces are listed | PASS | Primary server files, durable docs, focused C++ tests, Python server tests, and possible benchmark or stress harnesses are named. |
| Evidence plan separates public and internal evidence | PASS | Part 2 separates public HTTP, logs, `/metrics`, direct stats, harness-only evidence, and focused substitute evidence. |
| Benchmark evidence handles 10-02 | PASS | Each benchmark measurement is classified as public Prometheus, structured log, direct stats, or harness-only evidence. |
| Minimal-intrusion handling addresses 10-01 | PARTIAL | Legacy-path touch reasons and the coverage denominator are documented, but the coverage tool required by the approved design is not. |
| Security and hardening plan is complete enough for execution | PASS | OWASP A01, A03, A04, A05, A08, and A09 review items are listed with closure rules; cold-store, descriptor, marker, and unsupported-configuration hardening are covered. |
| Operator documentation is durable | PASS | The plan updates `tools/server/README.md`, `README-dev.md`, bench docs, test docs, and the Stage 10 QA plan only when QA planning opens. |
| Gate hygiene is preserved | PASS | No implementation, QA, commit, PR, or reviewer-response gate is opened by the plan. |

## Findings

### B1 [BLOCKING] Coverage tool is not defined in the implementation plan

The approved design requires the implementation plan to define both the coverage
tool and the coverage denominator before code work starts:

`Stage 10 closes R107 by requiring at least 80% coverage for hybrid-mode code
paths. The implementation plan must define the coverage tool and denominator
before code work starts.`

Part 2 defines the denominator, exclusions, and evidence fields, but leaves the
tool open:

`Coverage target: at least 80% line or branch coverage, using the repo-supported
coverage tool selected before implementation starts.`

That leaves an execution decision outside the reviewed plan. It also leaves the
line-versus-branch fallback undecided until after approval, even though the
design requires the coverage collection method to be reviewed before code work.

Correction: update Part 2 to name the coverage tool and command family to use
for Stage 10, state whether it produces branch or line coverage on the intended
platform, and keep any fallback from branch coverage to line coverage as an
explicit Architect-reviewed exception. The existing denominator and exclusion
rules can remain.

## Decisions

- REWORK: The plan cannot pass while the coverage tool remains a later
  selection.
- PASS: Advisory finding 10-02 is addressed by the benchmark measurement table.
- PASS with B1 caveat: Advisory finding 10-01 is addressed for minimal legacy
  intrusion and denominator scope, but the Stage 10 design also requires the
  coverage tool to be fixed in the implementation plan.
- PASS: The plan covers observability, structured diagnostics, startup
  validation, marker validation, cold-store hardening, descriptor and restore
  validation, abuse and pressure tests, deterministic seams, benchmark evidence,
  security review, operator docs, known risks, and gate hygiene.

## Required corrections

| ID | Severity | Correction | Owner |
| --- | --- | --- | --- |
| B1 | BLOCKING | Name the Stage 10 coverage tool and command family in Part 2, including branch/line capability and any reviewed fallback rule. | Developer |

## Handoff

Handoff state: re-review required.

Next owner: Developer to correct B1 in the implementation plan. After that,
Architect should re-review the plan. Manager implementation-plan approval
remains closed until the re-review passes.
