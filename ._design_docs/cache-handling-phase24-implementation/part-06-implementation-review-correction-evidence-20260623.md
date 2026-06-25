# Stage 24 implementation-review correction evidence 2026-06-23

Status: correction ready for Architect re-review
Date: 2026-06-23
Owner: Developer
Scope: Stage 24 runner and evidence only. No product code changed.

## Corrective actions

| Finding | Correction |
| --- | --- |
| B-24-IMPL-01 | `comparison.json` now derives S03 near-prefix counts from native and hybrid `requests.jsonl`. It records `near_prefix_requests`, `near_prefix_cache_n_nonzero`, `near_prefix_restore_policy`, and per-variant counts. Because the runner has no exact-boundary proof path, any nonzero near-prefix `cache_n` sets `FAIL-unsafe-prefix-restore`. |
| B-24-IMPL-02 | Each leg summary now records cleanup state: owned process id, whether the owned process stopped, and whether the port became free. Cleanup failure sets `BLOCKED-runner-cleanup` unless the leg already has a `FAIL`, which remains visible. |
| B-24-IMPL-03 | A real durable report was produced and preserved at `._design_docs/.test_reports/test-report-20260623-01.md`. The final leak scan result is `PASS` with zero hits in `._test_output/stage24-chat-s02-s03-20260623-correction-smoke3/final-leak-scan.json`. |
| B-24-IMPL-04 | `ReportPath` is validated after path resolution. The runner accepts only files directly under `._design_docs/.test_reports/` with names matching `^test-report-\d{8}-\d{2}\.md$`; invalid paths stop before dry-run or live execution. |

## Verification

Parser check:

```powershell
[System.Management.Automation.Language.Parser]::ParseFile(...)
```

Result: `PARSE OK`.

Route scan:

```powershell
Select-String stage24-chat-s02-s03-comparison.ps1 -Pattern '/completion|/v1/chat/completions'
```

Result: only `$Route = '/v1/chat/completions'` matched. No `/completion`
fallback exists.

Invalid `ReportPath` check:

```powershell
powershell ... -ReportPath ._test_output\bad-stage24-report.md -DryRun
```

Result: exit code 1 with
`Invalid ReportPath ... Use ._design_docs\.test_reports\test-report-YYYYMMDD-NN.md with a two-digit suffix.`

Valid dry-run:

```powershell
powershell ... `
  -RunId stage24-chat-s02-s03-20260623-correction-dryrun2 `
  -ReportPath ._design_docs\.test_reports\test-report-20260623-01.md `
  -RunRoot ._test_output\stage24-chat-s02-s03-20260623-correction-dryrun2 `
  -DryRun
```

Result: route `/v1/chat/completions`, rows `S02-chat,S03-chat`, S02
`--parallel 4`, S03 `--parallel 2`, valid durable report path, native without
hybrid flags, hybrid with redacted evidence and cold-store flags.

Focused smoke:

```powershell
powershell ... `
  -RunId stage24-chat-s02-s03-20260623-correction-smoke3 `
  -ReportPath ._design_docs\.test_reports\test-report-20260623-01.md `
  -RunRoot ._test_output\stage24-chat-s02-s03-20260623-correction-smoke3 `
  -SmokeSeconds 3 -DistinctPrefixes 4
```

Result: exit code 0. Durable report:
`._design_docs/.test_reports/test-report-20260623-01.md`.

Smoke row outcomes:

| Row | Comparison verdict | Failure | Leak scan | S03 near-prefix requests | S03 nonzero near-prefix `cache_n` |
| --- | --- | --- | --- | ---: | ---: |
| S02-chat | PASS | none | PASS | 0 | 0 |
| S03-chat | FAIL | FAIL-unsafe-prefix-restore | PASS | 4 | 1 |

S03 split counts: native had 2 near-prefix requests with 1 nonzero `cache_n`;
hybrid had 2 near-prefix requests with 0 nonzero `cache_n`. Since exact-boundary
proof is not implemented, the row correctly fails as unsafe-prefix restore.

Cleanup proof from the smoke summaries:

| Row | Variant | Cleanup | Owned process stopped | Port free |
| --- | --- | --- | --- | --- |
| S02-chat | native-legacy | PASS | true | true |
| S02-chat | hybrid-stage24 | PASS | true | true |
| S03-chat | native-legacy | PASS | true | true |
| S03-chat | hybrid-stage24 | PASS | true | true |

Final leak scan:

- Path: `._test_output/stage24-chat-s02-s03-20260623-correction-smoke3/final-leak-scan.json`
- Result: `PASS`, `hit_count = 0`

## Preserved prior evidence

Part 4 still records the earlier 60 second S02 hybrid `FAIL-http-request` after
repeated request connection closures. This correction does not hide or reclassify
that result. The new short smoke proves runner-contract behavior and durable
report handling only; it does not close final Stage 24 acceptance.

## Handoff

Architect can re-review the Stage 24 runner correction. Manager should still
wait for Architect re-review before opening QA planning.
