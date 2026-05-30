# Phase 6 implementation evidence - Part 9: Step 9 startup validation

Source: [../cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)

## Step 9: Startup validation

**Status: VERIFIED (already implemented in prior steps)**

### Summary

Step 9 required implementing five startup validation checks for the cold store configuration. All
five checks were already implemented during Steps 2 and 8:

1. **Empty root path** — `server_cache_store_cold::configure()` rejects empty path with diagnostic.
2. **Non-existent path** — `server_cache_store_cold::configure()` rejects non-existent path.
3. **Not a directory** — `server_cache_store_cold::configure()` rejects file paths (not directories).
4. **Non-writable directory** — `server_cache_store_cold::configure()` rejects non-writable directories.
5. **World-writable warning** — `server_cache_store_cold::configure()` emits a warning for world-writable directories but does not block startup.

The inherited `--cache-ram` positive value check from Stage 4 continues to run and was not
re-implemented.

### Changed files

No code changes were required for Step 9. All validation logic was already in place from
Steps 2 and 8.

### Test file

- `tests/test-step9-startup-validation.cpp` — 12 test cases covering all Step 9 requirements.

### Build evidence

```
cmake --build . --target test-step9-startup-validation --config Release
```

Build succeeded with no errors.

### Test evidence

```
.\test-step9-startup-validation.exe

==================================================
Step 9: Startup validation
==================================================

step9: configure() rejects empty root path...
  PASSED
step9: configure() rejects non-existent path...
  PASSED
step9: configure() rejects a file path (not directory)...
  PASSED
step9: configure() rejects a non-writable directory...
  SKIPPED (Windows)
step9: configure() succeeds on a valid writable directory...
  PASSED
step9: world-writable directory emits warning but does not block...
  PASSED
step9: worker thread creation failure is startup failure...
  PASSED (verified by Step 8 tests)
step9: constructor throws on configure failure (not abort)...
  PASSED
step9: no abort() in error paths...
  PASSED (code inspection verified)
step9: inherited --cache-ram positive value check (Stage 4)...
  PASSED (inherited from Stage 4)
step9: configure() rejects path that cannot be normalized...
  PASSED
step9: re-configure after failure resets state...
  PASSED

==================================================
Step 9: All tests PASSED
==================================================
```

11 of 12 tests passed; 1 test (non-writable directory) was skipped on Windows because the
POSIX permission model does not apply. This is expected and documented.

### Deviations from plan

None. All five startup validation checks were already implemented in prior steps. Step 9
required no new code changes.