# Stage 19 design part 4: risks, open questions, handoff

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 19 (System-Level Model Warmup Crash Investigation)
Source: [entry doc](../cache-handling-phase19-design.md)

## Risks

| ID | Severity | Description | Mitigation |
| --- | --- | --- | --- |
| R-19-DESIGN-01 | medium | The Stage 18 fix's `if (params_base.cache_ram_mib != 0)` gate is correct for cache-flag paths but does NOT cover the baseline path. The baseline crash (if it reproduces) is a separate issue. | Reproduction test RT1.1 captures this explicitly. |
| R-19-DESIGN-02 | low | The Stage 17 evidence (9933 MiB fit_params vs 1466 MiB baseline) is from a session dated 2026-06-17. The current system state (2026-06-18) may have different memory pressure. | Memory snapshot in RT2 captures current state. |
| R-19-DESIGN-03 | medium | If Branch A is selected, the fix scope depends on the Step 2 crash site evidence. The conditional fix proposal is a starting point; the Developer session may revise. | Conditional fix proposal (Part 2) frames the Developer session's plan scope. |
| R-19-DESIGN-04 | low | If Branch B is selected, the environmental follow-up is a new separate stage. The Stage 19 design does not pre-define the follow-up. | Manager makes the follow-up decision in the closure gate. |

## Open questions

| ID | Status | Description | Disposition |
| --- | --- | --- | --- |
| OQ-19-DESIGN-01 | open | Does the Stage 18 fix's `cache_ram_mib != 0` gate match the user-facing flag behavior? Specifically, when the user passes `--cache-cold-path` without `--cache-ram-mib`, does the parser set `cache_ram_mib` to a non-zero default? | Out of Stage 19 scope; recorded for Stage 20 review. |
| OQ-19-DESIGN-02 | open | Should the Stage 19 design pre-define the fix for each Branch, or wait for evidence and let the Developer session author the fix? | Design pre-defines the conditional fix for Branch A; Branch B and C do not require fixes. |

## Handoff

Next owner: Architect for independent design review in a fresh session.

The Architect reviews this design against:

1. Stage 17 D17-EXEC-02 disposition (baseline crash evidence).
2. Stage 18 D18-CLOSURE-01 substantive finding (validation ordering).
3. The Stage 19 question's three-branch disposition.
4. The reproduction plan's evidence capture and run matrix.
5. The root cause analysis Step 1-3 verification commands.
6. The fix proposal's conditional scope for Branch A only.
7. The test plan rows' tier distribution (3 integration, 1 focused).
8. The closure criteria's five-point checklist.
9. The traceability table's source-decision coverage.
10. The risks and open questions' severity and mitigation.

The Architect returns PASS or REWORK with findings. On PASS, the
Manager advances Stage 19 to the Developer session for reproduction
execution.

The implementation, test plan, and follow-up stages are NOT in scope
for the design review. The Architect does not author code, run builds,
run tests, commit, push, or open PRs per AGENTS.md.

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable doc cap.
