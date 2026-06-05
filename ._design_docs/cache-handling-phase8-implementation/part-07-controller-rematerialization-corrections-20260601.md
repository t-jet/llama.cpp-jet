# Stage 8 controller re-materialization corrections - 2026-06-01

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)

## Scope

This pass closes the remaining implementation-gate gaps from Part 6:

- Step 8.6: controller re-materialization and atomic payload save.
- Step 8.7: validation mismatch creates a new branch under the deepest valid parent.
- Step 8.8: equivalent branch admission reuses or re-materializes an existing branch.
- Step 8.10: cold cleanup ownership coverage for retained descendants and retry safety.
- Step 8.11: lifecycle counters and diagnostics coverage for the controller paths above.

## Plan

1. Add controller helpers that validate a selected metadata-only node before attaching a new payload. A failed attach must leave the node metadata-only.
2. Route admission through equivalent-branch lookup before creating a node. Payload-bearing equivalents refresh; metadata-only equivalents re-materialize.
3. On metadata validation mismatch, keep the mismatched node unchanged and create the new branch under the deepest validated parent, or under the namespace root when no segment validates.
4. Extend focused tests in `tests/test-step13-stage8.cpp` for successful and failed materialization, target/draft atomicity, mismatch branch creation, equivalent deduplication, cold cleanup ownership, and Stage 8 counters.
5. Rebuild and rerun the required focused C++ and Python tests, including the Windows server preload workaround if the Python test needs it.

## Progress

- 2026-06-01: Correction plan recorded before code edits.
- 2026-06-01: Added controller admission helpers for equivalent lookup,
  metadata-only re-materialization, mismatch-parent admission, and child branch
  creation.
- 2026-06-01: Added focused Stage 8 tests for successful and failed
  re-materialization, target/draft atomic save, mismatch branch creation,
  equivalent branch reuse, equivalent metadata-only re-materialization, and
  retained-descendant cold cleanup ownership.

## Evidence

Commands run from `D:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-step13-stage8 -j 4
```

Result: PASS. Built `build\bin\Release\test-step13-stage8.exe`.

```powershell
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
```

Result: PASS. `1/1` test passed.

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. Built `build\bin\Release\test-cache-controller.exe`; `1/1`
test passed.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Result: PASS. Built `build\bin\Release\llama-server.exe`.

After a final `server-context.cpp` sync fix, the C++ targets were rebuilt in
one command. After the later LRU-index correction in `server-cache-hybrid.cpp`,
the same command was run again:

```powershell
cmake --build build --config Release --target test-step13-stage8 test-cache-controller llama-server -j 4
```

Result: PASS. All three targets rebuilt.

```powershell
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. Both focused C++ tests passed.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Result: PASS with the existing expected xfail. `3 passed, 1 xfailed`.

```powershell
git diff --check
```

Result: FAIL on CRLF-only trailing-whitespace reports in pre-existing Stage 8
document-index and cold-store additions. The CRLF style was preserved to avoid
large line-ending churn.

```powershell
git diff --check -- tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h tools/server/server-context.cpp tests/test-step13-stage8.cpp ._design_docs/cache-handling-phase8-design.md ._design_docs/cache-handling-phase8-implementation.md ._design_docs/cache-handling-phase8-implementation/part-07-controller-rematerialization-corrections-20260601.md
```

Result: PASS.

## Gate state

The Stage 8 implementation gate is ready for Architect implementation review.
Steps 8.6 through 8.8 now have controller code and focused regression coverage.
The prior 8.10 ownership and 8.11 diagnostics gaps have focused coverage in
`test-step13-stage8`.

Known residual notes:

- The Python metrics run still uses the documented Windows preload workaround.
- `git diff --check` reports CRLF whitespace on pre-existing Stage 8 additions.
  The functional code and focused test diffs added in this pass were checked
  separately and do not add trailing whitespace.
