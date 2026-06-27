# Stage 28 design part 02: Known bug fix design

Status: design; Manager gate decision D28-DESIGN-01 2026-06-26
Date: 2026-06-26
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Owner: Architect (design); Developer (implementation)

## Scope

Fix design for the three known open bugs carried from Stage 27 closure:

1. TP-26-UT6 test artifact (R28-BUG-01).
2. S02 hybrid cold-store metric vs filesystem drift (R28-BUG-02).
3. AddressSanitizer LNK2038 SAL annotation mismatch (R28-BUG-03).

Each fix is documented with: root cause confirmation, minimal fix
design, verification approach, and any precondition needed before the
fix shape is final.

---

## Fix 1: TP-26-UT6 test artifact (R28-BUG-01)

### R28-BUG-01 root cause confirmation

The test file `tests/test-cache-controller.cpp` undefines `NDEBUG` at
line 22 so `assert()` is active in this TU regardless of CMake config.
The Stage 27 closure diagnosis attributed the abort to
NDEBUG-disables-assert, which is correct in spirit but not in fact:
the abort actually fires from explicit `std::abort()` calls at lines
3764-3770 and similar, raised inside the `/GS` runtime guard (Windows
maps `abort()` to `__fastfail(FAST_FAIL_FATAL_APP_EXIT)` = 0xC0000409).

The real root cause is inconsistent abort pattern across the test file:

- Pre-Stage-26 tests: rely on `assert()` alone. With `#undef NDEBUG`,
  these fire in Release and Debug builds.
- TP-26-UT6 (line 3682 onward): uses `if (!cond) { fprintf(stderr,
  "FAIL: ..."); std::abort(); }`. The `std::abort()` on Windows raises
  0xC0000409 via `__fastfail`, distinct from `assert()` which raises
  `SIGABRT` then a different code.

Stage 27 closure passed TP-27-UT-01 because the regression test
deterministically reproduces the demote leak; but TP-26-UT6 aborts at
the explicit `std::abort()` BEFORE the actual fixture setup completes,
so the test infrastructure never reaches the assertion under test.

### R28-BUG-01 minimal fix design

Replace the mixed abort pattern in TP-26-UT6 with a uniform pattern:
every expected-to-fire assertion is wrapped in
`if (!(condition)) { fprintf(stderr, "FAIL: <context>\n"); std::abort(); }`.
This matches the existing test-22/test-23 style in the same file.

Specifically:

1. Line 3707 `assert(stage23_admit_checkpoint_store(...))` -> wrap in
   explicit abort-on-fail.
2. Subsequent `assert(...)` calls in the same test -> matching
   `if (...)` abort pattern.
3. The `printf("  PASSED\n")` at line 3766 stays unchanged.

Affected lines: 3707, 3716-3729, 3736-3751, 3758-3765.
Estimated diff: ~30 lines.

### R28-BUG-01 verification approach

- V1 fix on disk: Select-String verifies the new abort pattern at the
  named lines.
- V2 clean build: `cmake --build build-cuda --config Release --target
  test-cache-controller` exits 0.
- V3 138-test pack passes: full `test-cache-controller.exe` exits 0 with
  "All tests passed successfully!" (vs the current 110 PASS + abort).
- V4 regression: rerun TP-27-UT-01 and Stage 24 -07 rerun unchanged to
  confirm no behavior change in the previously-passing tests.

---

## Fix 2: S02 hybrid cold-store metric drift (R28-BUG-02)

### R28-BUG-02 root cause confirmation (mandatory diagnosis step)

The drift is empirical:

- Filesystem: 5,374,544,424 bytes (5,125.56 MiB), 102 .cold files, all
  exactly 52,691,612 bytes (50.25 MiB per file).
- Metric: `n_cold_payload_bytes` = 526,915,480 bytes (502.5 MiB).
- Per-id map: sum of `cold_payload_bytes_by_id_` values = 502 MiB,
  10 entries (502 MiB / 50.25 MiB per entry).

If all 102 files were tracked in the map, the map total would be 5.12
GiB. So ~92 files have no per-id map entry. These are orphan files.

Three candidate orphan-file paths:

- **Candidate A (early-continue in `cold_budget_make_room`)**: at line
  641 `if (!cold_store.remove(it->second.store_ref.id)) { continue; }`.
  The `continue` skips the per-id erase, leaving the map entry intact.
  But this would INCREASE the metric, not DECREASE it. So this is not
  the orphan source; the actual drift direction (map < disk) requires
  files written without going through the map.
- **Candidate B (write-without-map)**: there may be a code path that
  calls `cold_store.write()` directly without going through
  `complete_demoted_payload`. The `attach_payload_for_tests` debug
  hook at line ~3500 has its own demote path; if exercised in
  production code paths, the file would be written but not tracked.
- **Candidate C (cleanup-loop deletion without map)**: at line 982
  `cold_store.delete_ids(cold_to_delete)` deletes files. The map is
  erased AFTER delete. If delete fails for some ids, `n_deleted <
  cold_to_delete.size()` triggers the descriptor-retained warning at
  line 996, and the map was already erased for ALL of them at line
  990-995. That would leave descriptors pointing at deleted files; not
  orphan files.

The diagnosis step must verify which path produces orphan files. The
simplest way: add a one-shot diagnostic in `cold_budget_allows_write`
or `remove_payload` that logs every `cold_store.remove()` return value
and every `cold_store.write()` call; rerun Stage 24 -07 S02 hybrid; the
log reveals the orphan-file source.

### R28-BUG-02 minimal fix design (after diagnosis)

Once the orphan-file path is identified, the fix is small:

- If Candidate A: the `continue` at line 641 should still erase the
  per-id entry (the entry was stale, file was on disk, the eviction
  did not delete the file but the map should not retain the stale
  claim). Adjust lines 641-646.
- If Candidate B: route the orphan-write path through
  `complete_demoted_payload` so the map and metric stay in sync.
- If Candidate C: re-order the cleanup loop so the map is only erased
  for ids that `delete_ids` actually removed.

Estimated diff: ~20-60 lines depending on diagnosis result.

### R28-BUG-02 verification approach

- V1 fix on disk: Select-String verifies the change at the diagnosed
  line.
- V2 clean build: build exits 0.
- V3 unit test TP-28-UT-01 (NEW): drives the diagnosed path
  deterministically and asserts `n_cold_payload_bytes ==
  sum(cold_payload_bytes_by_id_) == filesystem_bytes`.
- V4 Stage 24 -07 rerun S02 hybrid: filesystem bytes <= 512 MiB budget
  (was 5.37 GiB), per-id map sum equals filesystem bytes (within rounding).
- V5 metric path unchanged for S03 hybrid (PASS-filesystem-fallback
  should remain PASS).

---

## Fix 3: AddressSanitizer LNK2038 mismatch (R28-BUG-03)

### R28-BUG-03 root cause confirmation

MSVC `/fsanitize=address` adds SAL annotation metadata
(`annotate_string`, `annotate_vector`, `annotate_function`) to every
compiled translation unit. The values differ between ASan-instrumented
and non-ASan-instrumented translation units. When static libraries built
without `/fsanitize` are linked into an executable built with
`/fsanitize`, MSVC's incremental linker detects the annotation
mismatch and emits LNK2038 errors.

The side-channel build `build-cuda-asan` adds `/fsanitize=address` to
the `llama-server` target only (via `target_compile_options`), not to
the `ggml-cuda` static library. The 274 mismatches are between every
ggml-cuda object file and llama-server-impl.lib.

### R28-BUG-03 minimal fix design

Three options:

1. **Option A: rebuild ggml-cuda with same `/fsanitize` flags.** Add
   `target_compile_options(ggml-cuda PRIVATE /fsanitize=address)` to
   the side-channel CMakeLists. Adds ~10 lines.
2. **Option B: build the server executable with `--whole-archive`
   linking of ggml-cuda.** Avoids the static-lib boundary. Adds ~3
   lines but changes link semantics for ggml-cuda.
3. **Option C: do not propagate `/fsanitize` to llama-server; instead
   build a separate ASan-only `asan-llama-server` target.** Most
   surgical but largest CMake change (~30 lines) and requires a custom
   main wrapper to invoke the SEH handler.

Recommended: Option A. It is the most isolated change and preserves
the existing build-cuda-asan target name and semantics.

### R28-BUG-03 verification approach

- V1 CMake change on disk: Select-String verifies the new
  `target_compile_options` line in the side-channel CMakeLists.
- V2 clean rebuild: `cmake --build build-cuda-asan --config Release
  --target llama-server` exits 0 (was 274 LNK2038 errors).
- V3 binary functional check: `llama-server.exe --version` exits 0.
- V4 ASan runtime present: `clang_rt.asan_dynamic-x86_64.dll` is in the
  build output directory.
- V5 future ASan tests: TP-26-UT6 can now be re-run with ASan+CUDA
  and will report actual heap errors if any.

---

## Fix coupling matrix

| Fix | Touches test code | Touches production code | Touches build | Touches runner |
| --- | ---: | ---: | ---: | ---: |
| R28-BUG-01 (TP-26-UT6) | yes | no | no | no |
| R28-BUG-02 (cold-store drift) | yes (new test) | yes (1 site, after diagnosis) | no | no |
| R28-BUG-03 (ASan LNK2038) | no | no | yes (CMakeLists) | no |

The three fixes do not couple to each other. They can be implemented
in any order or in parallel. Recommended sequence: BUG-03 first (build
infra), then BUG-01 (test cleanup), then BUG-02 (most complex, with
diagnosis step).

See [part-04](./cache-handling-phase28-design/part-04-verification-plan.md)
for the full verification contract per fix.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
