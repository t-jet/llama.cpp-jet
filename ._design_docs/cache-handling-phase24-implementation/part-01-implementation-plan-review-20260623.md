# Stage 24 implementation-plan review 2026-06-23

Status: REWORK
Date: 2026-06-23
Reviewer: Architect
Subject: [Stage 24 implementation plan](../cache-handling-phase24-implementation.md)
Scope: independent implementation-plan review only. No runner, test, product,
public API, public metric, fixture, or Stage 23 evidence change was reviewed or
authorized.

## Verdict

REWORK.

The plan is mostly complete and follows the approved Stage 24 design and Manager
decisions D24-DESIGN-01 through D24-DESIGN-03. One blocking documentation and
artifact-placement issue must be corrected before Manager opens implementation.

## Review coverage

Reviewed against:

- [Document index](../document-index.md)
- [Stage 24 design](../cache-handling-phase24-design.md)
- [Stage 24 design review](../cache-handling-phase24-design/part-01-design-review-20260623.md)
- [Stage 24 Manager design gate](../cache-handling-phase24-design/part-02-manager-design-gate-20260623.md)
- [Chat-path prompt boundary invariant](../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md)
- [Stage 17 evidence plan](../cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md)
- [Stage 12 stress definitions](../cache-handling-test-plan/part-18-stage12-stress-benchmarks.md)
- [Stage 12 automation notes](../cache-handling-test-plan/part-19-stage12-test-automation.md)
- [Test output folder convention](../cache-handling-test-plan/part-24-test-output-folder-convention.md)
- [Stage 24 implementation plan](../cache-handling-phase24-implementation.md)

## Findings

### BLOCKING

| ID | Finding | Evidence | Required correction |
| --- | --- | --- | --- |
| B-24-IP-01 | The planned durable report name is not tracked by the current `.test_reports` whitelist. | The plan names `._design_docs/.test_reports/stage24-chat-s02-s03-YYYYMMDD-NN.md`. The active `.test_reports/.gitignore` whitelists `test-report-*.md`, `pre-merge-report-*.md`, `merge-log-*.md`, `stage14-integration-cherry-pick-*.md`, `stage15-benchmark-*.md`, `stage23-*.md`, and `coverage-run-*/coverage-report.md`. Test-plan part 24 says Markdown test reports use `test-report-YYYYMMDD-NN.md` unless the whitelist is updated. | Before implementation opens, either change the Stage 24 durable report pattern to a whitelisted `test-report-YYYYMMDD-NN.md` form, or explicitly add the required `.test_reports/.gitignore` and test-plan convention update to the docs-only scope. Do not leave the Stage 24 report at an ignored path. |

### Non-blocking

None.

### INFO

| ID | Observation | Evidence | Follow-up |
| --- | --- | --- | --- |
| I-24-IP-01 | The ordered implementation plan is otherwise complete. | It covers command interface, rows, variants, route enforcement, cleanup, metrics, timing, `cache_n`, comparison JSON, redaction, leak scan, failure classes, validation, risks, and docs handling. | Keep those sections while fixing B-24-IP-01. |
| I-24-IP-02 | The plan preserves D24-DESIGN-03. | It keeps the combined runner, `native-legacy` and `hybrid-stage24`, `/v1/chat/completions`, S02 `--parallel 4`, S03 Qwen3.5 MTP fixture, 10 minute leg cap, redacted evidence, and no Stage 23 evidence reopening. | None. |
| I-24-IP-03 | The plan does not authorize product or public-surface changes. | It explicitly excludes `tools/server/*`, public API schemas, public metric names, model fixtures, Stage 23 closed reports, Stage 23 runner behavior, and final live comparison during planning. | None. |
| I-24-IP-04 | The 300-line rule is satisfied. | The parent implementation log remains below 300 lines, and this review part is below 300 lines. | Recheck after the correction. |

## Gate decision

Manager cannot open runner implementation yet. The next owner should correct the
report-placement issue and request re-review. No product code, runner code, test
execution, public API change, public metric change, fixture edit, or Stage 23
evidence change is authorized by this review.
