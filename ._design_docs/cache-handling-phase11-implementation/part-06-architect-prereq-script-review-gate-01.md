# Stage 11 prerequisite: run_coverage.ps1 T114a change review gate 01

Source: [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)
Review date: 2026-06-04
Reviewer: Architect agent
Gate: Architect review of the run_coverage.ps1 T114a change (Stage 11 prerequisite)
Verdict: PASS

## Scope and gate status

This review covers the Developer-applied T114a change to
`._design_docs/cache-handling-test-scripts/run_coverage.ps1`. The change
adds a product-only coverage section to `coverage-report.md` so the
T114a row in test plan Part 13 is evidence-citeable from Stage 11
onward.

The review does not approve code work, merge execution, regression
reruns, coverage execution, k6 runs, the pre-merge report, the merge
log, the test plan body, the test report, the fixes report, any review
report, the bug-fix report, the production-fix parts, the verification
summary, commits, PR text, or reviewer responses. The review does not
edit the script. The review does not run coverage, the test suite, k6,
or the upstream merge. The review does not redefine the spec; the spec
is fixed by test plan Part 13.

The Stage 11 implementation remains closed. The test plan gate, the
rework Stage N gates, and the QA execution gate remain closed. The
Manager implementation-plan gate is the prior gate and remains
pass-closed. The prerequisite Developer gate for the script change is
the prior gate in the prerequisite workflow.

## Documents reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-test-plan/part-13-t114-product-only-coverage.md`
- `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
- `._design_docs/cache-handling-phase11-implementation/part-04-prerequisites.md`
- `._design_docs/cache-handling-phase11-implementation/part-05-architect-plan-review-gate-01.md`

## Verification command outputs

| # | Command | Observed output | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | `git diff -w --stat ._design_docs/cache-handling-test-scripts/run_coverage.ps1` | `1 file changed, 40 insertions(+)` | `1 file changed, 40 insertions(+)` (no deletions) | PASS |
| 2 | `git diff -w ._design_docs/cache-handling-test-scripts/run_coverage.ps1` | three hunks: `$productOnlyBasenames` after `$denomBasenames`; product-only sum/rate/verdict block after `$verdict`; `$reportLines += @( ... )` block after the `## Combined result` block | three hunks in the listed placements | PASS |
| 3 | `[System.Management.Automation.PSParser]::Tokenize(...)` | `syntax-ok` | `syntax-ok` | PASS |
| 4 | `git diff --check ._design_docs/cache-handling-test-scripts/run_coverage.ps1` | empty output, `exit=0` | empty output, exit 0 | PASS |
| 5 | Raw bytes CR/LF/size | `CR=0 LF=439 size=18279` | `CR=0 LF=<n> size=<m>` | PASS |
| 6 | First three bytes (BOM probe) | `b0=35 b1=114 b2=101` (`#re` from `#requires`) | no UTF-8 BOM (first three bytes would be `239,187,191`) | PASS |
| 7 | `git diff -w --numstat ._design_docs/cache-handling-test-scripts/run_coverage.ps1` | `40\t0\t._design_docs/cache-handling-test-scripts/run_coverage.ps1` | 40 insertions, 0 deletions | PASS |
| 8 | Working-tree status of the script | `modified: ._design_docs/cache-handling-test-scripts/run_coverage.ps1` (unstaged) | change present in working tree, unstaged | PASS |
| 9 | Most recent commit on the script | `bdb166ac1 ... Stage 10 complete` | script was last touched by the Stage 10 commit, current change is unstaged | PASS |

### Whitespace-ignoring diff content (three hunks)

Hunk 1 (after `$denomBasenames`):

```powershell
# T114a product-only denominator: the 11 hybrid cache implementation files
# named in the Architect review Finding B and recorded in test plan Part 13.
# Test files in $denomBasenames are excluded from the T114a verdict.
$productOnlyBasenames = @(
    'server-cache-hybrid.cpp',
    'server-cache-hybrid.h',
    'server-cache-store-cold.cpp',
    'server-cache-store-cold.h',
    'server-cache-controller.cpp',
    'server-cache-controller.h',
    'server-cache-graph.cpp',
    'server-cache-graph.h',
    'server-cache-io-worker.cpp',
    'server-cache-policy-lru.cpp',
    'server-cache-legacy.h'
)
```

Hunk 2 (after the existing `$verdict` line):

```powershell
# T114a product-only line rate and verdict: filter the per-file rows to
# the 11 product files in $productOnlyBasenames and sum the per-file
# Covered and Valid counts. Rate is Covered/Valid rounded to four decimal
# places to match the combined-rate format. Verdict is PASS when the
# product-only rate is at or above 0.70, FAIL otherwise.
$productOnlyCovered = 0
$productOnlyValid   = 0
foreach ($r in $rows) {
    if ($productOnlyBasenames -notcontains $r.File) { continue }
    $productOnlyCovered += $r.Covered
    $productOnlyValid   += $r.Valid
}
$productOnlyRate   = if ($productOnlyValid -gt 0) { [math]::Round($productOnlyCovered / $productOnlyValid, 4) } else { 0 }
$productOnlyVerdict = if ($productOnlyRate -ge 0.70) { 'PASS' } else { 'FAIL' }
```

Hunk 3 (after the `## Combined result` block in `$reportLines`):

```powershell
$reportLines += @(
    "",
    "## Product-only result",
    "",
    "- Product-only line rate: $productOnlyRate",
    "- Product-only covered: $productOnlyCovered / $productOnlyValid",
    "- 70% threshold: $productOnlyVerdict"
)
```

The diff noise warning in the task brief is confirmed by the
`git diff` and `git diff -w --numstat` outputs. The full diff shows
439 insertions and 399 deletions because the Developer's edit tool
rewrote the file with a different line-ending mix. The
whitespace-ignoring diff shows 40 insertions and 0 deletions, which is
the actual content change.

## Gate checks

| Area | What was checked | Result | Notes |
| --- | --- | --- | --- |
| Spec compliance | The 11-file array, the sum/rate/verdict logic, and the report block shape match test plan Part 13 exactly. No additions, no omissions, no reordering. | PASS | The 11 basenames match the test plan Part 13 product-only denominator table in order and verbatim. The verdict threshold is 0.70. The filter, sum, and rounding match the required script behavior. |
| PowerShell correctness | The PowerShell syntax is valid. The filter loop uses `$productOnlyBasenames -notcontains $r.File` correctly. The sum, rate, and verdict computations are correct. The `[math]::Round(..., 4)` rounding matches the combined-rate format. | PASS | `[System.Management.Automation.PSParser]::Tokenize` returned no errors. The filter is a `continue` guard, so non-product rows are skipped without altering the existing `$rows` list or the combined totals. The sum is integer addition across per-file `Covered` and `Valid`. The rate is computed only when `$productOnlyValid -gt 0`, matching the combined-rate guard. |
| Report block shape | The heading, the three bulleted lines, the labels, and the order match the required output sample. | PASS | The block emits `## Product-only result` followed by an empty line, then the three bulleted lines in the order: line rate, covered X / Y, threshold verdict. The labels are `Product-only line rate`, `Product-only covered`, and `70% threshold`. |
| No collateral changes | `$srcPatterns`, `$denomBasenames`, `$focusedTests`, the per-test loop, the HTTP probe, the HTML and Cobertura XML exports, the `exit 1` on combined FAIL, and the C1 and C2 follow-up changes are all unchanged. | PASS | The whitespace-ignoring diff has 0 deletions, so no line in those sections is modified. The script reading confirms 19 entries in `$srcPatterns`, 19 entries in `$denomBasenames`, 9 entries in `$focusedTests` including the C1 `test-stage10-policy-lru` entry, the per-test loop iterates 9 times, the HTTP probe still uses the model-backed configuration, the HTML and Cobertura XML exports are present, and `exit 1` is still emitted on combined FAIL. |
| File state | LF-only line endings, no UTF-8 BOM, `git diff --check` is clean. | PASS | Raw bytes show `CR=0 LF=439 size=18279`. The first three bytes are `35,114,101` (`#re` from `#requires`), which rules out a UTF-8 BOM (`239,187,191`). `git diff --check` is clean with exit code 0. The file is unstaged in the working tree on branch `cache-optimization` and is therefore reviewable. |

### Per-area detail

**Spec compliance.** The 11 basenames in `$productOnlyBasenames` are
listed in the same order and with the same spellings as the test plan
Part 13 product-only denominator table: `server-cache-hybrid.cpp`,
`server-cache-hybrid.h`, `server-cache-store-cold.cpp`,
`server-cache-store-cold.h`, `server-cache-controller.cpp`,
`server-cache-controller.h`, `server-cache-graph.cpp`,
`server-cache-graph.h`, `server-cache-io-worker.cpp`,
`server-cache-policy-lru.cpp`, `server-cache-legacy.h`. No extra
entries, no missing entries, no reordering. The verdict threshold is
`0.70`, written as the literal in `$productOnlyVerdict = if
($productOnlyRate -ge 0.70) { 'PASS' } else { 'FAIL' }`.

**PowerShell correctness.** The filter loop iterates over the existing
`$rows` list, which already contains one entry per denominator basename
with deduplication applied. The `$productOnlyBasenames -notcontains
$r.File` guard is correct because `$r.File` is a basename from
`[System.IO.Path]::GetFileName($filename)`, which is exactly the form
stored in `$productOnlyBasenames`. The integer sum is straightforward.
The rate guard `$productOnlyValid -gt 0` matches the combined-rate
guard. The `[math]::Round(..., 4)` rounding uses the same precision
and the same fallback to `0` when the denominator is empty.

**Report block shape.** The Hunk 3 array produces, in the report,
`## Product-only result` on its own line, a blank line, and three
bulleted lines in the order: line rate, covered X / Y, threshold
verdict. The labels match the spec sample exactly. The block sits
directly after the `## Combined result` block because the second
`$reportLines += @( ... )` call is appended to the same `$reportLines`
array that already holds the combined block. No blank line is inserted
between the two `$reportLines += @( ... )` calls, but a blank string
element is the first element of the new array, so the report still
gets a blank separator line between the combined and product-only
sections, which matches the spec sample layout.

**No collateral changes.** The whitespace-ignoring diff has 40
insertions and 0 deletions. No pre-existing line in the script is
modified. The full diff also shows 399 deletions in the full-diff
view, but those are line-ending rewrites from CRLF to LF, not content
deletions. The script's substantive sections (19-file denominator,
9-test focused list, HTTP probe, exports, exit policy, C1 and C2
follow-ups) read identically in the working tree and in HEAD.

**File state.** CR=0, LF=439, size=18279. No UTF-8 BOM. `git diff
--check` is clean. The change is unstaged in the working tree on
branch `cache-optimization`.

## Findings

### Blocking findings

None.

### Advisory findings

None.

### Observations

N1 [non-blocking, scope of the prerequisite]. The prerequisite
evidence file the implementation plan Part 4 describes (a
`part-04-prerequisites-evidence-YYYYMMDD-NN.md` file with the diff, a
dry run, the line count, and the trailing-whitespace check) is a
Developer-owned artifact. The Architect records the sanity check
in the same evidence file, not in this review. The next phase will
need to confirm the evidence file exists and cites this review for
the Architect sanity check. This observation is non-blocking because
the prerequisite gate's handoff to Step 1 of the merge activity is
the Manager's call once the Developer closes the gate and the
Architect sanity check is filed.

## Final verdict

**PASS**. The T114a change to `run_coverage.ps1` matches test plan
Part 13. The 11-file array, the sum/rate/verdict logic, and the
report block shape all match the spec. The PowerShell syntax is
valid. No collateral changes were made. The file is LF-only, has no
UTF-8 BOM, and `git diff --check` is clean.

## Handoff

Handoff state: prerequisite Developer gate Architect-review-pass.

Next owner: Manager. The Manager records the closure of the
prerequisite Developer gate in the Stage 11 implementation log entry
doc with a date. Once the Manager closes the prerequisite gate, the
merge activity Step 1 can start. The implementation, rework Stage N,
test plan, and QA execution gates remain closed. This review is a
sanity check on the script change and does not authorize the
implementation, merge execution, regression rerun, coverage
execution, or the upstream merge.
