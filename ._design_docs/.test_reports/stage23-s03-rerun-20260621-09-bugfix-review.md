# Stage 23 S03 rerun 20260621-09 bugfix review

Status: PASS
Date: 2026-06-21
Owner: Architect
Scope: F-23-S03-RERUN09-01 bug-fix review only. No product, test, runner, or
fixture fixes were implemented by Architect.

## Verdict

PASS. The metadata snapshot fix in `attach_checkpoint_payload` is a narrow and
reasonable correction for the symbolized access violation at the checkpoint
boundary metadata read. The new focused regression covers the demotion-budget
fallback plus stale completion shape that preceded the crash.

Stage 23 remains stopped at S03. QA may run one focused CUDA S03 rerun with the
same shape as report 09 and a fresh output suffix. S04..S08 and L01..L03 remain
stopped until S03 passes or Manager records a new decision.

## Reviewed files

| File | Reason |
| --- | --- |
| `._design_docs/document-index.md` | Current Stage 23 gate and report chain. |
| `._design_docs/cache-handling-phase23-design.md` | Stage 23 S/L matrix contract and stop rules. |
| `._design_docs/cache-handling-phase23-implementation.md` | Current S03 gate and handoff state. |
| `._design_docs/.test_reports/stage23-s03-rerun-20260621-09.md` | QA product-crash report. |
| `._design_docs/.test_reports/stage23-s03-rerun-20260621-09-developer-review.md` | Developer crash classification and fix scope. |
| `._design_docs/.test_reports/stage23-s03-rerun-20260621-09-fixes.md` | Developer fix report and evidence claims. |
| `tools/server/server-cache-hybrid.cpp` | Metadata snapshot fix and checkpoint attach flow. |
| `tools/server/server-cache-hybrid.h` | Private helper signature check. |
| `tests/test-cache-controller.cpp` | New regression body and registration. |

## Findings

| ID | Severity | Finding | Decision |
| --- | --- | --- | --- |
| F-23-S03-RERUN09-01-A | None | Symbolized crash claim is coherent. The reported RVA maps to `hybrid_cache_controller::attach_checkpoint_payload` at the loop reading `source_metadata->boundaries`. | Accepted. The fix targets the read site directly. |
| F-23-S03-RERUN09-01-B | None | `metadata_snapshot` is taken before `attach_payload` mutates entry payload ownership. Boundary selection and descriptor validation then use the stable local snapshot. | Accepted. This avoids reading through an aliased metadata pointer during checkpoint attach. |
| F-23-S03-RERUN09-01-C | None | The fix does not change public flags, public schemas, metric names, restore ranking, or cache policy surfaces. `attach_checkpoint_payload` remains a private helper. | Accepted. Scope stays inside local checkpoint metadata lifetime. |
| F-23-S03-RERUN09-01-D | None | The new regression forces one payload into demoting state, forces a second through demotion-budget rejection and immediate eviction, drains the stale completion, then attaches a checkpoint on the evicted-owner entry. | Accepted. This covers the pressure and stale-completion shape tied to the crash. |
| F-23-S03-RERUN09-01-E | Advisory | The branch still contains large pre-existing Stage 21/22/23 changes in nearby cache ownership, demotion, promotion, and restore paths. | Not blocking for this review. QA S03 rerun remains required to catch any second pressure bug. |

## Evidence checked

Local commands:

```text
git diff --check -- tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h tests/test-cache-controller.cpp ._design_docs/cache-handling-phase23-implementation.md ._design_docs/document-index.md
cmake --build build-cov --config Release --target test-cache-controller -j 4
.\build-cov\bin\Release\test-cache-controller.exe
cmake --build build-cov --config Release --target llama-server -j 4
```

Results:

| Check | Result |
| --- | --- |
| Scoped `git diff --check` | PASS, no output. |
| `test-cache-controller` build | PASS. |
| `test-cache-controller.exe` | PASS, 120/120 tests. |
| New regression line | PASS: `Stage 23 demotion budget fallback stale completion checkpoint attach... PASSED`. |
| `llama-server` build | PASS. |

Report claims checked against local source:

| Claim | Review result |
| --- | --- |
| Test total updated to 120 and Stage 23 focused count to 8 | Confirmed in `tests/test-cache-controller.cpp`. |
| New regression registered | Confirmed in `main()`. |
| Metadata snapshot used for boundary selection and validation | Confirmed in `attach_checkpoint_payload`. |
| No public metric or flag change | Confirmed for this narrow fix. |

## Risk notes

- The root cause is likely enough for bug-fix approval, but not final S03
  closure. The crash came from the CUDA S03 workload under pressure; focused
  CUDA rerun is still required.
- The branch has accumulated Stage 21/22/23 changes. This review accepts only
  the metadata-snapshot fix and the new regression. It does not reapprove older
  demotion, promotion, or runner changes beyond nearby regression risk.
- If QA rerun still crashes or loses required S03 evidence, stop again and open
  a new bug-fix loop instead of resuming the matrix.

## Handoff

Next owner: QA.

QA should run one focused CUDA S03 rerun with the same shape as
`stage23-s03-rerun-20260621-09.md`: Qwen3.5-4B-MTP, `--cache-mode hybrid`,
`--cache-ram 512`, `--cache-cold-max-mib 512`, redacted prompt evidence,
`--n-gpu-layers all`, `--fit off`, fresh cold path, fresh output root, and a
fresh report/output suffix.

Required outcome: no crash, `metrics-after.txt`, redacted prompt evidence,
bounded cold-budget behavior or explicit diagnosis, and S03 row behavior
evidence. S04..S08 and L01..L03 remain stopped.
