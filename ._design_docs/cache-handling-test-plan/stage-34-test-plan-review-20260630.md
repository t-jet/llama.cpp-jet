# Stage 34 test-plan review 2026-06-30

VERDICT: PASS

## Scope

Review subject:

- `._design_docs/cache-handling-test-plan/part-37-stage34-real-agentic-transcript-replay.md`
- `._design_docs/cache-handling-test-plan.md` (TOC entry)
- `._design_docs/document-index.md` (row added for part-37)
- `._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1` (parent-directory creation, `Set-StrictMode` fix)

Inputs checked (referenced, not re-reviewed):

- `._design_docs/.manager-inputs/manager-input-20260630-stage34-real-agentic-transcript-replay.md` (Manager intake brief)
- `._design_docs/cache-handling-phase34-design.md`
- `._design_docs/cache-handling-phase34-implementation/part-05-rework-evidence-20260630.md`
- `._design_docs/cache-handling-phase34-implementation/part-06-implementation-re-review-20260630.md`
- `._design_docs/cache-handling-test-plan/part-29-stage24-chat-s02-s03-comparison.md`
- `._design_docs/cache-handling-test-plan/part-30-stage25-atomic-transactional.md`
- `._design_docs/cache-handling-test-plan/part-35-stage31-hybrid-cache-misbehavior.md`
- `._design_docs/cache-handling-test-plan/part-36-stage32-live-comparison-rerun.md`
- `._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-result-analyzer.ps1`
- `tests/test-stage34-result-analyzer.py`

No tests were executed. No product code or harness script was modified. This is
a plan review only.

## Scope coverage matrix (Manager intake brief -> part-37 rows)

| Manager intake requirement | Covered by part-37 rows | Verdict |
| --- | --- | --- |
| Main-agent continuation after subagent return, with reuse of previous cached prompt/session state | TP-34-SC-01, TP-34-SC-02 (`parent_branch_tip` candidate source rows on `continuation` or `subagent_return`) | PASS |
| Subagent calls reusing compatible cache state without full prompt-token recalculation | TP-34-CC-01 (bounded branch fan-out), TP-34-CC-03 (cross-branch exact checksum reuse), TP-34-AH-01 (token_count + token_checksum on hit rows) | PASS |
| Concurrent main-agent and subagent execution against the same cache state with safe sharing, isolation, validation rules | TP-34-RR-03 (`-Mode concurrent`), TP-34-CC-01..03 (namespace metric, unsafe-prefix policy, cross-branch reuse) | PASS |
| Replay of `._analysis/chat_log.jsonl` while keeping the solution generic | TP-34-PR-02 (real-fixture parser run), TP-34-AH-03 (real-fixture analyzer run), TP-34-GA-01/02 (generic-fixture acceptance) | PASS |
| Workload-shape decisions: request/response mapping, main/subagent branch identity, return-to-parent, expected-hit measurement | TP-34-PR-01/02 (parser), TP-34-RN-01/02 (renderer sidecar), TP-34-AH-01/02/03 (expected-hit analyzer) | PASS |
| Cache policy decisions for hot retention, cold restore, branch graph, checkpoint, namespace, prompt identity | TP-34-BS-01/02/03 (budget floors), TP-34-CL-01/02 (cold-path policy), TP-34-DC-01/02 (restore-plan deep-copy) | PASS |
| Observability for reuse: cached token counts, hit/miss deltas, namespace count, restore miss reasons, branch lookup candidates, bounded evidence | TP-34-OB-01/02/03, TP-34-RA-01/02/03 (cached-tokens precedence), TP-34-AH-01/02/03 (bounded miss reasons) | PASS |
| Regression coverage for generic agentic workloads | TP-34-HC-01 (D-EXEC-24-03 Stage 27 durability), TP-34-DC-01/02 (deep-copy regression), TP-34-GA-01/02 (generic-acceptance rows) | PASS |

All eight Manager intake requirements map to at least one part-37 row, with no
duplication or omission.

## Per-check verdict table

| Check | Decision rule | Verdict | Observation |
| --- | --- | --- | --- |
| Scope alignment | Test plan rows implement every requirement in the Manager intake brief | PASS | 8/8 requirements covered (matrix above) |
| Generic wording | No specific run citations, no `_analysis/chat_log.jsonl` row counts, no Copilot-specific terms in part-37 evidence language | PASS | `Select-String` for `Copilot\|chat_log\.jsonl\|_analysis` returns zero hits in part-37 (confirmed) |
| Coverage adequacy | Parser, renderer, expected-hit analyzer, replay runner (sequential + concurrent), result analyzer, hot-cache regression, cold-path tolerance, budget sizing, observability, generic acceptance | PASS | 31 rows across 13 categories (PR 2, RN 2, AH 3, RR 3, RA 3, CC 3, SC 2, DC 2, HC 1, CL 2, BS 3, OB 3, GA 2) |
| Stale content removal | No leftover references to F34-PATH-01 wrong path; recursive `Get-ChildItem -Force` filtered on `._test_output*` inside `cache-handling-test-scripts/` returns empty set | PASS | `Test-Path ._design_docs\cache-handling-test-scripts\._test_output` returns `False`; recursive search returns no rows; part-37 preserves the policy statement and preflight check as durable documentation, not residue |
| Evidence format | Each row has pre-conditions, action, expected artifacts, pass criteria, failure classification; output paths under project-root `_test_output/stage34-*` | PASS | 3-column table (Row / Evidence / PASS signal) consistent with part-35 and part-36 patterns; pre-conditions consolidated in `Preflight checks`; failure classification consolidated in `Classification` section; per-row paths use `_test_output/stage34-TP-34-<category>-<NN>/` template |
| Automation soundness | Bare `replay-agentic-transcript.ps1 -Mode dry-run` exits 0; bare `analyze-stage34-expected-hits.ps1` writes expected-hits to caller-chosen path; `python -m pytest tests/test-stage34-result-analyzer.py -q` passes | PASS | Dry-run exit code 0 with summary (6/6 transcript rows, 1 exact hit, 6 captured, 0 blocked); analyzer with caller-chosen path exit code 0; pytest 1 passed |
| Clean-build rule | Test plan requires clean Release CUDA build before test execution | PASS | Preflight #1 and Acceptance precondition in part-37 reference the Stage 32 / part-36 build rules; clean Release `llama-server`, `test-cache-controller`, and pytest PASS required before any row |
| Decision criteria clarity | Each row classifies PASS / FAIL / BLOCKED-* / PARTIAL / SKIP with explicit signal | PASS | Global Classification section defines PASS / PARTIAL / FAIL / BLOCKED with explicit triggers; row PASS signals enumerate observable artifact properties |
| Hygiene | `git diff --check` clean for new/changed files; LF-only; <=300 lines per file; no BOM; no trailing whitespace | PASS | `git diff --check` on `cache-handling-test-plan.md` and `document-index.md` returns no warnings; part-37 line count 216 (under 300); analyzer 93 lines; recursive F34-PATH-01 search returns empty |

## Automation re-run output

Bare `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -Mode dry-run`:

```text
Stage34 expected-hit rows written: D:\source\llama.cpp-jet\_test_output\stage34-dry-run\expected-hits.jsonl
Stage34 expected hit rows: 1
Stage34 dry-run summary:
{
  "mode": "dry-run",
  "transcript_path": "D:\\source\\llama.cpp-jet\\._design_docs\\cache-handling-test-scripts\\_fixtures\\stage34\\synthetic-agentic.jsonl",
  "transcript_rows": 6,
  "replay_events": 6,
  "captured_events": 6,
  "reconstructed_events": 0,
  "blocked_events": 0,
  "events_path": "D:\\source\\llama.cpp-jet\\_test_output\\stage34-dry-run\\events.jsonl",
  "requests_path": "D:\\source\\llama.cpp-jet\\_test_output\\stage34-dry-run\\requests.jsonl",
  "expected_hits_path": "D:\\source\\llama.cpp-jet\\_test_output\\stage34-dry-run\\expected-hits.jsonl",
  "raw_prompt_capture": false
}
EXIT=0
```

Bare `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1 -EventsPath _test_output/stage34-dry-run/events.jsonl -OutputPath _test_output/stage34-TP-34-AH-verify/expected-hits.jsonl`:

```text
Stage34 expected-hit rows written: _test_output/stage34-TP-34-AH-verify/expected-hits.jsonl
Stage34 expected hit rows: 1
EXIT=0
```

The analyzer creates the parent directory `_test_output/stage34-TP-34-AH-verify/` (parent-directory creation confirmed via `New-Item -ItemType Directory -Force -Path` in lines 13-15 of the script).

`python -m pytest tests/test-stage34-result-analyzer.py -q`:

```text
.                                                                                                                                      [100%]
1 passed in 0.02s
EXIT=0
```

The precedence rule in `tests/test-stage34-result-analyzer.py` (`stage34_cached_tokens` returns `usage.prompt_tokens_details.cached_tokens` when present and falls back to `timings.cache_n`) matches the precedence rule in `stage34-result-analyzer.ps1` (`Get-Stage34CachedTokens` reads `usage.prompt_tokens_details.cached_tokens` first and falls back to `timings.cache_n` only when the primary signal is absent).

Dry-run output directory contents (`_test_output/stage34-dry-run/`):

```text
events.jsonl        5967 bytes
expected-hits.jsonl 2969 bytes
requests.jsonl      1020 bytes
summary.json         620 bytes
request-row-00001.json .. request-row-00006.json (one per fixture row)
```

All four required artifacts present; output rooted at project-root `_test_output/`, not under `._design_docs/cache-handling-test-scripts/._test_output/`.

## Non-blocking findings

1. `cache-handling-stage-tracker.md` row 34 currently reads "OPEN 2026-06-30 (Implementation re-review ready after path-correction rework)" and "ready for Architect re-review". It does not mention the test-plan status. Once Manager accepts this plan, a one-line addition to that cell (for example, "Test plan PASS 2026-06-30") would keep the tracker aligned with the gate flow. Not a blocker; the row already records the path-correction rework and the latest-test-report cell stays empty until execution opens.

2. The Evidence column header in part-37 tables is `Evidence` and combines action plus expected-artifact into one cell. The Manager intake matrix above verifies the substance; a future part-37 sibling could split them into two columns for explicit per-row auditability. Not a blocker; the pattern matches part-35 and part-36.

## Gate

Stage 34 test plan is ready for Manager test-plan gate. After gate PASS, QA
execution can open with a clean Release build, fresh per-session report under
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`, and per-row outputs
under project-root `_test_output/stage34-*`. Live rows (TP-34-HC-01,
TP-34-CL-01/02, TP-34-OB-01/02/03) remain deferred to execution; the plan
preserves them as the contract for that session.

## Handoff

Next owner: Manager test-plan gate.
Next gate: Test-plan gate.
Future gate after Manager acceptance: Test execution.
