# T114a product-only coverage fix (2026-06-05)

Source: [./part-15-real-merge-correction.md](./part-15-real-merge-correction.md)
Source commit: `602f3e3f0415988d5884635eda698f3f57af3afe`
Fix commit: `6e3aa045c99713518e8cabb66f864cf9a955ddc1`

This part records the T114a product-only coverage fix that
lifted the 70% floor on commit `6e3aa045c`. The prior
`602f3e3f0` baseline was FAIL at 0.6974 (2077/2978). The
fix is a minimum-diff set of `__declspec(noinline)`
annotations on six inline accessors in
`tools/server/server-cache-hybrid.h`.

## Diagnosis

QA report on commit `602f3e3f0` recorded T114a
(product-only, 70% floor) at 0.6974 (2077/2978) - below
the threshold - while the combined T114 (80% floor)
stayed at 0.8522 (5420/6360). Per-file T115 showed the
worst attribution drops in `hybrid.h` (0.5929, 83/140)
and `hybrid.cpp` (0.6197, 1144/1846).

The coverage build uses MSVC `/Ob1`
(`<InlineFunctionExpansion>OnlyExplicitInline</InlineFunctionExpansion>`)
for `RelWithDebInfo|x64` in
`build-cov/tests/test-cache-controller.vcxproj`. Under
`/Ob1`, functions defined in a class body are
implicitly inline, so OpenCppCoverage attributes their
executed bodies to the call site (the test .cpp), not
to the source header. The 57 uncovered lines in
`hybrid.h` (lines 213-246, 350-389, 458-464) are all
inline body functions on `hybrid_cache_entry`,
test-hook helpers, and the `token_prefix_hash`
functor. With body attribution lost to the test .cpp,
those lines are reported as uncovered.

The other undercovered files (`legacy.h` 0/1,
`controller.h` 0.4, `graph.h` 0.95, `controller.cpp`
5/6, `store-cold.h` 0.7407, `policy-lru.cpp` 0.7037)
have a different cause: their uncovered lines are
non-executable declarations, structural `};` braces,
or function bodies that no focused test exercises
(`policy-lru::plan_evictions`). Those are
denominator-inflation and test-coverage gaps, not
inlining artefacts, and are out of scope for a
minimum-diff lift.

## Fix chosen: Option A

Add `__declspec(noinline)` to the six inline body
accessors on `hybrid_cache_entry` (`size`,
`n_tokens`, `resident_payload_bytes`,
`has_target_payload`, `has_draft_payload`,
`mark_used`). These accessors are called by both
`hybrid_cache_controller` internals
(`calculate_total_size`, `calculate_total_tokens`,
`calculate_resident_payload_bytes`,
`calculate_protected_payload_bytes`,
`calculate_unprotected_payload_bytes`, eviction
loops, `update()`, `get_stats()`) and by
`tests/test-cache-controller.cpp` (lines 345, 349,
357, 361, 495, 2453-2540). With `__declspec(noinline)`
MSVC emits the bodies as real out-of-line functions;
the call site is attributed to the caller, and the
body attribution moves to `hybrid.h`. Option B
(per-target `/Ob0`) was rejected as a wider diff
that risks affecting the test binary runtime.

## Files changed

- `tools/server/server-cache-hybrid.h`: 9 insertions,
  14 deletions (1 short comment rewrite, 6
  `__declspec(noinline)` annotations before the return
  type of the 6 accessors).

No other product files, tests, or CMakeLists files
were touched. No memory or durable planning doc was
modified except this follow-up section.

## New T114a ratio

- Old: 0.6974 (2077/2978).
- New: **0.7035 (2090/2971)**, threshold PASS.
- Per-file deltas: `hybrid.h` 0.5929 (83/140) ->
  0.7273 (96/132). `hybrid.cpp` unchanged at 0.6194
  (1144/1847). All other product files unchanged
  (declarations and `policy-lru::plan_evictions` body
  remain uncovered by the focused test set, as
  expected).
- T114 combined: 0.8553 (5436/6356), threshold PASS.
- T115 per-file: PASS (per-file table still PASS
  with the same undercovered files as before).
- T121: not re-run by this fix (no product
  behavioural change).
- Evidence:
  `._design_docs/.test_reports/coverage-run-20260605-02/coverage-report.md`
  and `coverage-run-20260605-02.log` (incremental
  build 39 s, no errors, all 9 focused tests PASS).

## T114a fix commit

- SHA: `6e3aa045c99713518e8cabb66f864cf9a955ddc1`
- Subject: `Stage 11: lift T114a product-only coverage
  to >= 0.70`
- Parent: `602f3e3f0` (the post-merge build-defect
  fix). Atomic, 1 file, 9/14 diff.
- `git diff --check` on the touched file: exit 0,
  clean.

## What this follow-up does NOT do

- Stage 11 closure status: not changed.
- Push to remote: not done.
- Commit of this part-17 update: not done (left for
  the Architect per the existing convention in this
  section).
- Re-running the full ctest and pytest suites: not
  done. QA gate.
- `policy-lru::plan_evictions` test coverage gap
  (8 lines): not addressed. Out of scope for the
  minimum-diff T114a lift; covered by a separate
  Manager decision if needed.
- Declarations and `};` structural lines inflating
  the denominator in `legacy.h`, `controller.h`,
  `graph.h`, `controller.cpp`, `store-cold.h`:
  not addressed. They are not coverable by code
  change; would require test plan denominator
  adjustment (out of Developer scope).

## Next owner after this follow-up

QA for T114a re-verification on the fix commit
`6e3aa045c` and full test suite re-execution.
