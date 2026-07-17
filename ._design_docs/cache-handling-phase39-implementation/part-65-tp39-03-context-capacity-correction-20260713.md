# Part 65: TP-39-03 context-capacity correction

Date: 2026-07-13
Status: CORRECTED; READY FOR FRESH INDEPENDENT ARCHITECT REVIEW
Authority: D39-EXEC-06 and design Part 23

## Correction

Part 64 measured 3,631 source tokens plus 3,632 incoming tokens. Their 7,263
total cannot coexist under the prior 4,096-token controller cap. Parts 19,
60-62, and test-plan Part 43 now require:

- `--ctx-size 8192`, one slot, batch and ubatch 512;
- checked token total 7,263 and minimum coexistence margin 929;
- unchanged 2048 MiB hot and cold measurement budgets;
- 20-minute, 16 GiB RSS, 4 GiB cold-root, and six-chat-request caps per pass;
- exact measurement with no apply, then fresh-process and fresh-root canonical
  measurement before any apply;
- RS checkpoint eligibility plus actual startup and checkpoint evidence.

Per D39-EXEC-07 and design Part 25, measurement does not require a cold set. It
records both complete-pair resident and immutable serialized sizes. Canonical
uses their checked integer MiB startup formula, sends source then incoming, and
discovers before fillers. Lowered apply budgets still come from its snapshot.

## Unchanged implementation contract

No guarded-route security, schema, snapshot binding, complete-set validation,
owner/link compatibility, active-reference check, generation ownership,
rollback order, response redaction, normal selector, or `tx_update()` behavior
changes. TP-39-03 still requires the normal selector to see zero eligible cold
victims after compatible checkpoint reassignment and to emit exactly one
`evicted/both_filled` with zero cold-transaction delta.

Part 64's focused code and test evidence remains the implementation baseline.
Its live result remains BLOCKED and cannot be reclassified as PASS or SKIP.

## Required follow-up

After independent review and Manager authorization, Developer updates only the
driver constants, cap enforcement, token-margin checks, resource capture, and
fresh-pass isolation needed by Part 23. Then rerun seam-ON/OFF builds, controller
and route suites, PowerShell 5 and 7 self-tests, exact measurement, and fresh
canonical TP-39-03. Coverage remains QA-owned.

## Handoff

Ready for fresh independent Architect review with design Part 23 and corrected
Parts 19, 60-62, and 43. No code, test, build, or model run is authorized here.
