# Test plan part 42: Stage 38 prefix restore and cold-budget gauge

Status: Manager test-plan gate PASS; ready for QA execution
Date: 2026-07-11
Stage: 38
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope

Stage 38 validates two fixes:

- approved chat strict-prefix partial restore for `/v1/chat/completions` and
  the shared hybrid cache-controller path;
- the D36-FU-01 cold-budget gauge fix so `--cache-cold-max-mib 2048` reports
  `2147483648` bytes.

Out of scope: `/completion` strict-prefix restore stays rejected. Any
`/completion` strict-prefix candidate must recompute with a bounded
unsafe/fallback reason. Public prompt-token totals stay at full request prompt
length. Only cache-specific fields report restored prefix length.

## Clean-build rule

Every Stage 38 execution session must start from a clean Release build. Do not
reuse stale or incrementally rebuilt binaries as evidence.

```powershell
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server test-cache-controller -j 4
```

Use plain ASCII status labels in all reports: `PASS`, `FAIL`, `SKIP`,
`BLOCKED`. Do not use unicode status icons.

## Evidence tiers

| Tier | Source | Rows it proves |
| --- | --- | --- |
| Focused controller | `tests/test-cache-controller.exe` | checksum, namespace, pair-state, checkpoint-safety, cold payload, protected branch, generated-output, cold-budget boundary math |
| Live model-backed | `/v1/chat/completions` suffix run plus `/apply-template` and `/tokenize` proof | public `cached_tokens`, `timings.cache_n`, full `prompt_tokens`, prefix metrics, hybrid hit delta |
| Public Prometheus | `/metrics` | cold-budget gauge value `2147483648` |

## Model-backed evidence requirements

At least one `/v1/chat/completions` row must prove the public cached-token path:

- send a chat message, replay the actual assistant output from that first
  response, then append a new user turn so the second request is a strict
  rendered-token prefix continuation, not an exact repeat or synthetic replay;
- use a stable chat template when needed so model-specific reasoning or
  thinking history rewrites do not invalidate the prefix proof;
- prove the first rendered request tokens and the first-turn assistant replay
  tokens are both strict prefixes of the second rendered request tokens before
  accepting cache-field evidence;
- second response must report nonzero
  `usage.prompt_tokens_details.cached_tokens`;
- second response must report `timings.cache_n` equal to
  `usage.prompt_tokens_details.cached_tokens`;
- second response must report `usage.prompt_tokens` equal to the rendered full
  request token count proven by `/apply-template` plus `/tokenize`, and that
  value must be greater than the restored prefix length;
- `llamacpp:cache_hits_total{mode="hybrid"}` must show a positive delta after
  the suffix turn;
- `/metrics` must show at least one accepted prefix row
  (`cache_prefix_candidates_total{result="accepted",reason="accepted_strict_prefix"}`)
  or a bounded miss row.

A separate backup row must prove public Prometheus `2147483648` cold-budget
gauge: start hybrid server with `--cache-cold-max-mib 2048`, fetch `/metrics`,
and locate a `llamacpp:cache_cold_budget_bytes{mode="hybrid"} 2147483648` line.

## TP-38 rows

| Row | Scenario | Positive case | Negative case | Observability check | Expected outcome |
| --- | --- | --- | --- | --- | --- |
| TP-38-PR-01 | Exact repeat wins | Exact repeat request restores exact entry | Prefix logic must not claim an accepted reason for an exact repeat | `accepted_strict_prefix` counter absent after exact restore | Exact restore path wins; no prefix-accepted counter increments |
| TP-38-PR-02 | Safe strict prefix plus new turn | Duplicate-plus-suffix chat request restores prefix | Non-chat `/completion` candidate recomputes | Suffix turn reports nested cached_tokens > 0; `timings.cache_n` equals cached_tokens; `prompt_tokens` equals rendered full request length | Extracted prefix restores; suffixes processed; cache-specific fields equal prefix length |
| TP-38-PR-03 | Prefix token checksum mismatch | Matching checksum on shared prefix | Tampered token checksum past boundary | `cache_restore_misses_total{reason="checksum_mismatch"}` increments | Candidate rejected; full recompute; bounded reason recorded |
| TP-38-PR-04 | Namespace, template, or tool drift | Same template/tools restore | Drifted template or tool config | Zero restore hits for drifted request | Candidate rejected before payload apply |
| TP-38-PR-05 | Pair-state mismatch | Matching target/draft pair-state restores | Target-only request against target/draft entry | `cache_restore_misses_total{reason="pair_state_mismatch"}` | No target-only or draft-only partial restore applies |
| TP-38-PR-06 | Checkpoint or MTP path | Checkpoint-safe prefix restores for checkpoint-dependent runtime | Arbitrary LCP rejected for checkpoint-dependent or target-plus-draft runtime | `prefix_not_checkpoint_safe` or `unsafe_prefix_rejected` reason | Target-plus-draft and checkpoint-dependent paths restore only from checkpoint-safe points |
| TP-38-PR-07 | Cold prefix payload | Cold entry promotes inline to hot | Cold promotion fails with bounded fallback | Demotion or promotion counters, cold restore latency | Cold promotion succeeds before apply, or safe fallback with bounded reason |
| TP-38-PR-08 | Protected branch under pressure | Protected prefix metadata survives churn | Unprotected entries evict first | Protected-root decision counter; entry still matches strict-prefix request | Protected prefix metadata survives while budgets hold |
| TP-38-PR-09 | No generated-output replay | Real prompt prefix restores | Generated-output-only entry must not match fresh prompt | No hit row for generated-output-only entry | Prior assistant output is never emitted unless current generation produced it |
| TP-38-PR-10 | `/completion` strict-prefix candidate | `/completion` request recomputes normally | `/completion` strict-prefix candidate rejected before apply | `unsafe_prefix_rejected` or bounded fallback reason | Prefix restore not attempted; request recomputes |
| TP-38-MET-01 | Cold budget 2048 MiB | Gauge reports `2147483648` | Gauge must never be negative or narrowed through `int` | Public Prometheus `llamacpp:cache_cold_budget_bytes{mode="hybrid"}` | Value equals `2147483648` |
| TP-38-MET-02 | Cold budget boundary values | `0`, `1`, `2047`, `2048`, `4096` preserve meaning | `-1` means unlimited | Internal stats value matches configured bytes for each boundary | Each boundary preserves its documented meaning |

## Focused controller evidence

The Stage 38 focused tests live in `tests/test-cache-controller.cpp` and hold in
Release builds (they use `require_or_abort`, not `assert`).

| TP-38 row | Focused controller test |
| --- | --- |
| TP-38-PR-01 | `test_stage38_exact_repeat_wins_over_prefix` |
| TP-38-PR-02 (unit half) | `test_stage38_chat_strict_prefix_restore_plan` |
| TP-38-PR-03 | `test_stage38_prefix_boundary_checksum_rejects` |
| TP-38-PR-04 | `test_stage38_namespace_template_tool_drift_rejects` |
| TP-38-PR-05 | `test_stage38_pair_state_mismatch_rejects_prefix` |
| TP-38-PR-06 | `test_stage38_target_draft_prefix_requires_checkpoint_safe` |
| TP-38-PR-07 | `test_stage38_cold_prefix_payload_promotes_or_falls_back` |
| TP-38-PR-08 | `test_stage38_protected_prefix_metadata_survives_pressure` |
| TP-38-PR-09 | `test_stage38_generated_output_never_replayed` |
| TP-38-PR-10 | `test_stage38_completion_strict_prefix_recomputes` |
| TP-38-MET-01 | `test_stage38_cold_budget_prometheus_gauge_output` |
| TP-38-MET-02 | `test_stage38_cold_budget_metric_boundary_math` |

Focused commands:

```powershell
cmake --build build --config Release --target test-cache-controller
.\build\bin\Release\test-cache-controller.exe
ctest --test-dir build -C Release -R cache --output-on-failure
```

If the default build directory is missing at execution time, record the chosen
build tree and why the default was unavailable.

## Live model-backed evidence

Run after a clean build with a hybrid server. The reusable driver
`compare-legacy-vs-hybrid.ps1 -BurstDuplicateMode` covers the broad chat reuse
flow. Stage 38 adds checks the burst driver does not assert on its own: a
suffix turn (not an exact duplicate) showing partial cached tokens,
`timings.cache_n` equal to `usage.prompt_tokens_details.cached_tokens`,
`usage.prompt_tokens` equal to the rendered full request token count from
`/apply-template` plus `/tokenize`, and the public Prometheus `2147483648`
cold-budget gauge line.

Stand-alone Stage 38 verification:

```powershell
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\stage38-prefix-restore-and-cold-budget.ps1 `
    -ModelPath <GGUF path> `
    -LlamaServerPath build\bin\Release\llama-server.exe `
    -RunRoot ._test_output\stage38-prefix-restore-YYYYMMDD-NN `
    -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN-stage38.md `
    -ColdBudgetMiB 2048
```

## Classification

| Outcome | Condition |
| --- | --- |
| PASS | Every focused controller test passes, and at least one model-backed row proves nested cached_tokens > 0, `timings.cache_n` equals cached_tokens, public `prompt_tokens` equals the rendered full request token count and is greater than cached_tokens, positive hybrid hit delta, prefix metrics, and the public `2147483648` gauge |
| PARTIAL | Focused tests pass but model-backed row is blocked by verified missing fixture or host tooling |
| FAIL | Any focused test fails (Release), or model-backed row returns false zero cached_tokens for a suffix turn, or gauge reports a narrowed or wrong value |
| BLOCKED | Stale binary, occupied port, missing fixture, or unsafe cleanup |

## Handoff

Next gate: test-plan review (Architect). Product-code edits remain out of
scope unless an execution report fails and Manager opens a correction loop.
