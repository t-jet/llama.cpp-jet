# Stage 24 report 04 product bug fix (D-EXEC-24-01)

Status: ready for Architect review
Date: 2026-06-25
Owner: Developer
Scope: product code fix in `tools/server/server-cache-hybrid.cpp` for
`test-report-20260624-04.md`.

## Trigger

`test-report-20260624-04.md` reports S02-chat and S03-chat as FAIL
(FAIL-http-request) under hybrid cache mode. The native leg on both rows
completes thousands of requests at 99.8 percent nonzero cache_n; the hybrid
leg stalls above the 512 MiB hot budget for hundreds of slot cycles.

S02 hybrid log line 534 ends with:

```text
W srv  mark_payload:  - hybrid cache: demotion failed for payload_id 33, falling back to immediate eviction
I srv        update:  - hybrid cache state: 10 entries, 664.422 MiB payload, 664.424 MiB total, 440 tokens (limits: 512.000 MiB payload, 4096 tokens)
```

S03 hybrid log shows 152 `mark_payload` warnings and 57 `evict_until_`
warnings across 6003 log lines, with the cache state pinned above the
512 MiB hot budget.

## Root cause

`mark_payload_kind_evicted` in `tools/server/server-cache-hybrid.cpp` always
tried `demote_payload` first, even when the cache was already over the hot
budget. `demote_payload` then rejected with
`W srv  demote_paylo: outstanding demotions exceed payload budget for payload_id N`
because `calculate_demoting_payload_bytes() + estimated_cold_bytes > limit_size`,
which is always true once the in-flight demotion queue saturates the hot
budget. The caller logged
`W srv  mark_payload: demotion failed for payload_id N, falling back to immediate eviction`
and proceeded to evict. Each entry's worth of bytes was freed, but the next
entry in the eviction plan hit the same demote gate and the same log noise,
and new saves kept adding entries faster than the demotion worker could
drain them.

Demotion is async: queued demotions do not release hot bytes until the
worker completes the cold-store write. Trying to demote while already over
the hot budget cannot relieve the immediate pressure, so the demote attempt
is wasted work plus log spam.

## Fix scope

Changed file:

```text
tools/server/server-cache-hybrid.cpp
```

Patch (targeted guard inside `mark_payload_kind_evicted`):

```cpp
if (cold_store.is_configured() &&
    descriptor_it->second.residency == payload_residency_state::hot) {
    const bool over_hot_budget =
        hot_payload_budget_enabled() &&
        calculate_resident_payload_bytes() > limit_size;
    if (!over_hot_budget) {
        if (entry.protected_root) {
            n_protected_root_demotions++;
            SRV_WRN(" - hybrid cache: protected root demoted (payload_id=%" PRIu64 ")\n", payload_id);
        }
        if (demote_payload(payload_id)) {
            refresh_entry_payload_accounting(entry);
            return true;
        }
        SRV_WRN(" - hybrid cache: demotion failed for payload_id %" PRIu64 ", falling back to immediate eviction\n",
                payload_id);
    }
}
```

Behavior preserved:

- Demote-first path still runs when the cache is at or below the hot budget,
  so cold-store preservation semantics are unchanged for steady-state work.
- Protected-root demotion warning and `n_protected_root_demotions` counter
  only fire when the demote path runs, matching the prior contract.
- `n_demotion_*` counters and `record_payload_transition` accounting are
  unchanged because the demote path is bypassed, not the demotion budget
  gate.

New regression test:

```text
tests/test-cache-controller.cpp: test_stage24_over_budget_eviction_skips_demote
```

The test reproduces the production stall (8 entries of 100 bytes, hot budget
200 bytes, completion delay 1000 ms) and asserts:

- `resident_payload_bytes <= 200` after the admission burst,
- `n_payload_evictions > 0` so the eviction path actually fires,
- `resident_payload_bytes <= 200` after the worker stops so any in-flight
  demotion attempts surface cleanly through the completion handler.

## Evidence

Build:

```text
cmake --build build-cuda --config Release --target test-cache-controller
Result: PASS
Output: D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
LastWriteTime: 2026-06-25 12:47:21

cmake --build build-cuda --config Release --target llama-server
Result: PASS
Output: D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe
LastWriteTime: 2026-06-25 12:47:45

Source timestamps:
tools/server/server-cache-hybrid.cpp LastWriteTime: 2026-06-25 12:45:32
tests/test-cache-controller.cpp LastWriteTime: 2026-06-25 12:46:33
```

Binary timestamps confirm the test and server binaries are newer than the
edited sources.

Unit tests:

```text
Run: D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
Output: ._test_output/stage24-fix-iter1-20260625-01/test-output.txt

Result:
All tests passed successfully!
Total: 121 tests (... + 1 Stage 24 focused)

Stage 24 new test:
test-cache-controller: Stage 24 over-budget eviction skips demote attempt...
  PASSED
```

The new test is the only addition; the other 120 tests still pass, so the
fix did not regress any existing demotion, eviction, or budget behavior.

## Residual risk

- The fix only addresses the demote/evict interaction under sustained
  over-budget load. It does not change the demotion gate itself, the
  cold-store write path, or the I/O worker throughput.
- The Stage 24 CUDA rerun is the authoritative closure evidence; this fix
  is the minimum product change that should remove the
  `demote_paylo`/`mark_payload` warning cascade and let `evict_until_within_budget`
  drive the cache back under the budget.
- QA must rerun from a fresh suffix to confirm the cache no longer pins
  above the 512 MiB hot budget for S02/S03.

## Handoff

Verdict: ready for Architect review.

QA should rerun Stage 24 from a fresh suffix (`test-report-20260624-05.md`)
after Architect acceptance. The product fix touches one function in one
file; no runner, harness, request generator, or fixture changed.

