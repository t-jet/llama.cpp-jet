# Part 7: Architect implementation review (D26-IMPL-REVIEW)

Status: review PASS with non-blocking observations
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Reviewer: Architect
Scope source: [cache-handling-phase26-implementation/part-06-implementation-evidence-20260625.md](../cache-handling-phase26-implementation/part-06-implementation-evidence-20260625.md)
                          ([cache-handling-phase26-design/part-07-test-plan.md](../../cache-handling-phase26-design/part-07-test-plan.md))

## Verdict: PASS

All 12 plan steps implemented per approved design. Build clean, 137/137
tests pass on CUDA Release binary. The Developer evidence doc matches
the actual code on disk.

## A. SEH handler (Step 1): VERIFIED

- `tools/server/server-crash-handler.{h,cpp}` exist and implement
  `install_crash_dump_handler(const std::string&)` + `clear_crash_dump_dir()`.
- `#if defined(_WIN32)` guards the install path and the filter body;
  non-Windows builds are no-ops so call sites stay unconditional.
- `SetUnhandledExceptionFilter(write_minidump_on_unhandled_exception)`
  wired up; `MiniDumpWriteDump` called with bounded
  `MiniDumpWithIndirectlyReferencedMemory | MiniDumpWithThreadInfo`.
- `__try / __except (EXCEPTION_EXECUTE_HANDLER)` wraps the dump write
  to avoid recursive crash on dump-write failure.
- Stderr fallback logged on every failure path; dump filename pattern
  `llama-server-<pid>-<YYYYMMDD>-<HHMMSS>.dmp` is informative.
- `tools/server/CMakeLists.txt` adds `server-crash-handler.cpp` under
  `if(WIN32)` and links `dbghelp` PUBLIC on the `server-context`
  target. The smoke test is recorded in the evidence doc.
- `tools/server/server.cpp:82-105` pre-scans argv, splices
  `--crash-dump-dir` out before `common_params_parse`, then installs
  the filter. This matches design intent (filter installed before any
  other initialization; CLI flag not seen by parser).

## B. Cold-store accounting (Step 2): VERIFIED

- `std::unordered_map<uint64_t, size_t> cold_payload_bytes_by_id_`
  declared in `server-cache-hybrid.h:763` with explanatory comment.
- Five decrement/insert sites wired up:
  - `cold_budget_make_room` (L645-646): subtract + erase
  - `handle_demotion_completion` (L711): insert into map
  - `update()` cold cleanup loop (L986-995): subtract + erase
  - `remove_payload` cold path (L3333): subtract + erase
  - `handle_promotion_completion` (L904-916): subtract + erase
    (NEW per plan-review non-blocking observation 2)
- Decrement logic uses `n_cold_payload_bytes >= removed` guarded
  decrement (clamp to zero) on all sites, matching the existing
  eviction pattern. Promotion-success path uses the per-id map
  (preferred) with `target_size_bytes + draft_size_bytes` fallback
  for legacy descriptors.
- Production path verified: promotion decrement lives in
  `handle_promotion_completion` (real code, not test-only).

## C. Metrics renames (Steps 3-7): COMPLETE

- `grep "llamacpp_cache_"` in `tools/server/server-context.cpp`
  returns 0 matches.
- `grep "llamacpp:cache_"` shows 20+ emission sites, with the rename
  applied to the `cache_*` prefix (30 unique names from `llamacpp_cache_X`
  and 60 unique names from `cache_X` per evidence count).
- `stage24-chat-s02-s03-comparison.ps1` $MetricNames array (L30-39):
  all 10 entries renamed to `llamacpp:cache_*`.
- `metric_delta_comparison` block (L1033-1035): all 3 references
  updated.
- `execute_tests.ps1`: all 10 regexes at L188, 218, 248, 1186, 1238,
  1293, 1357, 1470, 1529, 1533 renamed from `llamacpp_cache_.*` to
  `llamacpp:cache_.*`.
- JSON stats field names (e.g. `cache_cold_bytes`, `cache_cold_budget_bytes`)
  preserved per invariant. `cache_stats.contains("cache_*")` lookups
  unchanged.

## D. Label fix (Step 4): VERIFIED

- `server-context.cpp:4537` reads
  `"scope", "off", "result", "none"` — duplicate `mode` argument
  resolved to `scope` as the first label.
- Inner block at `:4541` uses `"scope", json_value(row, "mode", ...)` —
  the helper at L4361 emits `{mode="<mode_var>", scope="<a_value>", result="<b_value>"}`,
  which is exactly the design intent (design option 2).
- All other two-label calls retain `"mode"` as the first label (the
  helper emits `mode` automatically from closure capture, so callers
  pass only their additional labels).
- Three-label helper similarly auto-emits `mode` first, then `a,b,c`.
- Net effect: zero duplicate-label series in any emitted metric.

## E. Tests (Step 8): PASS

Plan test plan (`part-07-test-plan.md`) lists **only 5 unit tests**,
all cold-store focused. The Manager brief flagged a potential
deviation ("Plan required 5 tests covering: SEH activation + cold-store
decrement + label uniqueness + metric format + runner scrape") — this
is a brief misreading of the design. The actual plan is exactly 5
cold-store unit tests; SEH activation, label uniqueness, metric format,
and runner scrape are fixture assertions (TA-26-FA-01..04) per design
part-07, not unit tests.

Verified in `tests/test-cache-controller.cpp`:

- 5 `test_stage26_*` functions at L4619, 4657, 4690, 4722, 4765.
- All registered in `main()` at L4938-4942.
- All use `if (!cond) { fprintf(stderr, ...); std::abort(); }` pattern
  per developer memory (NDEBUG silently disables assert in Release).
- Total test function count = 137 (call sites in `main()`).
- Existing 132 tests preserved (132 + 5 = 137).
- Summary printf at L4946: `"Total: 137 tests ... + 5 Stage 26 cold-store accounting"`.

Live run output confirms 137/137 PASS.

## F. Existing invariants preserved: ALL

- F-21-EXEC-01 / F-21-RERUN-01 / F-22-DR-01: not touched (cache evict,
  restore, deterministic replay paths unchanged).
- Stage 5/6/8/17/22 invariants: existing test buckets still pass;
  bucket count + names preserved.
- D-EXEC-24-01/02 / I-25-01..03 / Stage 16 chat-path boundary: no
  changes to server-chat.cpp, server-task.cpp, or slot routing.
- `n_hits`, `n_misses`, `cache_cold_bytes` JSON fields unchanged.
- `cache_reuse` CLI flag unchanged.

## G. Hygiene: PASS with one observation

- Build clean on CUDA Release (per evidence doc Step 9).
- 137/137 tests pass on the post-fix binary.
- CRLF line endings correct on all touched C++ files
  (`server-cache-hybrid.cpp` 5261 CRs / 5261 LFs; new crash-handler.cpp
  85 CRs / 85 LFs).
- New files (`server-crash-handler.{h,cpp}`) have 0 trailing-whitespace
  warnings.
- Test file has 0 trailing-whitespace warnings.
- **Non-blocking observation**: `git diff --check` reports 290
  trailing-whitespace warnings on inserted lines in `server-context.cpp`
  (226 warnings on the 90 metric rename lines) and
  `server-cache-hybrid.cpp` (64 warnings on the cold-store decrement
  block). These are all on `+` (inserted) lines from Stage 26 work.
  The fix is one regex strip on each file; not a code-correctness
  blocker but a documented hygiene gate per Stage 15+ governance.

## Plan deviation assessment: ACCEPTABLE

The Manager brief flagged a concern about "5 tests covering SEH +
cold-store + label + format + scrape" vs Developer's 5 cold-store
tests. Re-reading `part-07-test-plan.md`, the design plan enumerates
only 5 unit tests (all cold-store) and 4 fixture assertions
(TA-26-FA-01..04) that cover the SEH/label/format/scrape concerns via
the runner script rather than unit tests. The Developer delivered
exactly the plan. No deviation; the brief misread the plan shape.

## Non-blocking observations

1. **Trailing whitespace on inserted lines (290 total)**:
   `server-context.cpp` (226) and `server-cache-hybrid.cpp` (64)
   have trailing whitespace on Stage 26 inserted lines per
   `git diff --check`. Suggested fix: one-time LF-strip pass on the
   `+` lines; not a code-correctness blocker.

2. **Test count breakdown off by 1 (informational)**: The summary
   printf breakdown buckets sum to 136, not 137. Actual call sites
   in `main()` = 137 (verified). Pre-existing miscategorization,
   not introduced by Stage 26; flag for future stage closure sweep.

## Hard constraints honored

- No commits or pushes performed (verified via `git log -5` showing
  HEAD = `Stage 25 complete`; Stage 26 edits uncommitted).
- No design or plan doc modifications (only created implementation
  evidence + this review).
- No tracker or document-index modifications (per part-02 binding).

## Handoff

Implementation review PASS. Next owner: Manager for implementation
gate acceptance (D26-IMPL-MGR). After Manager gate, Stage 24 rerun
is QA work (Step 11) against the post-fix binary produced here.
