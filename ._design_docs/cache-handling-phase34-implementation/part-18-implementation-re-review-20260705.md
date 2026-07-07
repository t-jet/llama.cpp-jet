# Stage 34 implementation re-review: D34-REOPEN-06/07

Status: PASS
Date: 2026-07-05
Stage: 34 (reopened)
Owner: Architect
Scope: Fresh implementation re-review after part 16 REWORK and part 17 rework evidence.

## Inputs reviewed

- `cache-handling-phase34-implementation/part-16-implementation-review-20260705.md`
- `cache-handling-phase34-implementation/part-17-implementation-rework-evidence-20260705.md`
- `cache-handling-phase34-implementation/part-15-implementation-evidence-20260705.md`
- `cache-handling-phase34-implementation/part-14-manager-implementation-plan-gate-20260705.md`
- `cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tests/test-cache-controller.cpp`
- current Stage 34 status/index/tracker edits

## Verdict

PASS. The part 16 blocking findings are fixed.

T-34-PATHB-01 now calls production `tx_save` through
`debug_run_save_transaction_for_tests`, pauses from the test hook reached in
the real post-unlock slow-read section, runs `tx_restore` during that pause,
and proves restore completes before the save is released.

T-34-PATHB-02 now uses two production `tx_save` calls for the same prompt.
Save A pauses in the post-unlock slow-read section, save B admits the entry,
then save A reaches the second lock and dedupes through the production
second-pass branch.

No blocking architectural or implementation findings remain for
D34-REOPEN-06/D34-REOPEN-07.

## Blocking findings from part 16

| Prior finding | Re-review result | Evidence |
| --- | --- | --- |
| T-34-PATHB-01 did not exercise production `tx_save` slow-read relocation | FIXED | Test lines 5681-5742 call `debug_run_save_transaction_for_tests`; `tx_save` reaches the hook at `server-cache-hybrid.cpp:4877-4879` after the first lock scope ends at 4858 and before the second lock at 4914. Restore runs at test lines 5715-5729 while `release_save` is still false. |
| T-34-PATHB-02 did not exercise production second-pass dedupe | FIXED | Test lines 5747-5802 run save A and save B through `debug_run_save_transaction_for_tests`. Save A pauses in the slow-read hook; save B commits; save A is released and increments the test-only second-pass counter at `server-cache-hybrid.cpp:4920-4925`. |

## Code conformance

PASS: `tx_save` keeps the Stage 25 SPLIT shape.

- First critical section: `server-cache-hybrid.cpp:4772-4858`.
- Slow target read section: `server-cache-hybrid.cpp:4863-4894`.
- Slow draft read section: `server-cache-hybrid.cpp:4896-4912`.
- Second critical section with fresh `reentrancy_guard`:
  `server-cache-hybrid.cpp:4914-4918`.
- Second-pass `find_equivalent_entry`: `server-cache-hybrid.cpp:4920`.

PASS: no stale iterator survives the lock release. The first `existing`
iterator is scoped to the first critical section, and the second pass derives a
new iterator after relocking.

PASS: `std::bad_alloc` and size mismatch paths still return before cache
mutation. Target allocation and size checks are at
`server-cache-hybrid.cpp:4870-4893`; draft allocation and size checks are at
`server-cache-hybrid.cpp:4897-4911`.

PASS: budget recheck remains in the existing commit helpers. The second pass
still routes through `materialize_entry_payload` or `admit_entry_with_payload`,
which preserve their `evict_until_within_budget` calls.

PASS: D34-REOPEN-06 idempotent-save behavior is preserved. Hot hits refresh at
`server-cache-hybrid.cpp:4848-4857` and second-pass hot hits refresh at
`server-cache-hybrid.cpp:4920-4930`; cold hits re-materialize in place at
`server-cache-hybrid.cpp:4933-4955`.

PASS: test hooks are test-only. New state and helper bodies are guarded by
`LLAMA_SERVER_CACHE_TESTS`; production builds get only private stubs for the
existing test-helper signature pattern. The forced-target-byte path is
test-only and exists because controller-only tests have no `llama_context`.

PASS: test registration is intact. The five reopened Stage 34 tests are called
from `tests/test-cache-controller.cpp:5860-5864`, and the executable reports
`Total: 149 tests`.

## Non-blocking notes

- T-34-IDEM-01 and T-34-IDEM-03 still use the deterministic commit helper.
  This is acceptable for the implementation gate because T-34-IDEM-02 covers
  production hot first-pass dedupe, the Path B tests now cover production
  `tx_save`, and code review confirms the cold re-materialize branch.
- The Path B tests use `debug_set_tx_save_forced_target_bytes_for_tests` so the
  controller-only test can enter the post-unlock save-read path without a real
  model context. This does not change production behavior and does not weaken
  the lock-order proof, because the hook is reached from production `tx_save`
  between the two cache-mutex sections.
- No model-backed replay was rerun in this focused implementation re-review.
  Manager and QA may decide whether broader replay evidence is needed after the
  implementation gate.

## Commands run

| Command | Exit | Result |
| --- | --- | --- |
| `git diff --check` | 0 | clean |
| `cmake --build build-cuda --target test-cache-controller --config Release` | 0 | built `build-cuda/bin/Release/test-cache-controller.exe` |
| `.\build-cuda\bin\Release\test-cache-controller.exe` | 0 | all tests passed; output included the five reopened Stage 34 tests; total 149 |
| `ctest --test-dir build-cuda -C Release -R cache --output-on-failure` | 0 | 1/1 `test-cache-controller` passed |

## Handoff

State: implementation-re-review-pass.

Next gate: Manager implementation gate. If Manager accepts this PASS, the next
owner should be QA for test-plan update and the focused execution plan for
D34-REOPEN-06/D34-REOPEN-07.
