# Stage 24 design: chat-completion S02/S03 cache comparison

Status: design review PASS; Manager design gate PASS; Stage 24 closed 2026-06-25 per D-CLOSURE-24-01
Date: 2026-06-25
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Owner: Architect
Source: Manager intake from Stage 23 L02 analysis and user request on 2026-06-23
Scope: focused `/v1/chat/completions` native-vs-hybrid comparison for S02 and S03 workload intent.
Current gate: terminal (Stage 24 closed)

## Contents

- [Part 1: design review 2026-06-23](cache-handling-phase24-design/part-01-design-review-20260623.md)
- [Part 2: Manager design gate 2026-06-23](cache-handling-phase24-design/part-02-manager-design-gate-20260623.md)

## Purpose
Stage 24 compares current default cache behavior with the hybrid controller on
the OpenAI-compatible chat route. It reuses only the intent of Stage 23 S02 and
S03:
- S02: concurrent multi-slot access.
- S03: large branch forests with exact and near-prefix outcomes.
Stage 23 remains closed. Stage 24 does not reopen any Stage 23 PASS evidence.

## Traceability
This stage exists because Stage 23 L02 proved the paired comparison harness
contract but used native `/completion` for the baseline. That route produced
`token-position-fallback` metadata, so it could not prove the chat-path MTP
checkpoint boundary invariant.

Stage 24 targets the architecture invariant in
`cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md`:
chat requests must produce boundary metadata like:
```text
source=openai-chat method=rendered-text-boundary-inference
```
Stage 24 also inherits Stage 17 evidence rules from test-plan part 27:
redacted prompt evidence, bounded restore-miss reasons, no prefix restore, cold
budget accounting, and clean leak scans.

## Design decisions
| Decision | Stage 24 choice | Reason |
| --- | --- | --- |
| Runner shape | One combined focused runner with two workload rows and two variant legs per row. | The comparison needs identical request generation, timing extraction, report schema, cleanup, and leak scan logic across S02 and S03. Separate scripts would duplicate the comparison contract. |
| Cache-mode names | `native-legacy` and `hybrid-stage24`. | `native-legacy` means the current default server cache path with no `--cache-mode hybrid`. It is not an upstream checkout. `hybrid-stage24` means `--cache-mode hybrid` plus Stage 17 evidence and cold-budget flags. |
| HTTP route | Both variants must use `/v1/chat/completions`. | Route parity is the point of the stage. A `/completion` request invalidates the comparison. |
| Ports | Use base port 8900 by default. Each logical row runs serially with one server process at a time. If the implementation keeps both variant servers alive at once, use `base+0` for `native-legacy` and `base+1` for `hybrid-stage24`, then advance by 10 for the next row. | Serial execution avoids Stage 23 multi-leg port-collision issues. The two-port rule gives Developer a safe option for simultaneous smoke or overlap checks. |
| Row caps | Default live cap is 10 minutes per leg. Manager may approve 30 minutes per leg before execution. Smoke cap is 60 seconds and cannot satisfy final acceptance. | Stage 24 is a focused comparison, not a full matrix rerun. Ten minutes is enough to prove route, metadata, request accounting, and bounded behavior while limiting run time. |
| S02 parallelism | Use `--parallel 4` only for the required comparison. `--parallel 8` is optional follow-up evidence and must be classified separately if the host cannot start. | Stage 23 and Stage 12 already documented the host-risk rule for 8 slots. Stage 24 needs a stable native-vs-hybrid comparison, not a capacity probe. |
| S03 fixture | Use the Stage 23 primary Qwen3.5 MTP fixture: `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf`. Do not substitute the Qwen3-0.6B pressure fixture for S03. | Stage 24 tests chat-path MTP checkpoint metadata. The pressure fixture is useful for hot-budget pressure rows, but it would not prove the same checkpoint-dependent behavior. |
| S03 workload | Use fixed-seed chat `messages` arrays across exact-repeat, near-prefix, and new-branch classes. Keep 64 distinct branches unless Manager lowers it for host limits. | This preserves S03 branch-forest intent while making chat metadata observable. |
| Native pass condition | Native must complete requests and provide timing/counter baseline. It is not required to produce checkpoint admissions or redacted evidence. | Those are hybrid-specific Stage 17 surfaces. |
| Hybrid pass condition | Hybrid must complete requests, emit chat metadata, write redacted evidence, keep cold bytes within budget, and classify exact, miss, and near-prefix outcomes safely. | This is the behavior under test. |

## Scope
In scope:
- A new focused runner under the existing test-scripts tree.
- Rows `S02-chat` and `S03-chat`, each with `native-legacy` and
  `hybrid-stage24` legs.
- Stable `/v1/chat/completions` request bodies with `messages`, `temperature=0`,
  deterministic seed, bounded `max_tokens`, and no raw prompt text in durable
  reports.
- Per-leg metrics before and after, request samples, timing summaries, and
  machine-readable comparison JSON.
- Hybrid redacted prompt evidence and leak scan.
- Durable Markdown report under `.test_reports/` and non-durable artifacts under
  `._test_output/`.
Out of scope:
- Product code changes, public API schema changes, or public metric-name
  changes.
- Full S01..S08 or L01..L03 matrix rerun.
- Raw prompt evidence mode.
- Pressure-fixture substitution for S03.
- Any requirement that native/default cache behavior produce hybrid-only
  checkpoint metrics.

## Prerequisites and assumptions
- `build-cov/bin/Release/llama-server.exe` and its implementation DLL are fresh,
  or the report records a clean build before execution.
- The Qwen3.5 MTP fixture exists at the path listed above.
- Ports 8900..8911 are free, or Manager assigns a replacement base port.
- The cold path starts empty for each hybrid leg.
- Output volume has at least 30 GiB free and the cold-path volume has at least
  10 GiB free before execution.
- The implementation can reuse Stage 23 helpers for metrics capture, evidence
  directories, and bounded leak scans, but it must not alter Stage 23 closed
  evidence.

## Runner interface
The design expects a focused command shape like this:
```powershell
powershell -NoProfile -Command "& ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
  -RunId 'stage24-chat-s02-s03-YYYYMMDD-NN' `
  -RowsToRun @('S02-chat','S03-chat') `
  -ModelPath 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
  -RunRoot 'D:\source\llama.cpp-jet\._test_output\stage24-chat-s02-s03-YYYYMMDD-NN' `
  -CacheColdPath 'D:\tmp\cache-cold-stage24' `
  -BasePort 8900 `
  -LegDurationMin 10 `
  -ColdBudgetMiB 512 `
  -DryRun"
```
The live command removes `-DryRun`. Developer may choose parameter names, but
the runner must expose the same concepts: rows, run root, model path, cold path,
base port, leg cap, cold budget, and dry-run.

## Variant flags
`native-legacy`:
- Omit `--cache-mode hybrid`.
- Use `/v1/chat/completions`.
- Enable metrics.
- Use the same model path, seed, temperature, `--parallel` value, context size,
  and request bodies as the hybrid leg.
- Do not enable Stage 17 prompt evidence or cold-store flags.
`hybrid-stage24`:
- Pass `--cache-mode hybrid`.
- Pass `--cache-ram 512` unless Manager approves a different hot budget.
- Pass `--cache-cold-path <path>` and `--cache-cold-max-mib 512`.
- Pass `--cache-prompt-evidence redacted` and
  `--cache-prompt-evidence-dir <run-root>\prompt-evidence\<row>`.
- Enable metrics.
- Use the same model path, seed, temperature, `--parallel` value, context size,
  and request bodies as the native leg.

## Workload contracts
S02-chat:
- Start each leg with `--parallel 4`.
- Send concurrent chat-completion requests across four workers.
- Use stable `messages` arrays, not `/completion` prompts.
- Record per-worker request count, HTTP status, `cache_n`, prompt tokens,
  generated tokens, prompt time, total time, and slot or worker id when exposed.
- PASS requires no crash, no request-accounting loss, no cross-worker state
  contamination in logs or responses, and complete comparison evidence.
S03-chat:
- Start each leg with `--parallel 2`, `DistinctPrefixes=64`, and seed 42 unless
  Manager changes the row before execution.
- Generate deterministic chat messages for exact-repeat, near-prefix, and
  new-branch request classes.
- Near-prefix classes must not be counted as successful restores unless
  exact chat-boundary identity proves the hit. Otherwise they are safe misses.
- PASS requires branch-forest evidence, bounded restore-miss classification,
  no unsafe prefix restore, no corrupt restore, and complete comparison
  evidence.

## Artifacts
Durable report:
```text
.test_reports/stage24-chat-s02-s03-YYYYMMDD-NN.md
```
Non-durable output:
```text
._test_output/stage24-chat-s02-s03-YYYYMMDD-NN/
```
Required per-leg files:
- `launch.log`, `server.out.log`, `server.err.log`, `metrics-before.txt`,
  `metrics-after.txt`, and `requests.jsonl`.
- `summary.json` with row id, variant, route, flags, request counts, token
  totals, timing stats, `cache_n`, metric deltas, cold bytes, verdict, and
  failure classification.
- Hybrid-only redacted evidence JSONL and leak-scan output, or explicit
  `BLOCKED-evidence-missing`.
Required per-row files:
- `comparison.json` for `S02-chat` and `S03-chat`.
- A row summary table in the durable report.

## Metrics and evidence contract
The runner must collect these values when exposed:
- `cache_restore_misses_total`
- `cache_prefix_candidates_total`
- `cache_prompt_evidence_records_total`
- `cache_cold_bytes`
- `cache_cold_budget_bytes`
- `cache_cold_demotions_skipped_total`
- `cache_cold_evictions_total`
- `cache_checkpoint_admissions_by_shape_total`
- `cache_checkpoint_admissions_total`
- `cache_checkpoint_admission_failures_total`
The report must not invent missing metrics. If a family is unavailable, record
`BLOCKED-metric-unavailable` for that evidence item unless logs or JSONL prove
the same contract.
Each row comparison must report:
- request, success, and error counts per variant
- prompt, generated, total token, and `cache_n` sums
- prompt-time and total-time median, p95, and max
- cache hit rate from public metrics when available and from response
  `cache_n > 0`
- restore miss rate with bounded reason breakdown
- checkpoint admission success and failure totals split by bounded labels
- cold bytes and cold budget after values
- prompt-time and total-time deltas from native to hybrid, marked faster,
  slower, or neutral
- interpretation that separates product behavior from harness or workload
  limits

## Redaction and leak scan
Durable docs may include request ids, row ids, variant names, token counts,
checksums, bounded labels, namespace hashes, response status, and aggregate
timings. They must not include raw prompt text, raw message content, raw paths
inside prompt evidence, raw namespace ids, raw descriptor ids, or request JSON
bodies.
Leak scan must cover the durable report, request JSONL, summaries, comparison
JSON, redacted evidence JSONL, and server logs. A raw prompt leak in redacted
mode is a product or runner FAIL depending on source. Missing leak-scan output
is `BLOCKED-evidence-missing`.

## Cold budget checks
Hybrid legs use `--cache-cold-max-mib 512` by default. PASS requires
`cache_cold_bytes <= cache_cold_budget_bytes` at leg end when both metrics are
available. If cold metrics are unavailable, the report must use cold-path byte
measurement as substitute evidence and mark the metric gap separately.
Cold write failure, host allocation failure, or unbounded cold growth is FAIL.
No native leg needs cold-budget evidence unless it was accidentally started
with hybrid cold flags, which is a runner-contract failure.

## Failure classification
PASS:
- Both variants used `/v1/chat/completions`; hybrid emitted
  `source=openai-chat` and `method=rendered-text-boundary-inference`.
- Required files, summaries, hybrid redacted evidence, and clean leak scans
  exist.
- S02 and S03 row-specific behavior passed and cold budget stayed bounded.
FAIL:
- Product crash after valid setup.
- Repeated HTTP 500 after health was established.
- Corrupt restore, unsafe prefix restore, or cross-slot state corruption.
- Raw prompt leak in redacted mode from product output.
- Hybrid checkpoint admission counted as success when the bounded failure label
  says it failed.
- Cold write failure without bounded handling.
BLOCKED:
- Missing fixture, stale binary, port collision after one setup retry, disk
  shortage, server never healthy, missing evidence, missing required metric
  with no substitute, or runner contract violation.

## Testability and review gates
Developer implementation planning must show:
- Dry-run output for row, variant, port, command flags, route, and output paths.
- Parser or static checks that every request target is `/v1/chat/completions`.
- A 60 second smoke that writes both variant summaries and comparison JSON.
- Script-level checks for timing aggregation, `cache_n` aggregation, leak-scan
  failure, and metric-unavailable classification.
Architect implementation review must check runner contract and docs before QA
executes a final live comparison. Manager owns the checklist that opens
implementation planning.

## Risks and mitigations
| Risk | Mitigation |
| --- | --- |
| Qwen3.5 MTP fixture cannot load with `--parallel 4` | S02 may be `BLOCKED-host-capacity` only after the runner records the startup failure. Do not silently lower S02 below 4 without Manager approval. |
| Native and hybrid timing differs because of cache features, not route | Report deltas as comparison evidence, not as a performance claim unless request mix and token counts match closely. |
| Chat metadata is absent | Hybrid row fails or blocks depending on setup; do not substitute `/completion` fallback metadata. |
| S03 exact hits remain low | Safe misses are acceptable when bounded reasons and near-prefix rejection are proved. Exact-hit absence alone is not FAIL without matching identity evidence. |
| Evidence volume grows | Store raw request artifacts under `._test_output`; keep durable report to summaries and bounded snippets only. |

## Rollback and safe behavior
Stage 24 adds no product behavior. If the runner or comparison report is wrong,
revert or replace the Stage 24 runner and discard the affected non-durable
output. Stage 23 closure remains unchanged.
If live execution finds a product bug, stop after preserving evidence and open a
reviewed bug-fix loop. Do not change product code under this design-authoring
task.

## Acceptance criteria
Stage 24 design is ready for Manager checklist when this document is indexed,
stays under the 300-line cap, records all open design decisions above, and has
a PASS design review.
Stage 24 execution can close only when the durable report proves the PASS items
listed in Failure classification or records Manager-accepted BLOCKED rows with
complete setup evidence and no product defect.

## Handoff
Next owner: Developer.
Developer may write the implementation plan in a fresh session. Runner or code
changes still require implementation-plan review before execution opens.
This file uses LF line endings, plain ASCII status labels, and stays under the
300-line durable-doc cap.
