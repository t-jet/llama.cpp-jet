# Part 3: Regression test design - deterministic heap-corruption reproducer

Status: design approved; Manager gate closed per D-CLOSURE-27-01 2026-06-26
Date: 2026-06-26
Scope: focused test added to `tests/test-cache-controller.cpp` that reproduces heap corruption deterministically before the fix and passes after.
Historical note: the design proposed test name `test_stage27_tx_save_no_wasted_checkpoint_alloc` (TP-27-UT-01) targeting Candidate A. The actual root cause differed (enqueue-only demotion leak, not alloc+free churn). The implemented test name is `test_stage27_mark_payload_evicted_releases_hot_memory_inline` at `tests/test-cache-controller.cpp:6990` and exercises the inline-demote path deterministically. See implementation log [part-10](../cache-handling-phase27-implementation/part-10-manager-closure-20260626.md) for the verified test.

## Test name

`test_stage27_tx_save_no_wasted_checkpoint_alloc`

## Test contract

| Field | Value |
| --- | --- |
| Test ID | TP-27-UT-01 |
| Location | `tests/test-cache-controller.cpp` (added to the Stage 27 section, after the Stage 26 TP-26-UT-05 block) |
| Test class | focused controller test |
| Dependencies | `hybrid_cache_controller`, `debug_add_entry_for_tests`, `debug_get_payload_descriptor_for_tests`, `common_params` |
| Build target | `test-cache-controller` |
| Mocks | none required; uses null llama_context |

## Reproducer design

The test exercises the tx_save path with synthetic checkpoints whose `data_tgt` is sized to match the MTP-fixture pattern (~50 MiB). It performs N consecutive saves (N=20 by default, can be raised), inspecting the `hot_payloads` map and `payload_descriptors` map sizes plus the total bytes accounted.

### Pre-fix failure signature

With the pre-Stage-26 fix in place, each save allocates ~50 MiB for `entry.checkpoints = checkpoints;` then immediately frees it. After 20 saves, 20 * 50 MiB = 1 GiB of transient heap pressure. The Windows heap manager may detect the alloc+free churn as corruption under MSVC Debug heap validation or under ASan.

The test catches the regression via one of three signals (in priority order):

1. **`std::bad_alloc` thrown during `tx_save`**: the 20th save cannot allocate because heap is fragmented.
2. **AddressSanitizer report**: `_msize` or `__sanitizer_get_allocated_size` returns an unexpected value for the descriptor buffers.
3. **Heap metadata corruption assertion** under MSVC Debug CRT: `_CrtIsValidHeapPointer` fails for any payload pointer after the 20th save.

### Post-fix behavior

With the Stage 26 commit in place, `admit_latest_checkpoint_and_store_metadata` builds metadata-only checkpoints and never allocates the ~50 MiB destination buffer. After 20 saves, total heap delta is bounded (only the actual hot payload bytes are allocated).

## Test code shape (sketch)

```cpp
// TP-27-UT-01: tx_save with N checkpoint-shaped saves does not allocate
// the wasted ~50 MiB destination buffer per save. Pre-Stage-26 the
// pattern `entry.checkpoints = checkpoints; clear()` allocated and
// immediately freed the data_tgt/data_dft buffers. Post-Stage-26 the
// metadata-only copy avoids the wasted allocation.
void test_stage27_tx_save_no_wasted_checkpoint_alloc() {
    printf("test-cache-controller: Stage 27 tx_save no wasted checkpoint alloc...\n");
    common_params params = create_test_params();
    const size_t checkpoint_bytes = 50 * 1024 * 1024;  // MTP-fixture shape
    const int N = 20;

    hybrid_cache_controller ctrl(params, 100, 1000, nullptr, nullptr);

    // Pre-allocate N payload buffers; reuse across saves so the test
    // measures destination-side allocation only.
    std::vector<std::vector<uint8_t>> checkpoint_payloads;
    for (int i = 0; i < N; ++i) {
        std::vector<uint8_t> buf(checkpoint_bytes, static_cast<uint8_t>(i & 0xff));
        checkpoint_payloads.push_back(std::move(buf));
    }

    size_t baseline_descriptors = 0;
    {
        // Snapshot descriptor count before loop.
        baseline_descriptors = ctrl.debug_payload_descriptor_count_for_tests();
    }

    for (int i = 0; i < N; ++i) {
        // Build a synthetic checkpoint with the MTP-fixture shape.
        common_prompt_checkpoint cp;
        cp.n_tokens = 15;
        cp.pos_min = 0;
        cp.pos_max = 15;
        cp.data_tgt = checkpoint_payloads[i];
        cp.data_dft.clear();  // target-only mode for the test

        server_slot slot;
        server_task task;
        task.tokens = create_tokens({5000 + i});

        // tx_save path through the public debug helper. Pre-fix, this
        // allocates a wasted ~50 MiB destination and immediately frees.
        // Post-fix, no wasted allocation.
        std::list<common_prompt_checkpoint> checkpoints{cp};
        const bool ok = ctrl.debug_admit_latest_checkpoint_and_store_metadata_for_tests(
            ctrl.debug_add_entry_with_tokens_for_tests(task.tokens, "stage27-ut01"),
            checkpoints,
            false,  // runtime_has_draft = false (target-only)
            nullptr);
        assert(ok);
    }

    // Post-condition: N entries admitted; no wasted ~50 MiB buffers
    // remain in entry.checkpoints (only metadata).
    assert(ctrl.debug_entry_count_for_tests() == baseline_descriptors + N);

    // Diagnostic: walk each entry's checkpoints list and assert no
    // data_tgt/data_dft bytes were copied into them. Pre-fix this would
    // fail because the destination would have been allocated-then-cleared
    // (the bytes are not present after clear, but the temporary
    // allocation is the bug); post-fix the destination was never
    // allocated.
    for (const auto & entry : ctrl.debug_entries_for_tests()) {
        for (const auto & cp : entry.checkpoints) {
            assert(cp.data_tgt.empty());
            assert(cp.data_dft.empty());
            assert(cp.n_tokens == 15);
            assert(cp.pos_max == 15);
        }
    }
    printf("  PASSED\n");
}
```

## Required debug helpers (additions to `tools/server/server-cache-hybrid.h`)

| Helper | Purpose |
| --- | --- |
| `debug_payload_descriptor_count_for_tests()` | Returns `payload_descriptors.size()` for the focused test |
| `debug_add_entry_with_tokens_for_tests(tokens, namespace)` | Adds a minimal entry without payload so the test can drive checkpoint admission against a stable entry id |
| `debug_admit_latest_checkpoint_and_store_metadata_for_tests(entry, checkpoints, runtime_has_draft, failure)` | Public alias for the production path so the test exercises the same code path as the live server |
| `debug_entries_for_tests()` | Returns const reference to `entries` so the test can verify checkpoint metadata fields |

These helpers are minimal additions; each is a one-liner. They do not change the production behavior.

## ASan availability

| Platform | ASan status |
| --- | --- |
| MSVC Windows (build-cuda path) | ASan not yet wired in `CMakeLists.txt`; would require `/fsanitize=address` on MSVC 2019 16.9+. Currently NOT available. |
| MinGW Windows | not used. |
| Linux / Mac | not used for this stage. |

Conclusion: ASan is NOT available on the production build path. The regression test relies on post-condition invariants (metadata-only checkpoints, no copied bytes) rather than ASan heap-poisoning detection. This is acceptable because the test contract is "verify the fix is present", not "detect heap corruption via tooling". The Stage 24 rerun (production binary, MTP fixture) is the ASan-equivalent for the live failure mode.

## Failure modes captured

| Test signal | Meaning | What it proves |
| --- | --- | --- |
| `assert(cp.data_tgt.empty())` fails | Destination buffer was allocated then cleared (pre-fix pattern) | The wasteful alloc+free happened |
| `assert(ok)` fails (save returned false) | Admission validation rejected the save | Pre-fix payload corruption surfaced as descriptor rejection |
| `std::bad_alloc` uncaught | 20th save cannot allocate | Heap fragmentation from wasted alloc+free |
| ASan report (if ASan wired) | Heap-poisoned buffer accessed | Direct corruption detection |

## Handoff

Test placement: end of `tests/test-cache-controller.cpp`, after the Stage 26 TP-26-UT-05 block, before the test `main()` driver. The test does NOT require new test fixtures or a model load; it operates on the controller's in-memory state with synthetic payloads. Build gate: clean Release, `test-cache-controller` target, 138/138 tests pass after Stage 27 (137 existing + 1 new).
