# Stage 23 S03 rerun 20260621-09 Developer review

Status: FAIL-product-crash
Date: 2026-06-21
Owner: Developer
Scope: test-results review of focused S03 rerun 20260621-09. No product code,
test code, runner code, or fixtures were changed.

## Verdict

FAIL-product-crash.

S03 reached request traffic with valid setup, CUDA active, clean build evidence,
redacted prompt evidence, and a writable cold path. `llama-server.exe` then
terminated before final metrics with exit code `-1073741819`. Windows
Application Error records exception `0xc0000005` in `llama-server-impl.dll`
with fault offset `0x00000000001f0bf1`. This is not a runner/setup failure and
not an acceptable reclassification candidate.

Bug id: F-23-S03-RERUN09-01.

## Inputs

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase23-design.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/cache-handling-phase23-implementation/part-16-architect-s03-startup-crash-fix-review.md`
- `._design_docs/.test_reports/stage23-s03-rerun-20260621-09.md`
- Evidence under `._test_output/stage23-s03-rerun-20260621-09/`

## Evidence reviewed

- Preflight: branch, dirty state, CUDA flag, fixture, port range, cold path,
  disk, clean build, `test-cache-controller`, binary freshness.
- Dry run and live wrapper side log: `batch-summary.log.side`.
- Row logs: `S03-Jnew/launch.log`, `launch.err`, `server.err.log`,
  `metrics-before.txt`, `resource-samples.csv`.
- Prompt evidence:
  `prompt-evidence/cache-prompt-evidence.jsonl`.
- Windows Application log for the live window.
- Source anchors for likely failing area:
  `tools/server/server-cache-hybrid.cpp` demotion, eviction, and payload-removal
  paths.

## Classification table

| Finding | Evidence | Classification | Decision |
| --- | --- | --- | --- |
| Clean build and focused unit gate passed | `preflight/12-test-cache-controller.log` reports 119/119 tests passed, including 7 Stage 23 focused tests; binaries are fresh at 2026-06-21 14:11 | Valid setup evidence | Does not reduce the crash to environment or stale binary. |
| CUDA and fixture gates passed | Server log lists CUDA0/CUDA1 RTX 5060 Ti and the Qwen3.5 MTP model; preflight shows no GPU process before the row | Valid setup evidence | Not an environment blocker. |
| Port/cold/evidence setup passed | Side log: `listeners=` empty, `coldItems=0`, `runRootWritable=true`; dry-run includes cold path and prompt evidence dir | Valid setup evidence | Not a runner/setup bug. |
| Live wrapper exit 1 | `preflight/17-wrapper-live-exit.txt` and side log `ok=False` with missing `metrics-after.txt` | Consequence of product crash | Wrapper correctly failed the row after server died. |
| Server reached request phase | `metrics-before.txt` exists; server log records many task launches and saves through task 9865 | Product phase reached | Failure is beyond startup; prior startup-crash fix remains cleared. |
| Process exit `-1073741819` | `S03-Jnew/launch.err` | Product bug | Windows maps this to access violation class failure. |
| Windows Application Error | 2026-06-21 14:23:19, exception `0xc0000005`, module `llama-server-impl.dll`, fault offset `0x00000000001f0bf1` | Product bug | Strong crash evidence. Symbolizer was not available in PATH. |
| Missing `metrics-after.txt` and `cap-exit.json` | Side log row gate lists `metrics-after.txt` missing; row stopped before cap | Consequence of product crash | Not a separate runner contract bug. |
| Prompt evidence redaction | 1645 JSONL rows, fields limited to IDs, hashes, profile, pair state, token counts, lookup outcome, prefix candidate | PASS evidence item | No raw prompt leak found. |
| S03 behavior incomplete | 507 `try_restore - found match`, 0 `unsafe_prefix_rejected`, 1645 `exact_entry_absent` before crash | Incomplete due to product crash | Cannot pass or reclassify while server dies. |
| Cold budget pressure | 107,055,836 bytes on disk, but server resident payload logs hit 561.766 MiB and repeated budget warnings under 512 MiB budget | Product symptom near crash | Likely related to bug; not acceptable because row crashed. |
| Repeated demotion pressure | 1122 `demote_payload`, 1122 `demotion failed`, 406 `eviction could not satisfy` | Likely root-cause area | Focus fix on async demotion plus immediate-eviction fallback. |

## Root-cause hypothesis

Likely root cause sits in `tools/server/server-cache-hybrid.cpp`, in the
hot-budget pressure path where `evict_until_within_budget()` calls
`mark_payload_evicted()`, `mark_payload_kind_evicted()` attempts
`demote_payload()`, and failure falls back to immediate eviction while older
demotion completions are still arriving.

The log pattern is consistent:

- resident payload bytes exceed 512 MiB
- `demote_payload` rejects new demotions because outstanding queued bytes plus
  requested bytes exceed budget
- `mark_payload_kind_evicted` falls back to immediate eviction
- later demotion completions continue to arrive for earlier payload ids
- process eventually AVs in `llama-server-impl.dll`

Primary code anchors:

- `hybrid_cache_controller::demote_payload()` around lines 365-470
- `hybrid_cache_controller::evict_until_within_budget()` around lines 2798-2840
- `hybrid_cache_controller::remove_payload()` around lines 3205-3238
- `hybrid_cache_controller::mark_payload_kind_evicted()` around lines 3253-3287

This may be a stale descriptor, stale entry payload id, or cold I/O completion
ownership bug under rapid fallback eviction. The next fix loop should prove the
exact lifetime break before patching.

## Product bug

F-23-S03-RERUN09-01: S03 large-branch-forest workload crashes under CUDA with
512 MiB RAM/cold budgets after request traffic starts.

Fix scope:

- Instrument or reproduce the crash with symbolized PDB evidence for
  `llama-server-impl.dll` fault offset `0x1f0bf1`.
- Audit demotion completion and fallback immediate eviction ownership for
  descriptors, hot payload records, entry payload ids, branch metadata, and
  prefix index state.
- Add focused regression coverage for demotion-budget rejection followed by
  immediate eviction while earlier demotion completions are still processed.
- Keep public surfaces and metric names unchanged unless a separate reviewed
  design change approves them.

## Required retest scope

After the fix and Architect review:

- Rebuild `test-cache-controller` and `llama-server` in `build-cov` Release.
- Run the new focused regression plus the existing Stage 22/23 controller
  regressions in `test-cache-controller`.
- Run one focused CUDA S03 rerun with the same shape as 20260621-09:
  Qwen3.5-4B-MTP, `--cache-mode hybrid`, `--cache-ram 512`,
  `--cache-cold-max-mib 512`, redacted prompt evidence, `--n-gpu-layers all`,
  `--fit off`, fresh cold path, fresh output root.
- Require no crash, `metrics-after.txt`, redacted prompt evidence, cold budget
  bounded or explicitly diagnosed, and S03 row behavior evidence before
  resuming S04..S08 or L01..L03.

## Next owner

Developer owns bug-fix loop F-23-S03-RERUN09-01. Architect reviews the fix and
regression evidence. QA owns the focused S03 rerun after Architect approval.
Manager decides when S04..S08 and L01..L03 may resume.

## Handoff

Stage 23 remains stopped at S03. Report 09 is a valid product-crash report.
Do not reclassify this run as setup, runner, environment, or acceptable blocked
coverage without a Manager decision backed by new evidence.

This file is ASCII-only and under the 300-line cap.
