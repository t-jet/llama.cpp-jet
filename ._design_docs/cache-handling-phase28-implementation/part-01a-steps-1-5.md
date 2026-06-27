# Stage 28 implementation plan part 1A: ordered steps 1-5

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)
Companion: [part-01b-steps-6-10.md](./part-01b-steps-6-10.md)

This part specifies the 10 ordered implementation steps for Stage 28.
Each step compiles, keeps the existing 138-test suite passing, and
produces auditable evidence in the implementation log. The order
matters: HIGH severity bugs first (smallest first), then diagnosis-
gated bug fixes, then phased async-worker cleanup, then MEDIUM
severity tech debt, then regression sweep.

## Iteration 1: HIGH severity (binding)

4 items: R28-BUG-01, R28-BUG-02, R28-BUG-03, R28-BUG-04.
Iteration 1 estimated total: ~210 lines across 4 files.


## Steps 1-5 (R28-BUG-01..05)

### Step 1: R28-BUG-01 (TP-26-UT6 test artifact)

Smallest, isolated. Test code only. No production code change.

Precondition: Stage 27 test-cache-controller.exe binary is current
(mtime 2026-06-26 15:07:05) and contains the unfixed TP-26-UT6
assert + abort pattern at lines 3707-3765.

Action: in `tests/test-cache-controller.cpp` lines 3707, 3716-3729,
3736-3751, 3758-3765, replace every `assert(condition);` that is
expected to fire in a Release build with explicit

```text
if (!(condition)) { fprintf(stderr, "FAIL: <context>\n"); std::abort(); }
```

Keep the `printf("  PASSED\n")` at line 3766 unchanged.

Rationale: developer improvement memory "NDEBUG silently disables
asserts in Release-build unit tests" is the binding prior. The
`-D NDEBUG` compile flag from CMake's default Release-config
overrides the `#undef NDEBUG` at line 22.

Stop condition:

- `cmake --build build-cuda --config Release --target test-cache-controller` exits 0.
- test-cache-controller.exe runs to completion and prints "All tests passed successfully!" (was abort at 0xC0000409 pre-fix).
- Pre-fix regression check: temporarily revert Step 1, rebuild, confirm abort at the same line, re-apply fix, confirm PASS.

Estimated diff: ~30 lines test code, 0 production lines.

### Step 2: R28-BUG-03 (ASan LNK2038 mismatch)

Build infrastructure fix. CMakeLists change only.

Precondition: side-channel `build-cuda-asan` directory exists and
is configured per D-EXEC-27-09 investigation. Reproduce the
274 LNK2038 errors by attempting a clean rebuild.

Action: in the side-channel `build-cuda-asan` CMakeLists.txt (the
script that builds llama-server with `/fsanitize=address`), add

```text
target_compile_options(ggml-cuda PRIVATE /fsanitize=address)
```

Use the generator expression `$<COMPILE_LANGUAGE:CXX>` to scope the
flag to host compilation only (not nvcc device compilation per
R28-RISK-04).

Stop condition:

- `cmake --build build-cuda-asan --config Release --target llama-server` exits 0 (was 274 LNK2038 errors pre-fix).
- llama-server.exe --version exits 0.
- clang_rt.asan_dynamic-x86_64.dll is present in build-cuda-asan/bin/Release.

Estimated diff: ~10 lines CMake change, 0 production lines.

### Step 3: R28-BUG-02 (cold-store drift diagnosis)

Mandatory one-shot empirical step before fix design. No permanent
code change; diagnostic logging only.

Precondition: Stage 24 -07 S02 hybrid leg evidence is on disk at
`._test_output/stage24-chat-s02-s03-20260626-07/S02-chat/hybrid-stage24/`.
Filesystem shows 5.37 GiB; metric shows 502 MiB; per-id map shows
10 entries.

Action: add one-shot diagnostic logging to
`tools/server/server-cache-hybrid.cpp` at three sites:

1. `cold_budget_make_room` (line ~641): log every
   `cold_store.remove()` return value and every per-id erase.
2. `complete_demoted_payload` (line ~705): log every
   `cold_store.write()` call and its return value, plus the
   per-id map insert.
3. `remove_payload` (line ~904-916): log every map lookup and
   every per-id erase.

Diagnostic logging uses SRV_DBG macro (existing in
server-cache-hybrid.cpp) so it is conditional on cache log
verbosity. NOT LLAMA_SERVER_CACHE_TESTS gated (production path).

Rerun Stage 24 -07 S02 hybrid leg with `--cache-cold-max-mib 512`
and the existing 10-min leg cap. Capture
`D:\tmp\cache-cold-stage28-diag\*.cold` files and the per-leg
server.log and server.err.log.

Stop condition:

- Diagnostic log shows orphan-file path = one of three candidates (early-continue, write-without-map, cleanup-loop delete).
- Filesystem count after rerun matches a clear delta vs pre-step.

If none of the three candidates match, file a new OQ-28-07 with
the actual orphan-file path and stop iter 1 with R28-BUG-02 open
for re-design.

Estimated diff: ~30 lines diagnostic logging, 0 production logic
change (logging only, reverted after diagnosis).

### Step 4: R28-BUG-02 fix design + apply (after Step 3)

Fix shape TBD pending Step 3 diagnosis result.

Precondition: Step 3 has identified the orphan-file path with
diagnostic log evidence.

Action: per design part-02 fix design:

- If Candidate A (early-continue `cold_budget_make_room` line 641): remove the `continue` and unconditionally erase the per-id entry. Net ~5 lines.
- If Candidate B (write-without-map): route the orphan-write path through `complete_demoted_payload` so the per-id map tracks it. Net ~30 lines.
- If Candidate C (cleanup-loop delete-without-map): re-order the cleanup loop so the per-id map is only erased for ids that `delete_ids` actually removed. Net ~10 lines.

Revert Step 3 diagnostic logging after the fix is in place.

Add new unit test TP-28-UT-01 in `tests/test-cache-controller.cpp`
that drives the diagnosed path deterministically and asserts
`n_cold_payload_bytes == sum(cold_payload_bytes_by_id_) == filesystem_bytes`.

Stop condition:

- TP-28-UT-01 passes post-fix.
- Pre-fix regression check: temporarily revert fix, confirm TP-28-UT-01 aborts, re-apply.
- Stage 24 -08 rerun (separate evidence path, see Step 8) shows S02 hybrid filesystem <= 512 MiB budget.

Estimated diff: ~30 lines production + ~50 lines TP-28-UT-01 test.

### Step 5: R28-BUG-04 Phase A (fix prod callers)

Production code fix. Replaces 2 broken async callers with sync
inline tx_promote_payload.

Precondition: Steps 1, 2, 3, 4 must complete first because
R28-BUG-04 prod caller fix needs a clean test pack (Step 1) and
a clean build (Step 2). R28-BUG-02 fix changes the same
production file (server-cache-hybrid.cpp), so Step 4 must land
first to avoid line-number churn in Phase A.

Action: in `tools/server/server-cache-hybrid.cpp`:

1. `load_slot` (line ~4929): replace
   `if (self->promote_payload(selected_payload_id))` with
   `if (self->tx_promote_payload(selected_payload_id))`.
   The tx\_ variant runs the cold read inline under
   `cache_state_mutex_` and updates residency to hot before
   returning. Caller still returns false from load_slot if
   promotion fails (cold-not-configured, checksum mismatch),
   but the descriptor no longer stays in `promoting` indefinitely.
2. `stage23_admit_checkpoint_store` (line ~1875-1899):
   replace the `self->promote_payload(payload_id)` + 6000-iteration
   `process_completions()` wait loop with a single
   `self->tx_promote_payload(payload_id)` call. The 30 s hang
   path disappears because tx_promote_payload is synchronous.

Stop condition:

- `cmake --build build-cuda --config Release --target llama-server` exits 0.
- test-cache-controller.exe runs to completion (138 tests pass).
- Pre-fix regression check: temporarily revert Step 5, confirm Stage 24 -08 rerun shows the 30 s hang on S03 hybrid cold checkpoint restore (was the pre-fix symptom per design part-01 R28-BUG-04 row).

Estimated diff: ~30 lines production, 0 new test code.


## Handoff to part-01b

Steps 6-10 (R28-BUG-04 Phase B deprecation + migration + R28-TD-01..07)
are in [part-01b](./part-01b-steps-6-10.md).

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
