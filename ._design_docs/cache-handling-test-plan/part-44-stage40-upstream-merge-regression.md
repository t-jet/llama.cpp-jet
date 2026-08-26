# Test plan part 44: Stage 40 upstream merge regression

Status: pending QA test-plan review
Date: 2026-08-26
Stage: 40 (upstream merge cycle)
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: generic test planning for the Stage 40 open no-commit upstream merge. This is not execution evidence.

## References

- [Stage 40 design](../cache-handling-phase40-design.md)
- [Stage 40 pre-merge analysis](../cache-handling-phase40-implementation/part-01-pre-merge-analysis-20260826.md)
- [Stage 40 merge/rework implementation plan](../cache-handling-phase40-implementation/part-06-merge-rework-implementation-plan-20260826.md)
- [Stage 39 two-layer retention plan](./part-43-stage39-two-layer-retention.md)
- [Stage 38 prefix restore plan](./part-42-stage38-prefix-restore-cold-budget.md)
- [Stage 36 hybrid hit performance plan](./part-41-stage36-hybrid-hit-performance-validation.md)
- [Stage 34 replay plan](./part-37-stage34-real-agentic-transcript-replay.md)
- [Stage 35 upstream merge regression](./part-40-stage35-upstream-merge-regression.md)

## Scope

This part defines regression evidence QA must collect after Manager opens Stage 40 test execution. Merge open at MERGE_HEAD fc35562ba (1799 staged files, 10 text conflicts resolved, 2 BLOCKING compile fixes F1/F7). Fork point: 47e1de77aa0f06bf73cfd8c5281d95979f89fcbe.

In scope:

- Clean build and stale-binary enforcement: build dir build-cuda (or approved), Release config, llama-server test-cache-controller targets.
- Source-ref proof: git rev-parse MERGE_HEAD, fork point, upstream tip.
- Cache core focused regression: ctest -C Release -R cache.
- MTP/KV/speculative pair-state (Track 1): target/draft pair validity, namespace isolation -- EAGLE3/DSv4/Step-MTP/DFlash/init-refactor commits.
- Route/session lifecycle (Track 2): SSE replay buffer, /v1/responses, slot dispatch, stream resume -- preserves I-34-01/I-34-02.
- Checkpoint placement (Track 3): checkpoint at every user-msg, every-n-tokens, multi-modal caching, hybrid checkpointing.
- Two-layer retention + partial restore (Stages 38/39): prefix/checkpoint partial restore contract, cold-budget gauge cache_cold_budget_bytes{mode="hybrid"} = 2147483648 for 2048 MiB.
- Metrics bounded-label + unique HELP/TYPE: cache_hits_total{mode="hybrid"}, cold-budget gauge.
- Public HTTP probes for touched route families.
- Focused coverage when feature-mode files changed (combined + product-only blocks).
- Stage 36 hybrid hit/performance when driver lineage touched.
- Stage 34 replay/synthetic agentic when session/stream/tx_save paths touched.

Out of scope:

- Treating part-16/part-18 fix evidence as QA execution evidence.
- Upstream CI/test/lint as evidence.
- Replacing local focused tests with upstream tests.

## Execution preconditions

Each execution session creates a fresh report under ._design_docs/.test_reports/test-report-YYYYMMDD-NN.md. Non-durable logs and artifacts go under _test_output/stage40-upstream-merge-YYYYMMDD-NN/.

Before any test row runs:
1. Record git status --short.
2. Record git rev-parse --verify MERGE_HEAD.
3. Record git rev-parse origin/upstream_master.
4. Record git ls-remote origin refs/heads/upstream_master.
5. Verify SHAs still match or stop for Manager direction.
6. Create empty per-session output root. Reusing existing root is BLOCKED-output-dir-reuse.

### Clean build

Full CUDA rebuild may exceed wall-clock budget; plan relink-first, with CPU-only fallback build dir option.

Primary path -- staleness check + relink:

Get-Item build-cuda\bin\Release\llama-server.exe and test-cache-controller.exe mtime vs newest source. If stale, relink: cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 4. Verify mtime updated.

If relink fails (semantic conflict the 3-way merge missed), classify session as BLOCKED with build defect. Pair with Developer fixes file.

Fallback -- full clean build (time-capped, may span sessions):
cmake -B build-stage40-qa -S . -DCMAKE_BUILD_TYPE=Release -DLLAMA_CUDA=OFF && cmake --build build-stage40-qa --config Release --target llama-server test-cache-controller -j 4

If CUDA rebuild required, expect >30 min. Use -DLLAMA_CUDA=OFF for faster CPU-only regression build if CUDA-specific tests not in scope.

## Evidence rows

### Build and source state

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-BLD-01 | Release build logs for llama-server and test-cache-controller, binary mtimes, newest source mtime, build command, tree choice. | Build exits 0; binaries newer than source. If relink, cite command and mtime. |
| TP-40-SRC-01 | MERGE_HEAD, origin/upstream_master, remote refs/heads/upstream_master, fork point, unresolved-path check. | SHAs match Manager-approved ref; no conflict paths remain. |

### Cache core

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-CORE-01 | Run build-cuda\bin\Release\test-cache-controller.exe and capture full log. | All cache-controller tests pass including Stage 34 idempotent save, Path B slow-read, deep-copy, merged route-state rows, MTP pair-state, checkpoint. |
| TP-40-CORE-02 | ctest --test-dir build-cuda -C Release -R cache --output-on-failure. | Cache suite pass with no failed/skipped required rows. |

### MTP, KV, speculative, pair state (Track 1)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-MTP-01 | Focused evidence for no-draft, separate-draft, target-derived MTP, separate-model MTP when fixtures exist. | Runtime shapes map to target_only or target_and_draft only; EAGLE3/DSv4/Step-MTP shapes valid. |
| TP-40-MTP-02 | MTP namespace and pair-state mismatch checks, target/draft eviction-unit evidence. | Cross-runtime restore rejected; pairs save/restore/promote/demote/evict as one. |
| TP-40-MTP-03 | KV, SWA/ISWA, DSv4 KV, speculative context checks when touched files affect cache compat. | Namespace validation includes new runtime discriminator, or bounded unsupported reason. |

### Routes, sessions, streams (Track 2)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-RT-01 | HTTP probes for touched routes: /health, /metrics, native completion, OpenAI chat, /v1/responses. | Routes return expected schemas; cache selected by server flags not public fields. |
| TP-40-RT-02 | Stream resume/SSE replay smoke when server-stream.*, session code, or SSE buffer touched. | IDs stay out of namespace unless ABI change. |
| TP-40-RT-03 | I-34-01/I-34-02: idempotent save and slow read outside cache_state_mutex via focused evidence. | Idempotent counts match; no read under mutex in tx_save. |

### Checkpoint placement (Track 3)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-CP-01 | Focused evidence for checkpoint-at-every-msg, every-n-tokens, multi-modal, hybrid triggers. | Checkpoint attachment only after token-span, checksum, profile, namespace, pair-state validation. No second cold writer. |
| TP-40-CP-02 | Positive admission and negative shifted-boundary rejection via public chat if fixture exists. | Descriptor at valid boundaries; shifted falls back to recompute. |

### Metrics and diagnostics

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-MET-01 | /metrics before/after cache traffic; parse HELP/TYPE. | Labels bounded; HELP/TYPE unique; cache_hits_total{mode="hybrid"} present. |
| TP-40-MET-02 | Scan for prompt text, paths, checksums, payload bytes, IDs in public labels. | No prompt-local/path values; bounded reasons. |
| TP-40-MET-03 | cache_cold_budget_bytes{mode="hybrid"} from /metrics. | 2147483648 for 2048 MiB; 64-bit no narrowing. |

### Two-layer retention + partial restore (Stages 38/39)

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-PRS-01 | Required when touched files include server-cache-hybrid.*, policy.*, controller.*, cold-store, retention, partial-restore. Run Stage 38 prefix smoke + Stage 39 retention test. | Chat strict-prefix only at checkpoint-safe; /completion recompute-only; cold-budget holds. |

### Cold store

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-CS-01 | Required when server-cache-store.*, io.*, serialization, path helpers touched. Cold root, containment, checksum, atomic write. | Paths under root; checksum/version hold; bytes match metrics within block tolerance. |

### Stage 36 hybrid hit/performance

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-HYB-01 | Required when driver lineage touched (test-scripts/**, compare-legacy*). Run 48-row 8-burst 6-repeat workload. | 40 hits 8 misses both legs; output diff empty; hot bytes >=40% below legacy; throughput <= 10% off. |

### Stage 34 replay

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-AG-01 | Required when branch/session, resume, tx_save, save/restore, slow-read, SSE buffer, or replay harness touched. Run synthetic dry-run. | Covers branch, session, subagent, continuation, exact burst, tx_save, save/restore, slow-read. |
| TP-40-AG-02 | If live replay runs: expected-hit rows, cached_tokens, cache metrics, cold-store bytes, log scan. | Hits and misses match analyzer; cached_tokens primary. |

### Coverage

| Row | Evidence | PASS signal |
| --- | --- | --- |
| TP-40-COV-01 | Required when feature-mode files changed (server-cache-*, context.*, task.*, speculative.*, llama-kv-*, checkpoint, retention, partial-restore). Run focused coverage or record blocker. | Combined, product-only, per-file blocks. Floor 0.8486 per TP-39-03. VS2022 gap noted. |

## Evidence format

Each row in the execution report lists an evidence path (file, log, or metric snapshot), a verdict label, and a per-row classification: PASS, FAIL, PARTIAL, BLOCKED, or N/A. Evidence paths are relative to the session output root. Verdict labels are the first word of the verdict cell, capitalised. Example: `PASS build exits 0` or `BLOCKED relink failed semantic conflict`.

## Classification

PASS: all required rows pass in fresh QA report. Conditional rows SKIP only when plan marks them and report proves trigger absent.

FAIL: any required row fails, stale binaries, source-ref drift, unbounded labels, prompt-local fields in namespace, Stage 34 output in durable docs tree.

BLOCKED: no clean build (incl relink failure from semantic conflict), missing fixture, no coverage tooling, host capacity insufficient, Manager direction needed.

PARTIAL: conditionals exceed capacity but all required pass. Report which SKIP and why.

## Command checklist

git status --short
git rev-parse --verify MERGE_HEAD
git rev-parse origin/upstream_master
git ls-remote origin refs/heads/upstream_master
git diff --name-only HEAD -- tools/server src common tests

Staleness check + relink:
Get-Item build-cuda\bin\Release\llama-server.exe, test-cache-controller.exe
Compare mtime vs newest source. Relink if stale.

Focused cache tests:
build-cuda\bin\Release\test-cache-controller.exe
ctest --test-dir build-cuda -C Release -R cache --output-on-failure

## Handoff

Next owner: QA test-plan reviewer.
Next gate: Stage 40 test-plan review. Test execution after Manager opens gate.
