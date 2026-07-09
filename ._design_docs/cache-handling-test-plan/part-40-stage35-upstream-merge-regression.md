# Test plan part 40: Stage 35 upstream merge regression

Status: corrected after QA test-plan review; pending re-review
Date: 2026-07-08
Stage: 35 (upstream merge cycle)
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: generic test planning for the Stage 35 open no-commit upstream merge. This is not execution evidence.

Correction note: F35-TP-01 selected the project-root
`_test_output/stage35-upstream-merge-YYYYMMDD-NN/` root for all non-durable
Stage 35 logs and artifacts.

## References

- [Stage 35 design](../cache-handling-phase35-design.md)
- [Stage 35 implementation entry](../cache-handling-phase35-implementation.md)
- [Merge/rework implementation plan](../cache-handling-phase35-implementation/part-06-merge-rework-implementation-plan-20260707.md)
- [Source merge fix evidence](../cache-handling-phase35-implementation/part-27-source-merge-fix-evidence-20260708.md)
- [F35-IMPL-01 rework evidence](../cache-handling-phase35-implementation/part-29-f35-impl-01-rework-evidence-20260708.md)
- [F35-IMPL-01 implementation re-review](../cache-handling-phase35-implementation/part-30-f35-impl-01-implementation-re-review-20260708.md)
- [Manager implementation gate](../cache-handling-phase35-implementation/part-31-manager-implementation-gate-20260708.md)
- [Stage 34 replay plan](./part-37-stage34-real-agentic-transcript-replay.md)
- [Stage 34 reopen plan](./part-38-stage34-reopen-idempotent-save-and-path-b.md)
- [Stage 35 test-plan review](./stage-35-test-plan-review-20260708.md)

## Scope

This part defines the regression package QA must run after Manager opens Stage
35 test execution. It covers the current no-commit merge against
`origin/upstream_master=47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.

In scope:

- Clean build and stale-binary enforcement.
- Source-ref and open-merge evidence before and after the run.
- Cache core focused regression.
- MTP, KV, speculative, and target/draft pair-state checks.
- Route/session lifecycle, stream resume, and router child-state checks.
- Checkpoint placement and message-span boundary checks.
- Metrics bounded-label and unique HELP/TYPE checks.
- Cold-store and filesystem checks when touched files include cold-store paths.
- Stage 34 replay or synthetic agentic rows when branch/session, stream resume,
  `tx_save`, save/restore, or slow-read paths changed.
- Focused coverage when feature-mode source files changed.

Out of scope:

- Treating Part 27, Part 29, or Part 30 focused evidence as QA execution
  evidence for this gate.
- Committing, pushing, opening a PR, writing reviewer responses, or aborting
  the merge.
- Running a full legacy-vs-hybrid comparison unless Manager explicitly expands
  the gate.
- Hiding obsolete rows behind exclusions. Remove stale rows in a later plan
  update if implementation scope changes.

## Execution preconditions

Each execution session creates a fresh report under
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`. Non-durable logs and
artifacts go under `_test_output/stage35-upstream-merge-YYYYMMDD-NN/`.

Before any test row runs:

1. Record `git status --short`.
2. Record `git rev-parse --verify MERGE_HEAD`.
3. Record `git rev-parse origin/upstream_master`.
4. Record `git ls-remote origin refs/heads/upstream_master`.
5. Verify `MERGE_HEAD`, `origin/upstream_master`, and remote
   `refs/heads/upstream_master` still match, or stop for Manager direction.
6. Create an empty per-session output root. Reusing an existing output root is
   `BLOCKED-output-dir-reuse`.

The clean build must run before evidence collection:

```powershell
Remove-Item -Recurse -Force build-stage35-qa -ErrorAction SilentlyContinue
cmake -B build-stage35-qa -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller -j 8

$Server = Get-Item build-stage35-qa\bin\Release\llama-server.exe
$Controller = Get-Item build-stage35-qa\bin\Release\test-cache-controller.exe
$NewestSource = Get-ChildItem tools\server,src,common,tests -Recurse -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($Server.LastWriteTime -lt $NewestSource.LastWriteTime -or
    $Controller.LastWriteTime -lt $NewestSource.LastWriteTime) {
    throw "Stage 35 binary is stale. Rebuild before testing."
}
```

Do not count evidence from `build-cuda` or any prior implementation-review
build as QA evidence unless that same directory was cleaned and rebuilt inside
the execution session.

## Evidence rows

### Build and source state

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-BLD-01 | Clean Release configure and build logs for `llama-server` and `test-cache-controller`, binary mtimes, newest touched source mtime, and build command. | Build exits 0; binaries are newer than touched source files; report cites logs and mtimes. |
| TP-35-SRC-01 | `MERGE_HEAD`, `origin/upstream_master`, remote `refs/heads/upstream_master`, and unresolved-path check. | SHAs match the Manager-approved source ref; no unresolved conflict paths remain. |

### Cache core

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-CORE-01 | Run `build-stage35-qa\bin\Release\test-cache-controller.exe` and capture full log. | All cache-controller tests pass, including Stage 34 idempotent save, Path B slow-read, deep-copy, and Stage 35 router-state rows. |
| TP-35-CORE-02 | Run `ctest --test-dir build-stage35-qa -C Release -R cache --output-on-failure` and capture raw log. | Selected cache suite reports pass with no failed or skipped required cache rows. |

### MTP, KV, speculative, and pair state

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-MTP-01 | Focused controller or unit evidence for no-draft, separate-draft, target-derived MTP, and separate-model MTP when fixtures exist. | Runtime shapes map only to `target_only` or `target_and_draft`; no third pair state is admitted. |
| TP-35-MTP-02 | MTP namespace and pair-state mismatch checks, plus target/draft eviction-unit evidence. | Cross-runtime restore is rejected without a hit; target and draft payloads still save, restore, promote, demote, and evict as one pair. |
| TP-35-MTP-03 | KV, SWA/ISWA, DeepSeek KV, or speculative context checks when those touched files affect cache compatibility. | Namespace or descriptor validation includes the new runtime discriminator, or the report records a bounded unsupported reason. |

### Routes, sessions, streams, and router child state

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-RT-01 | Public HTTP probes for touched route families: health, metrics, native completion, OpenAI chat, embeddings when exposed, slots, and model-management routes when present. | Routes return expected schemas; cache behavior is still selected by server flags and internal metadata, not public cache-specific fields. |
| TP-35-RT-02 | Router child state smoke, including `tools/server/tests/unit/test_router.py::test_router_props` or the current targeted router test set. | Router child loading, ready, sleeping, and resume states are observable without replacing local sleep destroy/reload behavior. |
| TP-35-RT-03 | Stream resume or SSE replay smoke when touched files include `server-stream.*`, UI stream identity paths, or session lifecycle code. | Stream ids, session ids, request ids, and replay ids stay out of cache namespace unless they change model/template/runtime ABI. |

### Checkpoint placement and message spans

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-CP-01 | Unit or focused evidence for `task_params::message_spans.last_user_message_pos()` based checkpoint gating. | User-message checkpoint boundary equals `[0, message_token_end]`; missing or unsafe boundary metadata produces a bounded fallback. |
| TP-35-CP-02 | Positive checkpoint admission and negative shifted-boundary rejection, using public chat only when a capable fixture exists. | Descriptor attachment happens only after token-span, checksum, workload profile, namespace, and pair-state validation. |

### Metrics and diagnostics

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-MET-01 | Capture `/metrics` before and after cache traffic. Parse cache metric labels and HELP/TYPE blocks. | Labels are bounded; HELP and TYPE blocks are unique per metric; hybrid, checkpoint, restore, payload, and transition counters remain present where applicable. |
| TP-35-MET-02 | Scan metrics, logs, and durable report for prompt text, marker text, model paths, file paths, checksums, payload bytes, session ids, stream ids, and request ids in public cache labels. | No prompt-local or path-like value appears in public cache labels; diagnostics use bounded reasons. |

### Cold store and filesystem

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-CS-01 | Required only when touched files include `server-cache-store.*`, `server-cache-io.*`, descriptor serialization, path normalization, or filesystem helpers. Capture cold root setup, root containment proof, checksum proof, atomic write/rename proof, and file byte totals. | Cold paths stay under the configured root; descriptor checksum and version checks hold; file byte totals match metric totals within filesystem block tolerance. |

### Stage 34 replay and synthetic agentic rows

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-AG-01 | Required when touched files include branch/session, stream resume, `tx_save`, save/restore, slow-read, router child state, or Stage 34 replay harness paths. Run the Stage 34 synthetic agentic dry-run and any selected live row opened by Manager. | Synthetic rows cover branch, session, subagent return, continuation, exact duplicate burst, `tx_save`, save/restore, and slow-read paths without writing under `._design_docs/cache-handling-test-scripts/._test_output/`. |
| TP-35-AG-02 | If live replay runs, capture expected-hit rows, cached-token extraction, cache metrics, cold-store bytes when enabled, and server log scan. | Hits and bounded misses match the analyzer contract; `usage.prompt_tokens_details.cached_tokens` remains the primary signal; fallback to `timings.cache_n` is used only when primary signal is absent. |

### Coverage

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-35-COV-01 | Required when feature-mode source files changed: `tools/server/server-cache-*`, `server-context.*`, `server-task.*`, `server-stream.*`, `common/speculative.*`, `src/llama-kv-*`, checkpoint paths, or cache-related tests. Run focused coverage or record Manager-approved fixture/tool blocker. | Report cites markdown combined, product-only, and per-file coverage blocks. T114, T114a, and T115-style thresholds use the markdown report, not XML root attributes. |

## Evidence format

The execution report must include:

- test run id and artifact root;
- source-ref proof and open-merge proof;
- clean build commands, logs, binary paths, and mtimes;
- per-row command, raw log path, and PASS/FAIL/BLOCKED/SKIP result;
- model and draft fixture paths or explicit fixture-blocker reason;
- HTTP request/response snippets for route rows;
- metrics before/after paths and HELP/TYPE parser output;
- cold-store filesystem listing when TP-35-CS-01 applies;
- Stage 34 replay output paths when TP-35-AG rows apply;
- coverage report paths when TP-35-COV-01 applies;
- bug handoff with exact command, log path, failing row, and source state for
  each FAIL.

## Classification

PASS requires every required row to pass in the fresh QA report. Optional rows
can be `SKIP` only when the plan marks them conditional and the report proves
the triggering files or fixtures were not present.

FAIL applies when any required row fails, when stale binaries are used, when the
source-ref check drifts without Manager approval, when public metric labels gain
unbounded values, when cache namespace includes prompt-local route/session
fields, or when Stage 34 output lands under the durable docs tree.

BLOCKED applies when a clean build cannot be produced, a required model or MTP
fixture is missing, coverage tooling is unavailable, host capacity prevents a
valid live row, or Manager direction is needed for source-ref drift.

## Command checklist

```powershell
git status --short
git rev-parse --verify MERGE_HEAD
git rev-parse origin/upstream_master
git ls-remote origin refs/heads/upstream_master
git diff --name-only HEAD -- tools/server src common tests

Remove-Item -Recurse -Force build-stage35-qa -ErrorAction SilentlyContinue
cmake -B build-stage35-qa -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller -j 8

build-stage35-qa\bin\Release\test-cache-controller.exe
ctest --test-dir build-stage35-qa -C Release -R cache --output-on-failure

$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build-stage35-qa\bin\Release\llama-server.exe).Path
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
python -m pytest -q tools/server/tests/unit/test_router.py::test_router_props

pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\replay-agentic-transcript.ps1 `
  -Mode dry-run `
  -OutputDir _test_output\stage35-upstream-merge-YYYYMMDD-NN\stage34-synthetic
```

Coverage command, only when TP-35-COV-01 applies:

```powershell
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\run_coverage.ps1 `
  -BuildDir build-stage35-qa `
  -OutDir _test_output\stage35-upstream-merge-YYYYMMDD-NN\coverage
```

## Handoff

Next owner: QA test-plan reviewer.
Next gate: Stage 35 test-plan review. Test execution starts only after Manager
opens the execution gate.
