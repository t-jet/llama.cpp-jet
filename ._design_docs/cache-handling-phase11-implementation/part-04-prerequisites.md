# Stage 11 prerequisite: run_coverage.ps1 T114a change

Source: [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)

## Status

Planning date: 2026-06-04
Plan state: drafted.
Prerequisite state: PASS, 2026-06-04.
Implementation state: closed.
Pre-merge analysis state: in progress, 2026-06-04.

## Prerequisite status

The `run_coverage.ps1` T114a prerequisite gate closed PASS on 2026-06-04.
The Developer applied the script change that adds the
`## Product-only result` block to `coverage-report.md` per test plan
Part 13. The Architect review verdict is PASS, recorded in
[part-06-architect-prereq-script-review-gate-01.md](part-06-architect-prereq-script-review-gate-01.md)
with the verification commands and per-area gate checks. The Manager
closure record for the prerequisite gate is the implementation log entry
doc, dated 2026-06-04.

The Stage 11 merge activity Step 1 (pre-merge analysis) is now
unblocked. The T114a verdict has a `## Product-only result` block to
cite when the regression rerun in Step 5 records the coverage row.

## Upstream reference verification

Per the Manager plan-change decision recorded in the entry doc on
2026-06-04, the upstream reference is the local `upstream_master`
tracking branch. The Developer verifies the branch is current before
the merge opens. The verification commands and outputs are below.

### Verification commands and outputs

| # | Command | Observed output |
| --- | --- | --- |
| 1 | `git rev-parse upstream_master` | `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50` |
| 2 | `git log -1 --format='%H %ai %s' upstream_master` | `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50 2026-06-04 10:58:13 +0300 readme : add status badges (#24104)` |
| 3 | `git merge-base cache-optimization upstream_master` | `40d5358d3c730b81729ba81cd5c44ed596d02510` |
| 4 | `git log --oneline cache-optimization..upstream_master` count | 225 commits |
| 5 | `GET https://api.github.com/repos/ggml-org/llama.cpp/commits/master?per_page=1` SHA | `4586479852e40f0ce8d4a38b8ec3b98c042d5a04` |
| 6 | GitHub tip subject and date | `webui: fix tool selector toggle/counter, key tools by stable identity (#24065)` at `2026-06-04T11:09:49Z` |
| 7 | `GET .../compare/6ddc9430b...master` status, ahead, behind | `status: ahead, ahead_by: 5, behind_by: 0, total_commits: 5` |

### Staleness check result

The local `upstream_master` is **5 commits behind** the actual
`ggml-org/llama.cpp` upstream `master` branch. The 5 missing commits
between local tip `6ddc9430` and GitHub tip `458647985` are:

| # | SHA (short) | PR | Subject | Files touched |
| --- | --- | --- | --- | --- |
| 1 | `e3ba22d6` | #24091 | fix(mtmd): handle Gemma 4 audio projector embedding size | `tools/mtmd/clip.cpp` |
| 2 | `7ac5a422` | #24053 | cmake: skip cvector-generator and export-lora when CPU backend is disabled | `tools/CMakeLists.txt` |
| 3 | `00664040` | #24089 | server: add header to `tools/server/server-http.h` | `tools/server/server-http.h` |
| 4 | `4d742877` | #23974 | build: use umbrella Headers directory for XCFramework module map | `build-xcframework.sh` |
| 5 | `45864798` | #24065 | webui: fix tool selector toggle/counter, key tools by stable identity | `tools/server/server-http.h` (1 line), `tools/ui/...` |

None of the 5 missing commits match the file-glob groups in design
Part 2 except for two: commit #3 (`00664040`) and the `server-http.h`
line in commit #5 (`45864798`). Both add `#include <unordered_map>` to
`tools/server/server-http.h`. The first adds the include header
declaration; the second adds the same include as a build-time check.
The functional impact is null because the include was already
available transitively.

The remaining 4 of 5 missing commits touch only `tools/mtmd/clip.cpp`,
`tools/CMakeLists.txt`, `build-xcframework.sh`, and `tools/ui/...`,
which are outside the file-glob groups in design Part 2.

### Staleness risk and recommended action

The 5-commit gap is a risk because the merge will integrate the
content of the local `upstream_master` only. The 5 missing upstream
commits are not in the merge range and will not be reviewed in the
pre-merge analysis. The Manager decides whether to:

1. Fetch and fast-forward `upstream_master` from
   `https://github.com/ggml-org/llama.cpp.git` `master` before the
   merge opens, re-running the pre-merge analysis on the refreshed
   range. This is the safer choice and is the recommended default.
2. Merge with the current 5-commit gap and re-sync `upstream_master`
   after the merge closes. The merge log records the 5-commit gap
   as a known gap with a follow-up owner.

The Developer records the chosen path in the merge log when Step 3
opens. The pre-merge report is built on the current local range
(225 commits) and is consistent with the local
`upstream_master` as it stands on 2026-06-04.

### Local reference state

- Current branch: `cache-optimization` at merge base
  `40d5358d3c730b81729ba81cd5c44ed596d02510`
- Local integration branch: `cache-optimization`
- Local tracking branch for upstream: `upstream_master` at
  `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50`
- Local working tree contains uncommitted edits to
  `run_coverage.ps1`, the cache-handling docs, and the
  self-improvement memory files. The working tree is otherwise
  consistent with the merge base for the file-glob groups in design
  Part 2.

## Why this is a prerequisite

The test plan Part 13 split T114 into T114 (combined 80% on the
19-file hybrid-mode denominator) and T114a (product-only 70% on the
11 product files named in the Architect review Finding B). Both
rows are closure contracts from Stage 11 onward.

The T114a row requires the focused exporter coverage script
`._design_docs/cache-handling-test-scripts/run_coverage.ps1` to emit
a new `## Product-only result` block in `coverage-report.md` after
the existing `## Combined result` block. Without the new block, the
T114a verdict has no artifact to cite and the Stage 11 test report
fails the citation rule from design Part 5.

The Stage 10 closure record deferred this change as a Developer-owned
follow-up. The T114 split is forward-looking, and the script change
is the only artifact that makes the T114a row evidence-citeable.
Stage 11 cannot run a valid regression without the change in place.

## What the change does

The script change keeps the existing 19-file per-file table and the
existing `## Combined result` block. The change adds a new
`## Product-only result` block after the combined block.

The new block:

1. Filters the per-file table rows to the 11 product files named in
   the test plan Part 13 product-only denominator table.
2. Sums the per-file `Covered` and `Valid` line counts across the
   11 product files.
3. Computes the product-only line rate as `Covered / Valid`, rounded
   to four decimal places, matching the combined rate format.
4. Reports a verdict of `PASS` when the product-only rate is at or
   above 0.70, `FAIL` otherwise.
5. Writes the block with the same marker style as the combined
   section: a heading, three bulleted lines (line rate, covered X / Y,
   threshold verdict).

The required output sample from the test plan Part 13:

```text
## Product-only result

- Product-only line rate: 0.704
- Product-only covered: 2097 / 2978
- 70% threshold: PASS
```

The sample numbers are the Stage 10 closure values. Real values
change with each coverage run.

## What the change does not do

- No entry is added to or removed from `$srcPatterns`,
  `$denomBasenames`, or `$focusedTests` in this gate.
- The per-test loop keeps the 9 focused tests as they are after the
  C1 and C2 follow-ups.
- The HTTP probe keeps the existing model-backed configuration.
- The HTML export and Cobertura XML export keep the existing outputs.
- The citation rules in the test plan Part 13 are not changed by this
  gate; the citation rules are part of the test plan, not the
  script.

## Why this is a separate Developer gate, not Step 0 of the merge activity

The merge activity is the integration event that re-syncs the fork
with `upstream_master`. The script change is a Developer-owned
maintenance follow-up that does not touch the upstream merge, the
rework Stage N workflow, the regression rerun, or the merge log.

The two activities have different:

- Owners: the merge activity is Developer-led with Architect review
  and Manager approval. The script change is Developer-only with a
  focused review.
- Inputs: the merge activity reads the upstream ref and the file-glob
  groups. The script change reads the test plan Part 13 required
  script behavior.
- Outputs: the merge activity produces the pre-merge report, the
  merge log, and the test report. The script change produces a
  revised `coverage-report.md` with the new block.
- Gates: the merge activity is gated on the design and the
  implementation-plan review. The script change is gated on the
  focused review by the Developer and a quick Architect sanity
  check that the new block is in the report.

Placing the script change as Step 0 of the merge activity would
pollute the merge activity with a separate, smaller work item and
force the script change to share the implementation-plan review and
the Manager implementation-plan gate. Keeping the script change as a
separate Developer gate that runs before Step 1 of the merge
activity preserves the separation and lets each gate review the
correct artifact.

The prerequisite Developer gate for the script change runs before
Step 1 of the merge activity. The Developer confirms the
`## Product-only result` block is in the report before the
regression rerun in Step 5 starts.

## Evidence for the prerequisite gate

The Developer produces a short evidence file
`._design_docs/cache-handling-phase11-implementation/part-04-prerequisites-evidence-YYYYMMDD-NN.md`
that records:

- The diff applied to `run_coverage.ps1`.
- A dry run of the script on the current build tree, with the
  resulting `coverage-report.md` excerpt that shows the new
  `## Product-only result` block.
- The product-only line rate, the product-only covered X / Y, and
  the threshold verdict from the dry run.
- A line count and a trailing-whitespace check on the touched paths.

The evidence file is a Developer-owned artifact. The Architect
records a sanity check on the new block in the same evidence file,
not in a separate review document. The Manager records the closure
of the prerequisite gate in the Stage 11 implementation log entry
doc, with the date.

## Handoff state

The prerequisite Developer gate runs before Step 1 of the merge
activity. The merge activity remains closed until the prerequisite
gate closes. The implementation-plan review and the Manager
implementation-plan gate cover only the merge activity, not the
prerequisite gate.
