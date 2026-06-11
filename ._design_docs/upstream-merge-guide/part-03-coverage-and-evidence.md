# Part 3: Coverage, evidence, and closure contracts

Source: [../upstream-merge-guide.md](../upstream-merge-guide.md)

## 1. Closure contracts

Closure contracts are the metrics, coverage floors, evidence rows, and tests the prior stages and the test plan name as required for stage closure. Closure contracts survive the merge. A closure contract that an upstream change would weaken is a rework candidate, not a silent integration.

Each cycle inherits the closure contracts from the prior stages. The cycle's evidence is the test plan rows and the coverage rows the prior-stage contracts name. A cycle may add new closure contracts when a new stage or a new feature has been added since the last cycle. The new closure contracts are listed in the cycle's pre-merge report "Closure contracts" section.

Common closure contracts (per-stage-specific list is in the affected stage's design):

- A combined-rate coverage floor on a feature-mode denominator (e.g., T114 combined 80% on the hybrid-mode files).
- A product-only coverage floor on a narrower feature-mode denominator (e.g., T114a product-only 70% on the product files named in the Architect review).
- A per-file aggregation rule (e.g., T115 per-file deduplication by lowercased full path).
- A public Prometheus metric set and label shape (e.g., R61-R68, the `cache_checkpoint_*` rows, the bounded labels).
- A bounded diagnostic field set (failure, fallback, unsupported configuration, marker validation, cold-store failure, namespace or pair rejection, restore failure).
- An OWASP mitigation table (cold-store path normalization, root containment, marker sanitization, descriptor integrity, paired atomicity, monitoring).
- A model-backed or fixture-backed test row for a feature that requires a model (e.g., H53/H54 for the MTP path, Q102/Q103 for the checkpoint path).
- A focused C++ test that exercises a code path the focused exporter coverage does not reach.
- A k6 benchmark with corrected public Prometheus numbers.
- A clean-build evidence (a line in the test report showing the local build directory and the build target set used for the regression run).

## 2. Evidence format

The cycle's evidence is a set of test reports, coverage reports, and merge log entries. The exact report file name follows the test plan convention: `test-report-YYYYMMDD-NN.md`. The Developer opens a new report for each cycle execution. A cycle that runs more than once (because a fix surfaced a regression) opens a new report per execution.

Required evidence per execution:

| Artifact | Purpose | Required when |
| --- | --- | --- |
| `test-report-YYYYMMDD-NN.md` | Cycle regression test report. Records the ctest result, the public HTTP probe, the focused exporter coverage, the OWASP table, and the prior-stage regression. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/ctest.log` | Raw ctest output for the regression run. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/coverage/coverage-merged.xml` | Raw Cobertura XML from the focused exporter coverage run. | Always, when the cycle touched a feature-mode source file. |
| `test-report-YYYYMMDD-NN-artifacts/coverage/coverage-report.md` | Markdown summary of the focused exporter coverage run. Must contain the per-file table, the `## Combined result` block, and the `## Product-only result` block. | Always, when the cycle touched a feature-mode source file. |
| `test-report-YYYYMMDD-NN-artifacts/mtp-probe-*` | Public HTTP probe artifacts for the MTP or checkpoint admission row. | Only when a feature-mode MTP or checkpoint-capable server is available on the host. |
| Clean-build evidence | A line in the test report showing the local build directory and the build target set used for the regression run. | Always. |
| `test-report-YYYYMMDD-NN-fixes.md` | The cycle handoff from QA when the regression surfaces a FAIL or BLOCKED row. | Only when the regression surfaces a FAIL or BLOCKED row. |
| `test-report-YYYYMMDD-NN-developer-review.md` | The cycle test-results review from the Developer when the test report has a non-trivial verdict. | Only when the Developer classifies any row as FAIL, BLOCKED, or reclassification candidate. |
| `test-report-YYYYMMDD-NN-architect-review.md` | The cycle Architect review of the test report and the test-results review. | Only when the Architect review is required by the test-results verdict. |

The Developer does not invent new evidence formats that the prior stages did not use. The cycle's evidence uses the same artifact shape as the prior stage evidence, with the citation rules in section 3.

## 3. Citation rules

The cycle's test report cites:

- The `## Combined result` block in `coverage-report.md` for the combined-rate verdict. The XML root attributes are not the verdict source.
- The `## Product-only result` block in `coverage-report.md` for the product-only verdict. The combined block and the product-only block are separate sections in the same report.
- The per-file table in `coverage-report.md` for the per-file aggregation verdict. The verdict checks that the table lists each feature-mode file exactly once, after lowercased full-path deduplication.
- The MTP or checkpoint probe row in the public /metrics output for the public admission verdict, when a feature-mode MTP or checkpoint-capable server is exercised.
- The ctest log for the per-test pass or fail count for the prior-stage regression rows.
- The merge log for the conflict list, the resolution list, the deferred upstream commits, and the known gaps.

A verdict that cites the wrong artifact is sent back to the Developer for a rewrite. The Architect does not change a verdict to make the citation match the result.

A row that cites the XML root attributes for the combined-rate verdict is a denial-of-service attack on the test plan Part 13 citation rule. The XML root covers all tracked files and is almost always lower than the filtered-denominator rate. The Developer estimates the true rate from the per-file table before deciding on a bug-fix loop.

## 4. Coverage script prerequisites

A coverage script that does not emit the row the closure contract requires is a blocker, not a fallback. The Developer makes the script change as a separate Developer gate before step 1 of the cycle opens. The change is reviewed by the Architect. The change is a minimum-diff addition of the new block; the existing blocks are unchanged.

A coverage script change that lowers the per-file target the Architect set in a prior cycle is a rework. The Architect's per-file target is an internal target, not a published threshold. The Developer does not lower it during the merge.

## 5. Regression scope

The regression rerun covers the test plan parts the prior-stage contracts name. The Developer narrows the rerun to the test plan parts whose prior-stage contract touched a path the merge changed. A regression rerun that excludes a row whose prior-stage contract the merge touched is a closure-contract failure, not a rework candidate.

For a no-rework cycle, the regression scope is the minimum scope the prior-stage contracts name. For a cycle with reworks, the regression scope is the minimum scope plus the expanded scope each rework part file records. The expanded scope adds the rework-specific evidence on top of the minimum scope for the reworked stage.

The Developer does not start the cycle regression rerun until every open rework for the cycle has closed. A rework that is still open at the time of the regression is a blocker for the regression rerun, not a known gap.

## 6. Staleness check at regression time

The cycle's regression rerun includes a fresh staleness check. The Developer runs the verification commands in part 1 section 2 and records the upstream reference tip (local tracking branch or remote-tracking ref), the actual upstream remote tip, and the gap (if any). A gap that grew between the cycle's pre-merge analysis and the regression rerun is a known gap. The Manager decides whether the gap invalidates the regression evidence or is a follow-up for the next cycle.

## 7. Coverage evidence interpretation

The cycle's regression rerun produces a coverage report. The Developer reads the report and applies the interpretation rules below.

- The combined rate is the rate on the combined feature-mode denominator (e.g., the 19-file hybrid-mode denominator). The threshold is set in the closure contract (e.g., 80%). The verdict is PASS or FAIL.
- The product-only rate is the rate on the product-only feature-mode denominator (e.g., the 11 product files named in the Architect review). The threshold is set in the closure contract (e.g., 70%). The verdict is PASS or FAIL.
- The per-file rate is the rate on each feature-mode file individually. The table lists each file once, deduplicated by lowercased full path. The per-file target is an internal target the Architect sets; the Developer does not lower it.
- The XML root rate is the rate on all tracked files in the coverage run. The XML root rate is not a closure contract. The XML root rate is informational. A regression rerun that cites the XML root rate as the combined verdict is a citation error.

A per-file rate drop is a candidate for a coverage lift. A lift is a minimum-diff change (annotation, refactor, or test addition) that raises the rate without changing behavior. A lift is reviewed by the Architect. A lift is recorded in the cycle's evidence as a follow-up fix.

A coverage drop below the closure contract floor is a rework or a known gap with a follow-up plan. The Manager decides. The decision is recorded in the merge log.

## 8. Build evidence

The cycle's regression rerun includes a build evidence line in the test report. The line shows:

- The local build directory used for the run.
- The build target set used for the run.
- The build configuration (Release, RelWithDebInfo, Debug).
- The build command family.

A clean build is required for the first regression rerun in a cycle. An incremental build is acceptable for follow-up reruns (a coverage lift, a fix verification) when the clean build was already recorded.

A build that failed on a prior commit and passed on the follow-up commit is recorded as a build defect fix. The build defect fix is a separate commit, reviewed by the Architect, recorded in the merge log.

## 9. Test report format

The cycle's test report follows the test plan convention. The exact report file name is `test-report-YYYYMMDD-NN.md`. The report sections are:

- Cover and metadata: cycle number, design baseline link, date opened, date closed, owner, reviewer, approver, integration branch tip SHA, fork point SHA, upstream reference tip SHA (local tracking branch or remote-tracking ref), actual upstream remote tip SHA.
- Build evidence: build directory, build target set, build configuration, build command, build result, build timestamp.
- ctest result: focused test binaries, per-test pass or fail count, total count, ctest log path.
- Public HTTP probe: probe artifacts, per-row verdict, probe log path.
- Focused exporter coverage: coverage report path, combined result, product-only result, per-file aggregation verdict, XML root (informational only).
- OWASP table: OWASP mitigations, per-mitigation status, evidence.
- Stage regression: per-stage regression rows, per-row verdict, evidence.
- Closure contracts: per-contract verdict, evidence citation.
- Open items: any FAIL, BLOCKED, or reclassification candidate.
- Handoff: next gate, next owner, follow-up items.

A test report that is missing any of the required sections fails the Architect review and is sent back to the Developer for a rewrite.

## 10. Reclassification rules

A row in a cycle's test report can be reclassified from FAIL or BLOCKED to PASS or SKIP when the Architect and the Manager agree on a justification. The justification is one of:

- The row was a tooling limitation, not a product defect. The justification includes the tooling change that would lift the limitation and the cycle in which the change will land.
- The row's evidence is a substitute that the Architect approves. The substitute is recorded in the rework part file or the test plan.
- The row is a known gap with a follow-up owner. The follow-up owner is recorded in the merge log.

A reclassification that converts a FAIL into a BLOCKED-with-evidence does not make the closure contract disappear. The closure contract is still unmet. The closure decision is a separate gate. The Manager's closure decision is the only authority that closes a closure contract.

The closure decision is recorded in the cycle's implementation log. The closure decision is the Manager's verdict that the cycle is closed despite the open rows, with a justification for each open row. A closure decision that ignores a closure contract is a premature closure. The Architect flags premature closures. The Manager rejects premature closures.
