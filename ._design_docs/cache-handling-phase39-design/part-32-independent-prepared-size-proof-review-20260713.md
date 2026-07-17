# Part 32: independent prepared-size proof review

Date: 2026-07-13
Verdict: REWORK
Scope: design Part 31, implementation Part 71, aligned Parts 29, 30, and 70,
test-plan Part 43, entry documents, index, and current production pressure code

## Decision

The validated `cold_store.prepare()` boundary is the right source for exact
serialized bytes. The natural same-owner exact-first transition and named test
map also close their earlier findings. Three contract gaps still make the
prepared proof impossible to implement without new behavior choices. Manager
acceptance and implementation remain blocked.

## Review checks

| Check | Result | Basis |
| --- | --- | --- |
| Prepared-size boundary | PASS | `server_cache_store_cold::prepare()` closes, flushes, and validates the staging file. `tx_demote_payload()` receives `exact_bytes` before budget admission and victim selection. |
| Record bindings | REWORK | Role, owner, kind, pair, request, step, and component bindings are complete. The generation binding has no executable lifecycle across apply and two production mutations. |
| Calibration and canonical separation | PASS | Measurement values select launch budgets only. Canonical formulas use same-process prepared records and fail on drift. |
| Formula timing | PASS WITH BLOCKER | Resident formula runs before pressure. Serialized checks run at exact and checkpoint preparation, but failure cannot yet stop the current production loop safely. |
| Guarded mutation boundary | PASS | Setup is limited to positive budgets, hot order, and proof expectations. Ownership, links, residency, files, decisions, metrics, and accounting stay production-owned. |
| Natural transition | PASS | `mark_payload_evicted()` processes exact before checkpoint. Cold victim enumeration excludes the incoming owner, so the cold exact sibling cannot make room for its checkpoint. |
| Named evidence | PASS WITH BLOCKER | Part 43 maps controller and route tests for fields, malformed input, staleness, binding mismatch, and the real transition. Staleness assertions need the corrected generation lifecycle. |
| Default-OFF guard | FAIL | Existing live types and route use `LLAMA_STAGE39_LIVE_TEST_SEAM`. Part 71 instead places all new source inside `LLAMA_SERVER_CACHE_TESTS`, which is not the approved route's default-OFF build boundary. |

## Blocking findings

### F39-PSR-01: proof generation lifecycle is contradictory

Part 31 installs expectations from a discovery generation and says each real
preparation boundary matches generation against that expectation. Current
apply consumes the seam, changes hot order and budgets, and advances
`cache_generation_`. Exact demotion then advances it again before checkpoint
preparation. One discovery generation therefore cannot be the required current
generation at either boundary.

The immutable snapshot freezes at checkpoint preparation, before production
records the checkpoint capacity eviction. That eviction advances the same
production generation. A later retrieval that rejects a snapshot whenever the
current generation differs would reject every successful canonical run.

Define separate fields and rules for discovery generation, post-setup pressure
generation, each observed preparation generation, and terminal transition
generation. State which changes are expected, which relation orders them, when
the HMAC snapshot becomes immutable, and what later mutation makes retrieval
stale. Retrieval must accept the one expected checkpoint eviction after the
second capture but reject unrelated mutation and changed-then-restored state.

### F39-PSR-02: boundary failure has no abort path

Part 31 requires mismatch or formula drift to remove the affected prepared file
and stop before admission or capacity eviction. Today `tx_demote_payload()`
returns `false`; `mark_payload_kind_evicted()` then owns final classification,
and `mark_payload_evicted()` continues from exact to checkpoint. A generic
non-capacity failure records `retained_hot`, while a capacity failure can record
`evicted/both_filled` and unlink the descriptor. Neither outcome is a guarded
proof abort.

Specify one guarded terminal status propagated from the capture helper through
`tx_demote_payload()`, `mark_payload_kind_evicted()`, `mark_payload_evicted()`,
and `tx_update()`. It must stop the remaining kind, suppress ordinary capacity
classification for the rejected prepared object, keep already committed
production state intact, and let the control response distinguish pre-pressure
`BLOCKED` from post-pressure `FAIL`. Add exact controller tests for failure at
step 1 and step 2, prepared-file cleanup, no unintended decision or unlink,
and no processing after the abort.

### F39-PSR-03: compile guard does not match the live seam

The current default-OFF CMake option defines `LLAMA_STAGE39_LIVE_TEST_SEAM` for
the controller types, server route, and runtime opt-in. `LLAMA_SERVER_CACHE_TESTS`
is used for lower-level test hooks and is not the live route's build gate.

Place the prepared-proof controller state, request/response schema, capture,
and route under `LLAMA_STAGE39_LIVE_TEST_SEAM`. Use
`LLAMA_SERVER_CACHE_TESTS` only for subordinate fault injection where needed.
Keep route absence in the default build and retain runtime opt-in, loopback,
idle admission, and admin-token checks. Update the compile-off test wording to
name the actual option and macro.

## Closed earlier findings

F39-RPR-01 is closed in principle by capture from the validated prepared object
in the canonical process. F39-RPR-02 is closed by the exact controller, route,
and live-transition names in Part 43. The new findings concern lifecycle and
control flow needed to make that proof executable.

## Handoff

Developer owns documentation correction for F39-PSR-01 through F39-PSR-03.
Return the corrected design, plan, test map, entries, and index for a fresh
independent Architect review. No code, tests, builds, model execution,
coverage, commit, or push is authorized.
