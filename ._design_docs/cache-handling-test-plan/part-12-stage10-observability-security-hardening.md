# Cache handling test plan - Part 12: Stage 10 observability, security, and hardening

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Stage 10 scope

Stage 10 closes the hybrid-cache production-readiness plan after the
implementation re-review PASS. The QA plan covers observability shape and
escaping, bounded diagnostics, cold-store root and path hardening, startup
validation, pressure and abuse handling, deterministic stress, coverage and
benchmark evidence, operator documentation, security evidence, and regression
coverage from Stages 4 through 9.

QA execution is still closed. Do not create a test report or record run-specific
results in this plan.

Design documents:

- [Stage 10 design](../cache-handling-phase10-design.md)
- [Part 2: observability, security, and hardening](../cache-handling-phase10-design/part-02-observability-security-and-hardening.md)
- [Part 3: validation, traceability, and readiness](../cache-handling-phase10-design/part-03-validation-traceability-and-readiness.md)

Implementation documents:

- [Stage 10 implementation](../cache-handling-phase10-implementation.md)
- [Part 6: implementation evidence](../cache-handling-phase10-implementation/part-06-implementation-evidence-20260602.md)
- [Part 7: implementation evidence final pass](../cache-handling-phase10-implementation/part-07-implementation-evidence-20260602-final.md)
- [Part 8: Architect implementation review](../cache-handling-phase10-implementation/part-08-architect-implementation-review-gate.md)
- [Part 9: S10-IMPL-01 correction evidence](../cache-handling-phase10-implementation/part-09-s10-impl-01-correction-evidence.md)
- [Part 10: Architect implementation re-review](../cache-handling-phase10-implementation/part-10-architect-implementation-re-review-gate.md)

## Evidence sources

Use the narrowest source that can create the precondition.

| Source | Covers | Limits |
| --- | --- | --- |
| `test-step10-metrics` | Stage 10 metric rows, public exporter shape, bounded labels, quote and newline escaping | Focused exporter evidence; use live `/metrics` for operator-visible claims |
| `test-stage10-cold-store-hardening` | cold-store root normalization, containment, diagnostics, startup budget validation, pressure cases, queue pressure, shutdown with pending work, repeated integrity failures | Focused C++ evidence; does not prove model-backed HTTP behavior |
| `test-cache-controller` | descriptor validation, restore rollback, protected-root pressure, unsupported runtime shapes, Stage 4-5 regression | Map only rows with matching focused assertions |
| `test-step6-demotion-protocol`, `test-step7-promotion-protocol`, and `test-step11-test-hooks-fault-injection` | demotion, promotion, queue pressure, corruption, paired target/draft failure paths | Focused protocol and fault-injection evidence |
| `test-step12-branch-graph` and `test-step13-stage8` | branch metadata pressure, large forests, mismatch handling, re-materialization, deduplication, pruning, cleanup ownership | Focused graph and Stage 8 evidence |
| `tools/server/tests/unit/test_cache_modes.py` | startup validation, legacy-disabled behavior, public metrics shape, public marker behavior if enabled | Use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` only for startup and metric-shape rows |
| PowerShell integration runner | clean report creation, server startup, public HTTP requests, logs, and `/metrics` snapshots | No dedicated Stage 10 matrix yet |
| Benchmark runner and coverage tools | benchmark evidence and 80% hybrid-path coverage evidence | Required setup and evidence, not accepted skips when tools are missing |

## Positive coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| T100 | Public Stage 10 metric shape | `/metrics` exposes exact-blob restore, payload transition, payload eviction, protected-root decision, fallback restore, and structured diagnostic rows with the documented bounded labels. |
| T101 | Prometheus label escaping | Label values escape backslash, quote, newline, and carriage return, and metric output remains parseable. |
| T102 | Bounded structured diagnostics | Diagnostic rows use enum-like event, result, reason, strategy, operation, profile, pair state, payload kind, and residency fields. They do not include prompt text, marker text, local file paths, model paths, checksums, payload bytes, or serialized state. |
| T103 | Cold-store root hardening | Startup keeps a canonical absolute root, rejects unsafe roots, allows safe literal `..` directory names, checks derived payload and staging paths against the root, and sanitizes path diagnostics. |
| T104 | Cold file integrity fallback | Invalid cold files fail validation, invalidate only the affected descriptor path, and fall back without live-state mutation or partial paired restore. |
| T105 | Startup validation | Hybrid startup rejects impossible budgets and unsafe cold-store combinations before serving requests. Safe hybrid and legacy configurations still start. |
| T106 | Pressure handling | Tiny hot budgets, protected-root pressure, branch metadata pressure, queue pressure, and large branch forests prefer recompute, rejection, or bounded fallback over unsafe reuse. |
| T107 | Deterministic stress | Stress rows use deterministic clocks, fake stores, deterministic worker completion order, fixed tie-breaking, and fixed seeds when ordering matters. |
| T108 | Operator documentation | Durable docs describe hybrid flags, budget tuning, cold-store setup, workload profiles, restore behavior, metrics, diagnostics, benchmark evidence classes, security limits, and explicit exclusions. |

## Negative and security coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| T109 | Metric and diagnostic leakage | Stage 10 metric labels and diagnostics reject or omit unbounded external strings, prompt material, marker material, paths, checksums, payload bytes, and serialized cache content. |
| T110 | Request marker surface | No marker-surface abuse row is required while the repo exposes no hybrid cache request-marker surface. If a marker surface is later enabled, repeated invalid markers must produce bounded diagnostics and no protected-state influence. |
| T111 | Descriptor and restore hardening | Owner, kind, version, size, checksum, residency, namespace, profile, pair state, speculative identity, and boundary mismatches reject before live mutation or use Stage 5 transactional rollback. |
| T112 | Unsupported runtime shape | Unsupported multimodal, draft, workload profile, or cache configuration combinations fall back or fail startup with bounded diagnostics. |
| T113 | Security evidence | The Stage 10 report records focused OWASP A01, A03, A04, A05, A08, and A09 classifications as mitigated, accepted with rationale, or not applicable. Any unmitigated correctness, confidentiality, or operator-control issue is a blocking failure. |

## Coverage and benchmark requirements

Coverage and benchmark setup blockers must be carried as required setup and
evidence requirements. Do not record missing LLVM, GCOV, k6, Python packages, or
model fixtures as accepted skips in the plan.

| ID | Scenario | Expected result |
| --- | --- | --- |
| T114 | Hybrid path coverage | A coverage run proves at least 80% coverage for the reviewed hybrid-mode denominator, including observability emission, cold-store hardening, descriptor validation, hot/cold transitions, branch and Stage 8 paths, checkpoint paths, and target/draft pairing. |
| T114a | Product-only hybrid path coverage (Stage 11 onward) | A coverage run proves at least 70% coverage for the 11 product files in the hybrid-mode denominator. Test files in the denominator are excluded from the T114a verdict. |
| T115 | Coverage denominator and exclusions | The report lists tool, commands, included files, excluded files, percentage, branch totals when available, fallback reason if line coverage is used, and uncovered hybrid paths above risk threshold. |
| T116 | Benchmark evidence | Exact-hit, checkpoint-hit, cold-transition, and end-to-end savings benchmarks classify every measurement as public Prometheus, structured log, direct stats, or harness-only evidence before execution. |
| T117 | Benchmark correctness gate | Benchmark rows prove correctness before performance claims. Any accepted regression needs a written reason and manager decision. |

The Stage 10 closure record at
[test-report-20260603-05.md](../../.test_reports/test-report-20260603-05.md)
cites the T114 row only. From Stage 11 onward, the hybrid path coverage
contract is split into T114 (combined rate, 80% on the 19-file
denominator) and T114a (product-only rate, 70% on the 11 product files).
Both rows are closure contracts. The split rules, product-only
denominator list, floor threshold, and required `run_coverage.ps1`
change are recorded in
[Part 13: T114 split](./part-13-t114-product-only-coverage.md).

## Stage 4-9 regression after Stage 10

| ID | Scenario | Expected result |
| --- | --- | --- |
| T118 | Stage 4-5 regression | Byte-budget LRU, protected-root policy, descriptor validation, target/draft pair enforcement, transactional restore, draft namespace isolation, and Stage 4-5 metrics still pass with Stage 10 observability and hardening present. |
| T119 | Stage 6 regression | Cold demotion, promotion, async miss, corruption handling, queue fallback, root validation, and cold metrics remain valid with the hardened cold-store paths. |
| T120 | Stage 7-8 regression | Branch graph lookup, namespace validation, slot refs, metadata-only retention, re-materialization, mismatch handling, equivalent deduplication, pruning, cleanup ownership, and public metric labels remain valid. |
| T121 | Stage 9 regression | Workload profile namespace, checkpoint descriptor validation, checkpoint-first and exact-first ranking, target/draft checkpoint pairing, cold checkpoint promotion, public checkpoint metrics, and fixture-dependent public rows remain valid. |

## Clean build, coverage, and execution rules

Stage 10 execution starts from a clean build. At minimum, build:

```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server test-cache-controller test-step10-metrics test-stage10-cold-store-hardening test-step6-demotion-protocol test-step7-promotion-protocol test-step11-test-hooks-fault-injection test-step12-branch-graph test-step13-stage8 -j 4

$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

Focused checks for Stage 10 planning and execution:

```powershell
ctest --test-dir build -C Release -R "test-(cache-controller|step10-metrics|stage10-cold-store-hardening|step6-demotion-protocol|step7-promotion-protocol|step11-test-hooks-fault-injection|step12-branch-graph|step13-stage8)" --output-on-failure
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path
pytest tools/server/tests/unit/test_cache_modes.py
```

Use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` only for startup, public surface,
and metric-shape rows. Do not use it as evidence for model-backed save, restore,
hit, miss, promotion, demotion, eviction, boundary propagation, or checkpoint
behavior.

Store run evidence only in a fresh
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` file after QA
execution opens.

## Evidence checklist

Every Stage 10 report should state:

- clean build commands, targets, binary timestamp, and dirty worktree state
- evidence source for each row: public HTTP, focused C++ test, Python startup or metric test, model-backed fixture, benchmark runner, coverage report, or substitute evidence
- exact focused test names or source locations for rows that use focused evidence
- public `/metrics` scrape for operator-facing metric rows when a live server can create the row
- metric label names and values for exact restore, payload transition, payload eviction, protected-root decision, fallback, checkpoint, and diagnostic rows
- cold-store root setup without leaking local paths in public summaries
- startup validation commands and rejected configuration reason
- pressure and stress inputs, deterministic seams, fixed seeds, and worker ordering controls
- OWASP classification table and any blocking unmitigated item
- coverage tool, command family, included and excluded files, percentage, fallback reason, and uncovered high-risk hybrid paths
- benchmark scenario, fixture identity without local path leakage, flags, budgets, warmup window, measurement window, evidence source, and correctness proof
- operator documentation files checked against implemented flags, metrics, diagnostics, and exclusions
- Stage 4-9 regression rows and the exact evidence used for each
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts

Do not report run-specific results in this plan.
