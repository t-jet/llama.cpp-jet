# Part 10: pre-rerun investigation and fixes 2026-06-24

Status: correction reviewed PASS
Date: 2026-06-24
Owner: Developer
Scope: Stage 24 pre-rerun investigation for the CPU-only S02/S03 report. Runner and documentation changed. No product code changed.

## Trigger

Manager requested a focused pre-rerun check before the fresh CUDA Stage 24 run:

- S02 hybrid recorded `FAIL-http-request` in `test-report-20260623-03.md`.
- S03 recorded `FAIL-unsafe-prefix-restore` and low hybrid cache hits.

That report remains invalid for Stage 24 closure because it was built with
`GGML_CUDA=OFF`. The investigation still used its raw artifacts to remove
runner defects before the CUDA rerun.

## Inputs checked

- `._design_docs/.test_reports/test-report-20260623-03.md`
- `._test_output/stage24-chat-s02-s03-20260623-03/S02-chat/hybrid-stage24/summary.json`
- `._test_output/stage24-chat-s02-s03-20260623-03/S02-chat/hybrid-stage24/requests.jsonl`
- `._test_output/stage24-chat-s02-s03-20260623-03/S02-chat/hybrid-stage24/server.err.log`
- `._test_output/stage24-chat-s02-s03-20260623-03/S02-chat/comparison.json`
- `._test_output/stage24-chat-s02-s03-20260623-03/S03-chat/comparison.json`
- S03 native and hybrid summaries and request JSONL files
- `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`

## S02 finding

The S02 hybrid artifact shows 17 HTTP 200 responses, then transport errors, then
connection refused until the leg cap. The after-metrics scrape also failed with
connection refused on port 8900.

`server.err.log` ends during hybrid save and cold-pressure handling. The last
cache lines show:

- repeated payload budget warnings
- demotion failures falling back to immediate eviction
- invalidated context checkpoint erasure
- a final save attempt after the server had already reached roughly 612 MiB
  resident payload against the 512 MiB hot budget

No Application Error record for `llama-server` or `llama-server-impl` was found
in the relevant Windows Application log window. The artifact has no CUDA runtime
proof and the report records `GGML_CUDA=OFF`, so it cannot prove a CUDA product
bug.

Root cause classification: invalid CPU-only artifact plus runner amplification.
The server became unreachable after health during hybrid cold pressure, and the
runner kept sending S02 requests until the leg cap. The 887 request errors are
mostly harness amplification after the first transport loss, not 887 distinct
product failures.

## S02 fix

Updated the runner to stop an active request set when transport loss is detected
and the port is free after a previously healthy server. The runner now records:

```text
request_counts.request_run.state = aborted-server-unreachable-after-health
notes = request loop stopped after server became unreachable
```

The row still fails if this happens after valid CUDA startup. The fix only
prevents a long retry storm and makes the root cause easier to review.

No product code change was made because the available S02 evidence is CPU-only
and does not isolate a CUDA product defect.

## S03 finding

The CPU-only S03 hybrid leg is safe under the Stage 24 hybrid policy:

| Class | Hybrid requests | Nonzero `cache_n` |
| --- | ---: | ---: |
| exact-repeat | 134 | 67 |
| near-prefix | 67 | 0 |
| new-branch | 66 | 0 |

The row failed because the comparison counted native `near-prefix` `cache_n` as
unsafe. Native default-cache `cache_n` is not hybrid checkpoint restore proof and
does not use the Stage 24 redacted prompt-evidence policy. It is useful timing
and baseline data, but it should not decide unsafe hybrid prefix restore.

Expected hybrid hit rate for the CUDA rerun:

- Exact-repeat: about 50 percent nonzero `cache_n`, because each branch has one
  first exact request that admits/saves and one repeat request that can hit.
- Full S03 mix: about 25 percent nonzero `cache_n`, because near-prefix and
  new-branch classes should stay at zero.
- Near-prefix: zero nonzero `cache_n` unless exact chat-boundary identity proof
  is later implemented and proves the hit safe.

Under that policy, low overall hybrid hits are expected for the Stage 24 S03
workload. They are not a product bug by themselves.

## S03 fix

Updated the runner's unsafe-prefix check to fail only on hybrid near-prefix
nonzero `cache_n`. Native near-prefix nonzero counts are preserved under the
`native` diagnostic object in `comparison.json`, but they no longer trigger
`FAIL-unsafe-prefix-restore`.

The comparison policy text now says:

```text
hybrid nonzero near-prefix cache_n is unsafe unless exact chat-boundary proof exists; native default-cache cache_n is diagnostic only
```

No product code change was made.

## Verification

Commands run in this session:

```text
Parser check: PASS
Route scan: PASS, only /v1/chat/completions is used
Focused source assertions: PASS
Dry-run: PASS
Dry-run CUDA flags: PASS, all four planned legs include --n-gpu-layers all and --fit off
Dry-run CUDA build proof: BLOCKED-cuda-configure-missing, observed GGML_CUDA:BOOL=OFF
git diff --check: PASS for touched tracked paths
Manual trailing whitespace scan: PASS for touched untracked docs/script
Manual ASCII scan: PASS for touched untracked docs/script
Document caps: PASS
```

The dry-run used run root
`._test_output/stage24-chat-s02-s03-20260624-pre-rerun-dev/` and report path
`._design_docs/.test_reports/test-report-20260624-99.md`. It started no server
and sent no requests. The CUDA build proof state is expected because the current
local `build-cov` remains the invalid CPU-only build from the prior report.

## Handoff

Architect review passed this runner correction together with the CUDA correction
in Part 11. The rerun should preserve the approved Stage 24 constraints:
`/v1/chat/completions` only, `native-legacy` and `hybrid-stage24`, S02
`--parallel 4`, S03 `--parallel 2`, Qwen3.5 MTP fixture,
`--n-gpu-layers all`, `--fit off`, whitelisted report path, and no Stage 23
reopening.
