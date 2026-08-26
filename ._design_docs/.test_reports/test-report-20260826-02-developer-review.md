# Stage 40 test-results review (Developer)

Date: 2026-08-26
Reviewer: Developer
Report: test-report-20260826-02.md
Status: REWORK

## Per-row classification

| Row | Verdict | Analysis | Owner |
| --- | --- | --- | --- |
| TP-40-BLD-01 | PASS | Binaries fresh (19:37 / 19:41), all sources older. Reuse sound. | QA |
| TP-40-SRC-01 | PASS | MERGE_HEAD fc35562ba intact; fork point matches plan. | QA |
| TP-40-CORE-01 | PASS | 146 PASSED, 0 FAILED. Direct run. | QA |
| TP-40-CORE-02 | PASS | ctest -R cache 1/1, 1.80s. | QA |
| TP-40-MTP-01 | PASS | MTP model loads, 512 tokens decode, no crash. F-22-01 flow verified via common_speculative_process. | QA |
| TP-40-MTP-02 | PASS | MTP pair-state covered by test-cache-controller. | QA |
| TP-40-MTP-03 | PASS | KV/DSv4 namespace covered by core tests. | QA |
| TP-40-RT-01 | PASS | /health ok, /v1/chat/completions valid schema. | QA |
| TP-40-RT-02 | REWORK (reviewer) | Report-labeled SKIP, but merge shipped `tools/server/tests/unit/test_stream.py` (3 resume tests, ~153 lines) covering SSE replay/reload resume/stop-evict. SKIP claim "no slot-stickiness fixture" contradicts merged tree. Needs harness route. Plan requires evidence when server-stream.* touched. Owner: QA. | QA |
| TP-40-RT-03 | PASS | I-34-01/02 covered by test-cache-controller. | QA |
| TP-40-CP-01 | PASS | Checkpoint triggers covered by core tests + MTP server log "created context checkpoint 1 of 32". | QA |
| TP-40-CP-02 | N/A | No multi-turn hybrid-boundary chat fixture in legacy run; plan conditional. Correct classification. | QA |
| TP-40-MET-01 | REWORK (reviewer) | HELP/TYPE unique, labels bounded, but only mode="legacy" tested. Plan PASS signal requires `cache_hits_total{mode="hybrid"}`. No hybrid flag run. Owner: QA | QA |
| TP-40-MET-02 | PASS | No prompt text/paths in labels. | QA |
| TP-40-MET-03 | REWORK (reviewer) | Verdict PASS cites `{mode="legacy"} -1`, but plan PASS signal is `{mode="hybrid"} 2147483648` for 2048 MiB (Stage 38 D36-FU-01). Legacy -1 not the contract. Cold-gauge + hybrid-mode belongs to PRS-01 retest scope. | QA |
| TP-40-PRS-01 | N/A | Trigger absent: no server-cache-hybrid.*, policy.*, controller.*, cold-store, or retention files in MERGE_HEAD diff. llama-memory-hybrid.cpp change is upstream recurrent-rollback batching, not this repo's retention code. Correct. | QA |
| TP-40-CS-01 | N/A | No server-cache-store.*/io.* touched in diff. Correct. | QA |
| TP-40-HYB-01 | N/A | No driver lineage (test-scripts/**, compare-legacy*) touched. Correct. | QA |
| TP-40-AG-01 | N/A | No replay harness/branch-session files touched. Correct. | QA |
| TP-40-AG-02 | N/A | Trigger absent. Correct. | QA |
| TP-40-COV-01 | REWORK (reviewer) | Report BLOCKED justification "no gcov/lcov; GCC rebuild needed" is wrong for this repo. MSVC coverage path is established: OpenCppCoverage 0.9.9.0 (present at D:\app\OpenCppCoverage\OpenCppCoverage.exe) + `run_coverage.ps1` + `build-cov` dir with `/Zi /DEBUG:FULL` (Stage 18 D18-IMPL-01 precedent). Option A: reconfigure build-cov RelWithDebInfo + PDB and reuse existing run_coverage.ps1 (no GCC rebuild; ~10-15 min focused vs 30 min for full GCC clean build). Option B: GCC rebuild (LLAMA_CUDA=OFF, ~30 min) to satisfy the plan's floor 0.8486. Owner: QA/Developer. | QA |

## Product bugs

- none confirmed by this pass.

## Findings (non-product, worth carrying)

| ID | Type | Finding |
| --- | --- | --- |
| F-40-R-01 | Test-plan mismatch | TP-40-MET-01/MET-03 PASS claim covers legacy mode only; plan signals require hybrid. Reclassify or add hybrid run. |
| F-40-R-02 | Coverage tooling gap | TP-40-COV-01 close via OpenCppCoverage + run_coverage.ps1 (repo standard), not GCC rebuild, which is slower and unnecessary. |
| F-40-R-03 | Harness gap | Stream resume covered by merged upstream test_stream.py; add to focused route. Recommend running test_stream.py against built server (commit script path). |
| F-40-C-01 | Environment (verify) | cold_budget=-1 in legacy = this repo's documented "unlimited" sentinel (Stage 17 design: "`-1` represented by documented unlimited value"; default since Stage 39). Not the Stage 39 hybrid 2147483648 finding. Needs hybrid-mode run to confirm positive value stays 2147483648. |

## Retest scope

1. PRS-01/MET-01/MET-03: run one hybrid-mode server (Qwen3-0.6B, --metrics --cache-mode hybrid --cache-cold-max-mib 2048); scrape and assert `cache_cold_budget_bytes{mode="hybrid"} 2147483648` (Stage 38 D36-FU-01) and `cache_hits_total{mode="hybrid"}` present.
2. TP-40-RT-02: run `tools/server/tests/unit/test_stream.py` against built server (merged upstream fixture exists; invoke the 3 resume tests). If server-stream resume requires interactivity not reproducible, keep SKIP but cite the harness path and exact limitation.
3. TP-40-COV-01: Option A: add `/Zi /DEBUG:FULL` to build-cov CMAKE_CXX_FLAGS_RELEASE + linker (D18-IMPL-01 precedent), rerun `run_coverage.ps1` focused on test-cache-controller. Option B: GCC CPU-only build and reassess. Whichever closes coverage floor 0.8486 (TP-39-03).
4. Confirm F-40-C-01 is legacy default sentinel and hybrid mode matches 2147483648.

## Handoff

- Next gate: Manager test-execution gate.
- Status: REWORK. No product bugs; 1 coverage tooling gap, 1 stream-resume harness gap, 2 metric rows run in wrong mode (legacy not hybrid). All closable by QA within existing budget except CP-02 (fixture absent, stays N/A).
- Handoff owner: QA (retest hybrid metrics, stream harness, coverage close). Developer/Architect for build-cov reconfig if QA lacks the D18-IMPL-01 flag precedent.
- Evidence to retain: full test-cache-controller log (copilot-terminal-output-67126045-875b-4ac1-8058-82f27dd00352.txt), this review.
