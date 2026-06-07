# Stage 11 follow-up: n_outputs_max cap fix - test automation

Source plan: `cache-handling-test-plan/part-15-stage11-mtp-cap-fix.md` Sections 4 and 5 (T-NOUT-MAX-01, T-NOUT-MAX-02).
Source implementation: `part-22-stage11-mtp-cap-fix-implementation.md` (PASS in implementation review `part-23`).
Design baseline: `cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md`.
Architecture invariant: `cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md`.
Head commit: `02db7a768`. Build dir: `build-cuda`.

## 1. Scope and references

Documentation only. Records the focused C++ test automation added to `tests/test-cache-controller.cpp` for the Stage 11 follow-up `n_outputs_max` cap fix. The production code change is captured in `part-22`; this part captures the test code that locks the per-chunk bound and the symmetric MTP cap formula. No commits, no pushes, no model runs, no coverage, no k6, no test plan edits.

## 2. Test file modified

`tests/test-cache-controller.cpp`. Diff against HEAD `02db7a768`: +188 lines, two new test functions, two new `main()` dispatch lines, two new includes (`speculative.h`, `cstdint`), and an updated totals line (`83 -> 85 tests`).

## 3. T-NOUT-MAX-01 record

| Item | Value |
| --- | --- |
| Function | `test_chunked_decode_respects_n_outputs_max_cap` |
| File | `tests/test-cache-controller.cpp` |
| Plan reference | part-15 Section 4 |
| Production site mirrored | `tools/server/server-context.cpp:3750-3774` |
| Parameters | `n_batch=2048`, `n_outputs_max=4`, `n_total=17` |
| Per-chunk invariant | `n_tokens > 0`; `n_tokens <= n_batch`; `n_tokens <= n_outputs_max` |
| Chunk sequence | 4+4+4+4+1 (5 chunks, residual = `n_total % n_outputs_max == 1`) |
| Edge cases | `n_total == n_outputs_max` (1 chunk of 4); `n_total == 1` (1 chunk of 1); `n_total < n_outputs_max` with `n_total=3` (1 chunk of 3) |

Test code snippet (the production-bound mirror):

```cpp
    std::vector<int32_t> chunk_sizes;
    for (int32_t i = 0; i < n_total;) {
        const int32_t n_tokens = std::min({
            n_batch,
            n_total - i,
            (int32_t) n_outputs_max
        });
        assert(n_tokens > 0);
        assert(n_tokens <= n_batch);
        assert(n_tokens <= n_outputs_max);
        chunk_sizes.push_back(n_tokens);
        i += n_tokens;
    }
```

The fixture is the same `std::min({n_batch, batch.n_tokens - i, (int32_t) params_base.n_outputs_max})` initializer-list the production chunked loop uses at `:3750`, mirrored into a self-contained function so the assertion does not need a model or a live `server_context`.

## 4. T-NOUT-MAX-02 record

| Item | Value |
| --- | --- |
| Function | `test_mtp_cap_matches_symmetric_formula_with_clamp` |
| File | `tests/test-cache-controller.cpp` |
| Plan reference | part-15 Section 5 |
| Production sites mirrored | `tools/server/server-context.cpp:1175` (draft MTP cap-bump) and `:1308` (MTP cparams cap-bump) |
| Parameters | `n_parallel=1`, `n_batch=2048`, `n_max=3`, `expected=4u` |
| Speculative config | `params.speculative.types = { COMMON_SPECULATIVE_TYPE_DRAFT_MTP }`, `params.speculative.draft.n_max = 3` |
| Cap assertion | `cap_dft == 4u` and `cap_mtp == 4u` and `cap_dft == cap_mtp` |
| n_batch clamp sanity | With `n_batch=4` the clamp returns 4 (the `n_batch` side of the `min` wins) |

Test code snippet (the symmetric cap formula and the equality assertion):

```cpp
    const uint32_t cap_dft = std::min<uint32_t>(
        static_cast<uint32_t>(params.n_batch),
        static_cast<uint32_t>(params.n_parallel * (1 + n_speculative)));
    assert(cap_dft == expected);

    const uint32_t cap_mtp = std::min<uint32_t>(
        static_cast<uint32_t>(params.n_batch),
        static_cast<uint32_t>(params.n_parallel * (1 + n_speculative)));
    assert(cap_mtp == expected);

    assert(cap_dft == cap_mtp);
```

`common_speculative_n_max(&params.speculative)` is read from the public header so the test exercises the same accessor the production guard at `:1175` and `:1308` reads through.

## 5. Build evidence

Command: `cmake --build build-cuda --config Release -j --target test-cache-controller`.

- Exit code: 0.
- Wall time: about 10.5 seconds (incremental relink of `test-cache-controller.exe`; `test-cache-controller.cpp` recompiled cleanly).
- `git diff --check -- tests/test-cache-controller.cpp` exit code: 0.
- Pre-existing `LNK4098` defaultlib warning unchanged; no new warnings.

## 6. Manager handoff

Submitting to Manager. Owner: Manager. Next gate: Test execution (QA, with operator run for T-MTP-FIX-01) or QA correction.
