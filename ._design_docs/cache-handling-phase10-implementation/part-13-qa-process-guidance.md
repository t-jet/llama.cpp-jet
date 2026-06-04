# Stage 10 follow-up: A and D - QA process guidance

- Date: 2026-06-04
- Owner: QA
- Source of action:
  [test-report-20260603-architect-review.md](../.test_reports/test-report-20260603-architect-review.md)
  Findings A and D, actions A and D in the action summary table.

## Action A: T114 verdict must cite coverage-report.md

When reporting the T114 (hybrid path coverage) verdict in any Stage N test
report, cite the `Combined result` block at the bottom of
`coverage-report.md` rather than the Cobertura XML root attributes
(`line-rate`, `lines-valid`, `lines-covered`).

The XML root rate is the all-files rate across every source file the
OpenCppCoverage run tracked, not the hybrid-mode denominator rate. The
hybrid-mode denominator is the 19 files named in the `$denomBasenames`
array in `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
lines 303 onward. The script writes `coverage-report.md` to the
`-OutDir` parameter; the `## Combined result` block at the bottom of
that file contains the `Combined line rate`, the `Combined covered` ratio
of covered lines to valid lines for the denominator, and the 80% verdict.

Citing the XML root in the T114 verdict row misrepresents the
closure-contract rate. The 2026-06-03 report cited `line-rate="0.7315"`
with `lines-valid="27191"` as the T114 result and was wrong; the
hybrid-mode denominator rate in that same run was approximately 84.9%.
The 2026-06-04 bug-fix re-execution (test-report-20260603-04) repeated
the mistake by citing `line-rate="0.2068"` against `lines-valid="169683"`
as a T114 failure. That report's bug-fix handoff
(test-report-20260603-04-fixes.md section 3) confirms the merged XML
included 8 packages and 169683 valid lines, which is the
non-hybrid-mode denominator.

The closure contract for T114 is the `Combined result` rate. Reference
the artifact path that QA produces, not the merged XML root, when
writing the verdict.

Citation format for the T114 row in a Stage N test report:

- Artifact:
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/coverage/coverage-report.md`
- Script: `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
- Verdict cites the `## Combined result` block (combined line rate,
  combined covered X / Y, 80% threshold PASS/FAIL).
- Do not cite `coverage-merged.xml` root attributes in the verdict
  section. Mention the XML root only when explaining why the
  hybrid-mode denominator is narrower than the all-files rate.

Worked example. The 2026-06-04 closure report cited:

- Wrong: `Combined line rate: 0.7406 (XML root across 27536 lines).`
- Right: `Combined line rate: 85.21% (5231/6139, hybrid-mode denominator).`

If a run also produces a non-hybrid `coverage-merged.xml` for
documentation, list the XML path and root attributes in the
`Coverage evidence` block of the test report as supplementary context
for the 19-file denominator, never as the T114 verdict number.

## Action D: T121 public probe must supply common_prompt_checkpoint boundary

When a model-backed checkpoint restore path is required for the T121
(Stage 9 regression) public probe in a Stage N report, supply a
`common_prompt_checkpoint` boundary block in the public `/completion`
request body. The block admits a checkpoint descriptor and produces a
non-zero `cache_checkpoint_hits_total` or
`cache_checkpoint_restores_total` counter, which is the
architecturally required end-to-end evidence of a successful restore.

The 2026-06-04 closure (test-report-20260603-05.md) passed T121 on
`cache_checkpoint_admission_failures_total{mode="hybrid"} 2` because
the public probe did not supply the boundary block. The two failures
are caused by the descriptor validation path returning
`missing checkpoint boundary metadata` from `admit_latest_checkpoint`
when the public `/completion` endpoint does not supply a
`common_prompt_checkpoint` boundary block. The Architect accepted
this as the T121 closure row in
test-report-20260603-04-architect-fix-instructions.md: the
admission-attempt counter is the architecturally required row, and its
non-zero value satisfies the T121 verification rule for the closed
stage.

Future runs that need a successful restore in addition to the
admission-attempt counter must:

- Use the 2026-06-04 closure public probe server start flags:
  `--cache-mode hybrid --cache-ram 512 --spec-type draft-mtp --metrics`.
- Build a `common_prompt_checkpoint` boundary block in the completion
  request body that pairs with a long, deterministic-boundary prompt.
  The block carries the `token_span_start` and `token_span_end` fields
  the `admit_latest_checkpoint` descriptor path expects. The MTP
  fixture and the `--spec-type draft-mtp` configuration are required
  to exercise the speculative-decoding checkpoint path; a non-MTP
  fixture will not raise the `cache_checkpoint_hits_total` or
  `cache_checkpoint_restores_total` counters.
- After the probe, scrape `/metrics` and assert that
  `cache_checkpoint_hits_total{mode="hybrid"}` or
  `cache_checkpoint_restores_total{mode="hybrid"}` is greater than
  zero. The admission-attempt counter may still increment on the
  validation path; do not require it to be zero.
- Classify the T121 row PASS only when the hits or restores counter
  is non-zero. A non-zero admission-failures counter alone is the
  weaker evidence rule used by the 2026-06-04 closure and is not the
  default for future runs.

If the boundary block cannot be supplied in the current run, classify
the row BLOCKED on the public-probe side and preserve the request
body, the server log, and the `/metrics` scrape so a follow-up run
can include the boundary block.

## Scope

This is a process-guidance change for the QA role. No code, test,
test-plan, or script change is in scope. The C1 and C2 Developer
actions and the B Architect action are separate gates and are not
touched by this part. The hybrid controller coverage work in
[part-12-stage10-hybrid-controller-coverage-followup.md](part-12-stage10-hybrid-controller-coverage-followup.md)
is the Developer-owned C2 follow-up and is referenced here only for
lineage.
