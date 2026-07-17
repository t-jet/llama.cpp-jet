# Part 40: independent read-only generation-boundary review

Date: 2026-07-13
Verdict: HISTORICAL PASS; SUPERSEDED BY PART 41
Scope: design Part 39, implementation Part 75, test-plan Part 43, entry
documents, index, and current controller and cold-store code

## Decision

D39-EXEC-14 is implementable as written. The correction removes both
post-exact mutators, validates completed production state under the cache
mutex, aborts before checkpoint work on mismatch, and gives the proof boundary
one guarded generation owner. Manager acceptance may proceed. Code, tests,
builds, model execution, coverage, QA, commit, and push remain blocked until
that gate passes.

## Review checks

| Check | Result | Basis |
| --- | --- | --- |
| Descriptor and entry invariants | PASS | Exact and checkpoint IDs, owners, kinds, pair fields, sizes, checksums, store refs, residencies, hot records, and cached entry projection are readable under `cache_state_mutex_`. Bound session values provide immutable expectations. |
| Branch invariants | PASS | Production demotion already copies both payload links and entry accounting. Checkpoint-first status projection makes exact-cold plus checkpoint-hot state hot, non-metadata-only, and absent-reason none. Validation only reads it. |
| Store and accounting invariants | PASS | Cold byte map, cold gauges, descriptor cold ref, hot map, entry and forest sizes, and pruning counters provide exact read-only accounting. File presence is feasible from public cold root plus canonical hexadecimal `<payload-id>.cold`; no store mutation is needed. |
| Mismatch terminal behavior | PASS | Parts 33, 35, and 39 latch abort before checkpoint preparation and propagate it out of pressure and update loops. No ordinary decision, unlink, pruning, proof retrieval, or later-kind processing is allowed. |
| Generation ownership | PASS | Validation records and rechecks post-exact generation without mutation. Success alone advances once, checks delta one, then binds and arms step 2. Wrong phase, duplicate entry, drift, abort, or overflow fails first. |
| Seam-OFF equivalence | PASS | Validator state, boundary call, observations, and tests stay under `LLAMA_STAGE39_LIVE_TEST_SEAM`. Default builds contain no added generation path. Runtime OFF cannot enter the guarded transaction. |
| Test contract | PASS | Named controller and route cases cover every mismatch class, unchanged failure generation, exact-cold/checkpoint-hot retention, delta one, duplicate rejection, redaction, ordered HMAC fields, tamper rejection, and no double advance. |
| Code feasibility | PASS | Hook fits between exact and checkpoint calls in `mark_payload_evicted()`. `tx_demote_payload()` completes production accounting and branch sync before return; the kind wrapper refreshes entry accounting before the hook. Existing mutator signatures stay unchanged. |

## Finding disposition

F39-GBR-01 is closed. Part 39 supersedes Part 37's post-exact refresh and sync
sequence. Part 75 supersedes the corresponding Part 74 implementation step.
Historical Parts 36 and 38 remain accurate REWORK records.

No blocking or non-blocking findings remain in this review scope.

## Handoff

Manager owns acceptance of D39-EXEC-14. If accepted, Developer may implement
Parts 39 and 75 with the still-binding session, abort, terminal-order, HMAC,
and QA contracts from Parts 33, 35, and test-plan Part 43. Fresh Architect
implementation review remains required before QA.
