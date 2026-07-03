# Stage 34 implementation-plan review 2026-06-30

VERDICT: PASS

## Scope and gate status

Review subject:

- `._design_docs/cache-handling-phase34-implementation.md`
- Accepted Stage 34 design:
  `._design_docs/cache-handling-phase34-design.md`
- Independent design review:
  `._design_docs/cache-handling-phase34-design/part-01-design-review-20260630.md`
- Manager design gate:
  `._design_docs/cache-handling-phase34-design/part-02-manager-design-gate-20260630.md`
- Stage tracker row 34 and `._design_docs/document-index.md`

Gate status: PASS. The implementation plan is ready for Developer code work.

Findings:

- Blocking: 0
- Non-blocking: 0

## Review decisions

| Check | Decision |
| --- | --- |
| Approved design baseline | PASS. The plan cites the Stage 34 design PASS, independent design review PASS, Manager design gate PASS, Manager intake, and binding Stage 17, 25, 31, 32, and 33 decisions. |
| D34-OQ-01 through D34-OQ-05 | PASS. The plan fixes each open question with concrete JSONL schemas, metadata placement, no-pinning decision plus proof/test obligation, prefix-candidate-only scope, and analyzer-derived hot/cold budgets. |
| Ordered steps | PASS. Parser, renderer, expected-hit analyzer, runner, result analyzer, bounded diagnostics, C++ tests, harness tests, and evidence logging are in an executable order. |
| Affected files | PASS. Listed production surfaces match current cache metadata, task, restore, and metrics code. Harness and test paths are plausible and contained under existing documentation/test areas. |
| No-code-yet boundary | PASS. The plan explicitly forbids production, harness, fixture, test, live replay, evidence, commit, and push work during this gate. Current Stage 34 artifacts are docs only. |
| Namespace exclusion | PASS. Branch/session/agent data stays in harness sidecars or ignored `metadata.stage34` request metadata. The plan preserves the Stage 31 rule that prompt-local identity cannot enter the compatibility namespace. |
| Exact restore only | PASS. Stage 34 does not implement safe prefix restore. Prefix continuations stay `unsafe_prefix_rejected` or another bounded prefix-candidate reason unless an exact parent-state match exists. |
| Restore-plan lifetime | PASS. The no-pinning decision is backed by current `cache_response` deep-copy behavior and by required C++ regression coverage for eviction/demotion after plan capture. |
| Budget model | PASS. Hot budget starts from active branch tips plus duplicate burst needs and rounds up with a 2048 MiB floor. Cold budget must hold expected exact candidates or mark rows `EXPECTED-COLD-MISS` before live execution. This avoids the Stage 33 fixed-512 MiB mismatch. |
| Evidence plan | PASS. Evidence covers clean build, cache tests, targeted Python tests, synthetic parser/analyzer/replay, real transcript dry-run, live Qwen MTP replay only after exact resident-hit prediction, metrics, cold-store proof, log scans, and markdown hygiene. |
| Risks and rollback | PASS. Fallbacks are specific: transcript incompleteness, prefix-only opportunities, budget resizing, sequential versus concurrent comparison, bounded diagnostics, and follow-up pin/refcount design if deep-copy proof fails. |

## Code-surface feasibility notes

- `tools/server/server-cache-hybrid.cpp` computes namespace from runtime
  compatibility plus `prepared_prompt_metadata.compatibility_key`, so Stage 34
  must keep branch/session data out of that compatibility key.
- `tx_restore` holds the cache mutex while selecting a candidate and copies
  `payload->target` and `payload->draft` into `cache_response`.
- `try_restore_from_cache` applies `plan.target_bytes` and `plan.draft_bytes`
  outside the cache mutex, then finalizes through `tx_apply_restore`.
- Existing miss reasons include `unsafe_prefix_rejected` and
  `payload_unavailable`, matching the plan's required classifications.

## Required corrections

None.

## Handoff

State: ready for Developer implementation.

Next owner: Developer.

Next gate: implementation, then implementation review before QA test planning.
