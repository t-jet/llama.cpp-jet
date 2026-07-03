# Test plan part 37: Stage 34 real agentic transcript replay

Status: authored; pending QA test-plan review
Date: 2026-07-01
Stage: 34 (real agentic transcript replay and concurrent cache reuse)
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: test planning for the Stage 34 generic agentic-shape replay flow. Do not treat this as live-run evidence.

## References

Design:

- [Stage 34 design entry](../cache-handling-phase34-design.md)
- [Stage 34 design review PASS](../cache-handling-phase34-design/part-01-design-review-20260630.md)
- [Stage 34 Manager design gate PASS](../cache-handling-phase34-design/part-02-manager-design-gate-20260630.md)
- [Stage 34 Manager intake brief](../.manager-inputs/manager-input-20260630-stage34-real-agentic-transcript-replay.md)

Implementation handoff:

- [Stage 34 implementation log entry](../cache-handling-phase34-implementation.md)
- [Stage 34 implementation-plan review PASS](../cache-handling-phase34-implementation/part-01-implementation-plan-review-20260630.md)
- [Stage 34 Manager implementation-plan gate PASS](../cache-handling-phase34-implementation/part-02-manager-implementation-plan-gate-20260630.md)
- [Stage 34 implementation evidence](../cache-handling-phase34-implementation/part-03-implementation-evidence-20260630.md)
- [Stage 34 implementation review REWORK](../cache-handling-phase34-implementation/part-04-implementation-review-20260630.md)
- [Stage 34 rework evidence PASS](../cache-handling-phase34-implementation/part-05-rework-evidence-20260630.md)
- [Stage 34 implementation re-review PASS](../cache-handling-phase34-implementation/part-06-implementation-re-review-20260630.md)

Carry-over sources and prior plans:

- [Part 24: test output folder convention](./part-24-test-output-folder-convention.md)
- [Part 27: Stage 17 agentic cache reuse](./part-27-stage17-agentic-cache-reuse.md)
- [Part 36: Stage 32 live comparison rerun](./part-36-stage32-live-comparison-rerun.md)
- [Stage 33 Developer test-results review](../.test_reports/test-report-20260630-03-stage33-01-developer-review.md) (hot 2048 MiB / cold 8192 MiB floors, 512 MiB round-up)
- [Stage 27 fix evidence](../.test_reports/test-report-20260626-07-fixes.md) (D-EXEC-24-03 heap-corruption regression baseline)

## Scope

Stage 34 replays any agentic-shape transcript through a generic parser, renderer, and expected-hit analyzer, then exercises a server-backed replay flow that must respect concurrent main/subagent cache reuse and main-agent continuation after subagent return. The flow must work on a synthetic generic fixture that covers main + subagent + return + continuation + exact duplicate burst, and on a real captured transcript that exposes only main and subagent events.

In scope:

- Generic parser correctness and stable branch id assignment
- Renderer sidecar metadata, hashed token plan, opt-in raw prompt capture
- Expected-hit analyzer behavior on synthetic and real fixtures, with preflight fail-on-missing-token/checksum
- Dry-run replay runner covering sequential and concurrent modes
- Result analyzer precedence between primary signal and fallback signal
- Python regression for the cached-tokens precedence rule
- Concurrent main/subagent namespace sharing and unsafe-prefix policy
- Sequential main-agent continuation after subagent return with parent-tip candidate source
- Stage 3 restore-plan deep-copy regression (target + draft byte vectors surviving eviction)
- D-EXEC-24-03 Stage 27 fix durability on the long-spaced duplicate workload
- Cold-store auto-load and cold-budget under-sizing policy (D34-OQ-05)
- Hot and cold budget floors plus 512 MiB round-up rule
- Observability counters, cold-store filesystem byte proof, and server log scan
- Generic acceptance for any new agentic workload that exposes main, subagent, return, and continuation rows

Out of scope:

- Live Qwen MTP replay execution in this plan (executed only during a later QA execution session)
- Authoring or modifying production C++ or Python harness tests
- Opening the test-plan review session
- Committing or pushing any changes
- Modifying Stage 34 design or implementation log files
- Public metric label changes beyond what the Stage 32 closure already approved
- Stage 34 row output writing inside `._design_docs/` for any reason (F34-PATH-01 hard rule)

## Automation context

Reusable scripts:

- `._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1` (the entry point)
- `._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-replay-parser.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-request-renderer.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-result-analyzer.ps1`
- `._design_docs/cache-handling-test-scripts/_fixtures/stage34/synthetic-agentic.jsonl`

Acceptance precondition: a clean Release build must produce fresh `llama-server.exe`, `test-cache-controller.exe`, and `tests/test-stage34-result-analyzer.py` PASS. Build cleanliness and binary freshness follow the Stage 32 plan rules in [Part 36](./part-36-stage32-live-comparison-rerun.md).

## Output locations

Per-row output paths:

```text
_test_output/stage34-TP-34-<category>-<NN>/
```

Path rule (F34-PATH-01): every row writes only under project-root `_test_output/`. Any output that lands under `._design_docs/cache-handling-test-scripts/._test_output/` is a violation of this plan and must be classified `FAIL-path-violation` for the affected row. The wrong-tree residue must stay at `Test-Path = False`.

Durable reports do not belong in this part; per-session reports will live under `._design_docs/.test_reports/` if and only if a QA execution session opens.

## Preflight checks

Before running any row:

1. Verify `Test-Path ._design_docs/cache-handling-test-scripts/._test_output` returns `False`.
2. Verify `git status --short` shows no uncommitted durable-doc edits in this session beyond the QA planning artifacts.
3. Verify `tests/test-stage34-result-analyzer.py` passes via `python -m pytest tests/test-stage34-result-analyzer.py -q`.
4. Verify bare `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -Mode dry-run` writes `events.jsonl`, `requests.jsonl`, `expected-hits.jsonl`, and `summary.json` under `_test_output/stage34-dry-run/`.
5. Verify `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1 -EventsPath <events.jsonl> -OutputPath <outdir>/expected-hits.jsonl` exits 0 and writes one row per event.
6. Verify the per-row output directory is freshly allocated; reuse of an existing row directory is `BLOCKED-output-dir-reuse`.

## Evidence rows

Total: 31 rows across 13 categories.

### Parser (TP-34-PR)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-PR-01 | Run `replay-agentic-transcript.ps1 -Mode dry-run` against the bundled `synthetic-agentic.jsonl`. Inspect `events.jsonl` for `event_kind` coverage and stable branch id hashes. | One row per fixture row; `event_kind` set includes `main_request`, `subagent_request`, `subagent_return`, and `continuation`; each row has a non-empty `branch_id_hash`; parent links populated for `subagent_request`, `subagent_return`, and `continuation` where the fixture supplies a parent. |
| TP-34-PR-02 | Run `replay-agentic-transcript.ps1 -Mode dry-run -TranscriptPath` against the real captured transcript. Read `summary.json` `captured_events`, `reconstructed_events`, and `blocked_events` counts and inspect the `blocked_reason` field on each `events.jsonl` row that the parser reconstructed. | `summary.json` exists; parser never panics on the real fixture; rows missing a usable prompt carry `prompt_capture=reconstructed` and `blocked_reason=BLOCKED-transcript-incomplete`; the parser does not invent `subagent_return` or `continuation` rows that the real fixture does not expose; mismatches between fixture density and parser density classify at most as `BLOCKED-transcript-incomplete`. |

### Renderer (TP-34-RN)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-RN-01 | Run the replay runner with the synthetic fixture. For every `events.jsonl` row, open the matching `request-<id>.json` and verify the `metadata.stage34` sidecar and absence of raw prompt text. | Every `request-<id>.json` contains a `metadata.stage34` object with `request_id`, `transcript_row`, `session_id_hash`, `branch_id_hash`, `parent_branch_id_hash`, `agent_id_hash`, and `turn_index`; the request `messages` content is the `[stage34 blocked transcript row N]` placeholder unless `-IncludeRawPrompts` is set; no raw prompt text from the captured fixture leaks into the rendered request. |
| TP-34-RN-02 | Run the replay runner with `-IncludeRawPrompts` against the synthetic fixture. Verify a sibling `raw-prompts/` directory is created next to `events.jsonl`. | Per-event raw prompt files appear under `raw-prompts/` (or the documented sibling path); no raw prompt bytes leak into `events.jsonl`, `requests.jsonl`, `summary.json`, or any durable Markdown output. |

### Expected-hit analyzer (TP-34-AH)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-AH-01 | Read `expected-hits.jsonl` from the synthetic dry-run. Group rows by `candidate_source` and verify token count and checksum are populated on every hit row. | At least one `candidate_source=cross_branch_exact_checksum` row exists with `token_count > 0` and a non-empty `token_checksum`; every row satisfies `(token_count > 0) AND (token_checksum not empty) OR (bounded_miss_reason set)`. |
| TP-34-AH-02 | Construct an `events.jsonl` clone with a `render_policy=blocked_transcript_incomplete` row that still produces an exact-checksum collision. Run the analyzer against it. | Analyzer throws a `Stage 34 preflight ... lacks token_count/token_checksum` message and exits non-zero before writing output. |
| TP-34-AH-03 | Run `replay-agentic-transcript.ps1 -Mode dry-run` against the real captured transcript. Walk every row of `expected-hits.jsonl` and classify each as `captured` (has `token_count > 0` and non-empty `token_checksum`) or `BLOCKED-transcript-incomplete`. | Every row has either a captured token/checksum pair or a `BLOCKED-transcript-incomplete` `bounded_miss_reason`; rows are never both populated and ignored. |

### Replay runner (TP-34-RR)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-RR-01 | Run the replay runner with no `-TranscriptPath` and no `-OutputDir`. Verify it lands outputs under project-root `_test_output/stage34-dry-run/`. | `events_path`, `requests_path`, `expected_hits_path`, and `summary.json` paths in `summary.json` all begin with the project-root absolute path and end with `stage34-dry-run/`; no path begins with `._design_docs/`. |
| TP-34-RR-02 | Same as TP-34-RR-01 with explicit `-OutputDir _test_output/stage34-TP-34-RR-02`. | All four artifacts (`events.jsonl`, `expected-hits.jsonl`, `requests.jsonl`, `summary.json`) exist; `summary.json` parses as JSON; `events.jsonl` row count equals fixture row count; `expected-hits.jsonl` row count equals `events.jsonl` row count. |
| TP-34-RR-03 | Run the replay runner twice in this order: first with `-Mode sequential`, then with `-Mode concurrent`. (Both modes are deferred to QA execution in this plan; the dry-run path validates the event shape only. Live invocation requires a server URL.) | Event shape preserves branch id hashes and parent links across both modes; both runs terminate with `events.jsonl`, `expected-hits.jsonl`, `requests.jsonl`, and `summary.json`; parent-link rows in `expected-hits.jsonl` reference the expected predecessor request id; concurrent-mode and sequential-mode dry-runs without a server URL stay inside dry-run semantics. |

### Result analyzer (TP-34-RA)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-RA-01 | Read `stage34-result-analyzer.ps1` line-by-line. Verify the precedence order in `Get-Stage34CachedTokens`. | The function reads `usage.prompt_tokens_details.cached_tokens` first and falls back to `timings.cache_n` only when the primary signal is absent; primary signal takes precedence when both are present (verified by direct unit test). |
| TP-34-RA-02 | Same source, fallback branch. | When `usage.prompt_tokens_details` is missing or empty, the analyzer returns `[int]` of `timings.cache_n`; when both are missing the analyzer returns `0` (not a throw). |
| TP-34-RA-03 | Run `python -m pytest tests/test-stage34-result-analyzer.py -q`. | Exit code 0 and at least one test passing; the precedence test case asserts `usage.prompt_tokens_details.cached_tokens` wins over `timings.cache_n`. |

### Concurrent main/subagent sharing (TP-34-CC)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-CC-01 | Run the replay runner against a concurrent fixture with bounded branch fan-out. Inspect `expected-hits.jsonl` branch id distribution and any captured `llamacpp_cache_*` namespace metric. | Distinct branch id hash count stays at or below the documented bound for the concurrent fixture; namespace count never exceeds the branch fan-out cap. |
| TP-34-CC-02 | Inspect `expected-hits.jsonl` for `bounded_miss_reason=unsafe_prefix_rejected` and `expected_class=main_continuation_after_subagent_return` per D34-OQ-04. | Every `parent_branch_tip` row carries `bounded_miss_reason=unsafe_prefix_rejected`; no row appears with empty `bounded_miss_reason` on a parent-tip path. |
| TP-34-CC-03 | Verify synthetic dry-run produces at least one `cross_branch_exact_checksum` row with `branch_id_hash` populated. | At least one row has `candidate_source=cross_branch_exact_checksum` and a non-empty `branch_id_hash`; the predecessor `branch_id_hash` differs from the new row's `branch_id_hash`. |

### Sequential main-agent continuation (TP-34-SC)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-SC-01 | Inspect `expected-hits.jsonl` for the synthetic fixture. Confirm `parent_branch_tip` candidate source rows are emitted where the synthetic fixture supplies a `continuation` or `subagent_return` event. | Each synthetic `continuation` row produces a `parent_branch_tip` candidate source row with a non-empty `predecessor_request_id`. |
| TP-34-SC-02 | Inspect the synthetic fixture for an exact prompt collision on the same branch tip after a continuation. Verify the analyzer accepts the parent-state hit when the rendered prompt exactly matches. | When the synthetic fixture re-emits a parent-tip exact prompt, the row's `expected_result=hit` and `expected_class=exact_duplicate_request_burst`; when the fixture varies one token, the row's `bounded_miss_reason=unsafe_prefix_rejected`. |

### Restore-plan deep-copy coverage (TP-34-DC)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-DC-01 | Run `ctest --test-dir <build> -C Release -R test-cache-controller -V` and read `tests/test-cache-controller.cpp` around the Stage 34 deep-copy regression. | The Stage 34 deep-copy test exists at the documented line range; it admits target and draft bytes (documented 64 target + 32 draft), captures both via the documented hook, evicts the source payload, asserts source validation fails, and reasserts target and draft sizes plus byte patterns unchanged. |
| TP-34-DC-02 | Read the same test and confirm the captured target and draft byte vectors survive a subsequent eviction cycle and can be applied by the restore plan. | The test asserts `plan.target_bytes.size() == 64`, `plan.draft_bytes.size() == 32`, target byte pattern byte-equal before and after eviction, draft byte pattern byte-equal before and after eviction, and the test PASSES via ctest. |

### D-EXEC-24-03 hot-cache regression (TP-34-HC)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-HC-01 | Live replay of the Stage 33 long-spaced duplicate workload on the MTP fixture in hybrid mode (deferred to QA execution; this plan row is the contract). Server log must remain free of `STATUS_HEAP_CORRUPTION` past the Stage 27 fix crash threshold. | Replay reaches at least 250 requests without `STATUS_HEAP_CORRUPTION` (Stage 27 fix baseline); the Stage 27 fix remains durable across the Stage 34 concurrent reuse scope. |

### Cold-path tolerance (TP-34-CL)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-CL-01 | Live replay with `--cache-cold-path` configured (deferred to QA execution). Inspect namespace count and any captured cold auto-load log line per Session 31 plus Stage 29 design L96. | Cold-store auto-load reads the cold store at startup without inflating the namespace count above the documented bound; the auto-load completes before request traffic. |
| TP-34-CL-02 | Live replay with `--cache-cold-max-mib` set below the cold budget needed for the fixture's exact-duplicate burst (deferred to QA execution). Inspect `expected-hits.jsonl` for `bounded_miss_reason=EXPECTED-COLD-MISS` per D34-OQ-05. | Cold-budget under-sizing marks the affected rows `EXPECTED-COLD-MISS` in `expected-hits.jsonl` before live traffic; live cold cache misses still show non-zero cold path entries. |

### Budget sizing (TP-34-BS)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-BS-01 | Read the analyzer budget computation at the top of `analyze-stage34-expected-hits.ps1`. Verify the hot budget floor. | Hot budget resolves to `max(2048, requested)`; floor holds even when the caller passes a smaller hot budget. |
| TP-34-BS-02 | Same source, cold budget floor. | Cold budget resolves to `max(8192, requested)`; floor holds even when the caller passes a smaller cold budget. |
| TP-34-BS-03 | Compute the budget that the analyzer should adopt given hot 2048 MiB floor, and verify rounding. | Result rounds up to the next 512 MiB boundary (2048 MiB floor stays at 2048 MiB because 2048 is already a 512 MiB multiple); budget never lands between 512 MiB bands. |

### Observability (TP-34-OB)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-OB-01 | Live replay under hybrid mode (deferred to QA execution). Capture `/metrics` snapshots and grep for the hot/cold bytes, payload counts, evictions, demotions, promotions, and promotion failures counters. | All counters present and match the documented counter names; deltas over the replay window match the expected direction (positive for hots/colds and promotions on cold hits, non-negative otherwise). |
| TP-34-OB-02 | Live replay with `--cache-cold-path` configured (deferred to QA execution). Capture cold-store filesystem byte proof via the cold path root listing. | Cold-store filesystem byte total equals the per-id bytes sum within one 4 KiB block tolerance; no row exceeds the cold budget floor. |
| TP-34-OB-03 | Live replay (deferred to QA execution). Scan the server log for `checksum`, `token_count`, `namespace`, `restore-apply`, `crash`, and `request-error` patterns. | All six patterns appear when the corresponding product event happens; no `crash` or `request-error` pattern appears during a clean run; `restore-apply` appears at least once whenever any `expected_result=hit` row resolves. |

### Generic acceptance (TP-34-GA)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-34-GA-01 | Author a generic synthetic fixture with main + two subagent branches + subagent return + parent continuation + exact duplicate burst (no GitHub or Copilot-specific fields) and replay it through the runner. | The parser, renderer, and expected-hit analyzer process the generic fixture with the same code paths as the bundled fixture; branch count, expected-hit rows, and cross-branch hits match the generic fixture shape; no Copilot-specific keys are required. |
| TP-34-GA-02 | Run the runner against a second generic fixture that uses different agent names and an extra continuation row. | Both fixtures replay without code changes; the analyzer rejects non-conformant fixture rows with `BLOCKED-transcript-incomplete` instead of inventing parent rows. |

## Classification

PASS requires every evidence row to pass.

PARTIAL applies when an automated evidence row passes but a live row is deferred by the plan and the deferred row has a documented reason (no model fixture, deferred to QA execution, or outside this plan's window). The report must list completed legs, open rows, and preserved artifacts.

FAIL applies when any evidence row fails without a deferral reason, when the wrong-path tree under `._design_docs/cache-handling-test-scripts/._test_output/` reappears, when the parser panics on a non-pathological fixture, when the analyzer throws on a fixture row that has the documented token plan, or when the result analyzer returns the fallback signal when the primary signal is present.

BLOCKED applies to missing fixture, failed clean configure/build, missing CUDA proof, stale binary, missing required artifacts, host capacity limits that prevent valid row evidence, or model-backed rows that the QA execution session must run live.

## Handoff

Next owner: QA test-plan review. Product-code edits remain out of scope unless a later Stage 34 row produces live evidence that fails and Manager opens a correction loop.
