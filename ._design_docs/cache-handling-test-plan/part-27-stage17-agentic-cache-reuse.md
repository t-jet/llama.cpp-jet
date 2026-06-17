# Test plan part 27: Stage 17 agentic cache reuse, cold budget, and checkpoint policy

Status: authored; pending QA test-plan review
Date: 2026-06-17
Stage: 17 (Agentic Cache Reuse, Cold Budget, and Checkpoint Policy)
Branch: work-branch
Owner: QA (test plan authoring, fresh session)
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: Stage 17 test plan only. Not re-review of design, plan, implementation, or any other stage.

## References

Design:

- [Stage 17 design](../../cache-handling-phase17-design.md)
- [Part 1: restore diagnostics and prompt evidence](../../cache-handling-phase17-design/part-01-restore-diagnostics-and-prompt-evidence.md)
- [Part 2: agentic reuse and checkpoint policy](../../cache-handling-phase17-design/part-02-agentic-reuse-and-checkpoint-policy.md)
- [Part 3: cold storage budget and eviction](../../cache-handling-phase17-design/part-03-cold-storage-budget-and-eviction.md)
- [Part 4: observability, QA, acceptance, and traceability](../../cache-handling-phase17-design/part-04-observability-qa-acceptance-traceability.md)
- [Part 6: Manager design gate](../../cache-handling-phase17-design/part-06-manager-design-gate.md) (D17-01..D17-03)

Implementation:

- [Stage 17 implementation](../../cache-handling-phase17-implementation.md)
- [Part 1: implementation plan](../../cache-handling-phase17-implementation/part-01-implementation-plan.md)
- [Part 4: implementation evidence](../../cache-handling-phase17-implementation/part-04-implementation-evidence.md)
- [Part 5: architect implementation review gate 01](../../cache-handling-phase17-implementation/part-05-architect-implementation-review-gate-01.md) (PASS, 0 BLOCKING)

Prior test plan parts:

- [Part 12: Stage 10 observability, security, and hardening](./part-12-stage10-observability-security-hardening.md) (observability/metric example)
- [Part 25: Stage 15 full test suite validation](./part-25-stage15-full-test-suite-validation.md) (full-suite example)
- [Part 26: Stage 16 chat-path prompt-span boundary](./part-26-stage16-chat-path-prompt-boundary.md) (most recent per-stage plan)

## Manager decisions (binding)

- D17-01: use `--cache-cold-max-mib` as the cold payload budget option. Reject values < -1.
- D17-02: prompt evidence records are JSONL, one record per restore lookup. Raw mode may reference raw prompt file by relative file name only.
- D17-03: prefix restore is NOT implemented. Test plan must NOT add prefix restore assertions except `unsafe_prefix_rejected`.
- D17-IP-01: use `--cache-prompt-evidence MODE`. Valid modes: `off`, `redacted`, `raw`. Default `off`.
- D17-IP-02: use `--cache-prompt-evidence-dir PATH` for JSONL evidence output.
- D17-IP-03: raw mode may reference raw prompt files only when `--log-prompts-dir PATH` is also explicitly configured.

## Scope and exclusions

In scope for Stage 17 test plan:

- bounded restore-miss reason enum and one-primary-reason accounting
- JSONL prompt identity evidence in `off`, `redacted`, and `raw` modes
- prefix-candidate detection with `unsafe_prefix_rejected` classification only (no restore)
- `--cache-cold-max-mib` budget with `0`, positive, `-1`, and invalid-negative semantics
- skip-before-write cold pressure, cold eviction, and target/draft atomicity
- checkpoint-density admission policy with `compat_required` and `semantic` labels
- bounded metric label allowlist (no prompt text, no raw paths, no raw namespaces, no raw descriptor ids)
- synthetic, stress-longrun, and heavy manual/nightly QA hooks

Out of scope (deferred or excluded):

- Cold startup ownership reconciliation (deferred per implementation part 4)
- Orphan staging cleanup extension (deferred per implementation part 4)
- Semantic-boundary dense-checkpoint filter (deferred per implementation part 4)
- Raw prompt file reference emission in evidence (deferred per design part 4; raw mode is gated by `--log-prompts-dir`)
- Prefix restore implementation (deferred per D17-03)
- Live `/metrics` scrape in this implementation session (deferred; will be captured in test execution)
- Stage 4-9 regression rows (covered by prior stage test plan parts)
- Stage 12/15 S01..S08 and L01..L03 full re-run (re-uses S/L framework hooks; full re-run deferred)
- Stage 15 B01..B08 benchmark rows (re-uses bench framework; full re-run deferred)

## Test plan rows

### Unit tests (in tests/test-cache-controller.cpp)

Fixture: `none` for all unit rows. Preconditions: build the focused
test binary, run `build\bin\Release\test-cache-controller.exe`. Each
row asserts one focused contract. Command form is illustrative;
executor records the actual command in the test report.

| ID | Type | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-17-UT1 | unit | none | construct `common_params` with defaults; read `cache_cold_max_mib` | value is `-1` | ctest log line | default cold budget `-1` means unlimited |
| TP-17-UT2 | unit | none | read default `cache_prompt_evidence` mode | value is `"off"` | ctest log line | default evidence mode `off` |
| TP-17-UT3 | unit | none | set `cache_cold_max_mib = 0`; verify controller | cold writes disabled; hot eviction still works | ctest log line | `0` disables cold writes |
| TP-17-UT4 | unit | none | set `cache_cold_max_mib = 100`; verify controller | budget accepted, mode logged as `100 MiB` | ctest log line | positive cold budget accepted |
| TP-17-UT5 | unit | none | set `cache_cold_max_mib = -1`; verify controller | unlimited mode accepted | ctest log line | `-1` unlimited accepted |
| TP-17-UT6 | unit | none | call arg parser with `--cache-cold-max-mib -2` | `std::invalid_argument` thrown | ctest log + exception type | negative values < -1 rejected |
| TP-17-UT7 | unit | none | set `cache_prompt_evidence` to `off`, `redacted`, `raw` | all three accepted by parser | ctest log line | three valid evidence modes |
| TP-17-UT8 | unit | none | call arg parser with `--cache-prompt-evidence garbage` | parser rejects with bounded error | ctest log + error text | unknown mode rejected |
| TP-17-UT9 | unit | none | write a redacted evidence record; assert no prompt text, no raw paths, no `raw_prompt_file` key | redacted JSONL contains only bounded fields | redacted JSONL sample line | redacted mode emits no prompt content |
| TP-17-UT10 | unit | none | set `cache_prompt_evidence = raw` without `--log-prompts-dir`; verify startup validation | raw mode rejected at startup | ctest log + error text | raw mode requires `--log-prompts-dir` |
| TP-17-UT11 | unit | none | call `classify_restore_miss` for each narrower internal cause | result maps to bounded reason set | ctest log + reason value | narrower causes map to bounded enum |
| TP-17-UT12 | unit | none | build a strict-prefix candidate under same namespace; call `find_prefix_candidate` | returns `unsafe_prefix_rejected` with bounded reject reason | ctest log line | prefix candidates classified unsafe |
| TP-17-UT13 | unit | none | same setup as UT12; verify no slot mutation, no live state change after restore attempt | slot state unchanged; no recency refresh; no usage bump | ctest log + slot state diff | prefix restore not applied |
| TP-17-UT14 | unit | none | fill cold budget; trigger demotion; assert `cold_demotions_skipped_total` increments | counter increments by 1, no filesystem write attempted | ctest log + counter value | skip-before-write records `cold_demotion_skipped` |
| TP-17-UT15 | unit | none | set cold budget that admits target side but not target+draft; trigger demotion | both sides skipped; counter increments by 1; no partial cold residency | ctest log + descriptor state | target/draft atomicity enforced |
| TP-17-UT16 | unit | none | run a checkpoint admission; inspect emitted `cache_checkpoint_admissions_by_shape` row | row includes `policy`, `result`, `reason` labels | metric row sample | admission labels include the bounded triplet |
| TP-17-UT17 | unit | MTP-style profile (or stub) | run checkpoint admission for checkpoint-dependent or target+draft profile | `policy = compat_required` | metric row sample | compatibility-required paths labelled |
| TP-17-UT18 | unit | none | emit a metric with a free-form marker label attempt | label rejected or stripped; metric row uses bounded labels only | ctest log + metric row | metric label allowlist enforced |

### Integration tests (against llama-server binary, hybrid mode)

Fixture: model-backed MTP fixture for the rows that need it;
`LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` allowed only for startup
and metric-shape rows. Preconditions: clean build of
`llama-server.exe` and `test-cache-controller.exe`; cold path
directory prepared where required; prompt evidence directory prepared
where required.

| ID | Type | Fixture | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-17-IT1 | integration | none | hybrid mode enabled, cold path configured | start server with `--cache-cold-max-mib 100` | startup succeeds; mode logged as `100 MiB` | server.out.log + server.err.log | positive cold budget accepted at startup |
| TP-17-IT2 | integration | none | hybrid mode enabled | start server with `--cache-cold-max-mib -2` | startup fails with bounded error; server exits non-zero | server.err.log + exit code | invalid cold budget rejected at startup |
| TP-17-IT3 | integration | none | hybrid mode, evidence dir configured | start server with `--cache-prompt-evidence redacted --cache-prompt-evidence-dir <path>`; issue one request | JSONL file created at `<path>/cache-prompt-evidence.jsonl` | evidence file mtime + size | redacted mode writes JSONL at startup |
| TP-17-IT4 | integration | MTP | redacted evidence enabled | parse the JSONL record emitted by the warmup request | fields: `preparation_id`, `namespace_hash`, `profile`, `pair_state`, `token_count`, `boundary_count`, `first_user_boundary`, `token_span_checksum`, `lookup_outcome`, `prefix_candidate` | JSONL record + field check | redacted record shape matches design schema |
| TP-17-IT5 | integration | MTP | raw evidence requested, no `--log-prompts-dir` | start server with `--cache-prompt-evidence raw` only | startup fails with bounded error; raw mode not enabled | server.err.log + exit code | raw mode rejected without `--log-prompts-dir` |
| TP-17-IT6 | integration | MTP | redacted evidence enabled, evidence dir read-only | start server; issue one request | request succeeds; bounded counter increments; `prompt_evidence_failure` log line | server.err.log + counter value | evidence write failure does not fail request |
| TP-17-IT7 | integration | MTP | cold budget small (e.g. 50 MiB); cold path configured | start server; send requests that exceed budget | `cache_cold_demotions_skipped_total` increments; no filesystem write failure in server logs | server.err.log + counter | cold pressure triggers skip-before-write |
| TP-17-IT8 | integration | MTP | hybrid mode; Stage 15/16 acceptance workload reused | run the Stage 15 V2 B05 driver body on `/v1/chat/completions`; expect restore on subsequent identical requests | exact-blob restore path works; `cache_n > 0` on subsequent identical requests | per-request response body + metrics | exact restore regression preserved |
| TP-17-IT9 | integration | MTP | cold budget configured; cold path populated | trigger cold pressure; observe cold eviction | `cache_cold_evictions_total` increments; unprotected cold payloads removed first | server.err.log + counter | cold eviction removes unprotected first |
| TP-17-IT10 | integration | MTP | target+pair cold budget that admits one side only | trigger demotion; observe skip | `cache_cold_demotions_skipped_total` increments by 1; no partial cold residency in descriptors | server.err.log + descriptor state | pair skipped when only one side fits |
| TP-17-IT11 | integration | MTP | hybrid mode with all new flags | scrape `/metrics` after one request | metric families present: `cache_restore_misses_total`, `cache_prompt_evidence_records_total`, `cache_prefix_candidates_total`, `cache_cold_bytes`, `cache_cold_budget_bytes`, `cache_cold_evictions_total`, `cache_cold_demotions_skipped_total`, `cache_checkpoint_admissions_by_shape_total` | `/metrics` scrape text | all eight metric families exposed |
| TP-17-IT12 | integration | MTP | same as IT11 | grep the `/metrics` scrape for known forbidden patterns (prompt text, raw paths, raw namespaces, raw descriptor ids) | zero matches; bounded labels only | `/metrics` grep output | labels bounded to reason/profile/pair_state/mode/result/policy/payload_kind/state |

### Synthetic tier (small fixture, generated prompts)

Fixture: generated agentic chat prompts of the named length.
Preconditions: prompt generator; hybrid mode; cold path configured
where cold budget is exercised; MTP fixture for the larger sizes.

| ID | Type | Fixture | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-17-SY1 | synthetic | generated 12k chat prompt | hybrid mode, redacted evidence | save on first request; restore on second identical request | second request returns `cache_n > 0`; redacted JSONL records one hit and one exact-miss-then-hit | per-request response + JSONL | exact repeat restores at 12k |
| TP-17-SY2 | synthetic | generated 24k chat prompt | same as SY1 | same as SY1 | second request returns `cache_n > 0`; JSONL record present | per-request response + JSONL | exact repeat restores at 24k |
| TP-17-SY3 | synthetic | generated 60k chat prompt | same as SY1 | same as SY1 | second request returns `cache_n > 0`; JSONL record present; first-user boundary and boundary count recorded | per-request response + JSONL | exact repeat restores at 60k |
| TP-17-SY4 | synthetic | generated prompts in four classes | same as SY1 | save four prompt classes: exact repeat, near-duplicate, different agent same prefix, same branch continuation | for each class record `cache_n`, miss reason, namespace hash, prefix candidate count; near-duplicate and prefix-only classes must classify miss as bounded reason and `unsafe_prefix_rejected` for prefix candidates | per-request response + JSONL + miss reason | four prompt classes produce bounded outcomes |
| TP-17-SY5 | synthetic | generated 60k prompt | cold budget 50 MiB; cold path | trigger demotion that exceeds budget | bounded eviction OR `cold_demotions_skipped_total` increment; no filesystem write failure in server logs | server.err.log + counter | cold pressure bounded, no write failure |

### Stress-longrun tier (S01..S08 / L01..L03 framework with Stage 17 hooks)

Fixture: existing Stage 12/15 stress and longrun framework with
agentic prompt generator and cold pressure paths. Preconditions:
framework drivers rebuilt with Stage 17 hooks; cold path configured
for stress rows that exercise budget; MTP fixture for MTP-stress rows.

| ID | Type | Fixture | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-17-ST1 | stress | S01..S08 framework | redacted evidence enabled | run S01..S08 drivers with redacted evidence | one JSONL record per restore lookup; bounded miss reasons; no crash; no corrupt restore | per-row JSONL + server logs + counters | stress rows with redacted evidence PASS |
| TP-17-ST2 | stress | L01..L03 framework | cold budget enabled | run L01..L03 drivers with bounded cold budget | cold bytes stay at or below budget; skipped demotions before filesystem write failure; no host-allocation failure | per-row server logs + cold byte gauge + skipped counter | longrun rows respect cold budget |
| TP-17-ST3 | stress | branch-forest growth | prefix-classification enabled | run branch-forest growth driver with mixed exact and near-prefix requests | prefix candidates classified as `unsafe_prefix_rejected`; no slot mutation; counters consistent | server logs + counters | prefix-only candidates rejected, not restored |

### Heavy manual or nightly tier (Qwen3.6-27B-MTP, near-60k prompts, 8 GiB hot cache, bounded cold budget)

Fixture: Qwen3.6-27B-MTP model; near-60k agentic chat prompts; 8
GiB hot cache; bounded cold budget. Preconditions: MTP fixture
available; cold path on a volume with sufficient headroom; a
multi-hour run window. These rows are NOT a normal PR gate.

| ID | Type | Fixture | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-17-HV1 | heavy | Qwen3.6-27B-MTP | cold budget enabled; 8 GiB hot cache; several-hour run | run a long agentic workload with mixed exact, near-prefix, and new-user-turn prompts | record prompt identity drift, restore miss reasons, cold byte growth, cold write failures, host allocation failures; bounded counters, no crash, no corrupt restore | per-hour snapshot of metrics + JSONL tail | heavy MTP run reproduces Stage 16 log class with bounded outcomes |
| TP-17-HV2 | heavy | same as HV1 | Stage 16 model-log baseline available | compare HV1 metrics and JSONL to Stage 16 model-log baseline | document what changes with new diagnostics and budget; no new product bug introduced | comparison table in the heavy run report | Stage 16 baseline comparable; no new product bug |

## Pass/fail criteria

- Unit rows TP-17-UT1..UT18 must all PASS. Any FAIL opens the
  bug-fix loop per part-25 bug-fix loop rules. A missing test case
  is `BLOCKED-pending-test-code` and is not a soft skip; the
  implementation plan requires these tests.
- Integration rows TP-17-IT1..IT12 must all PASS or BLOCKED with
  a documented harness/setup reason. Any FAIL opens the bug-fix
  loop. Rows that depend on a model-backed fixture (IT4, IT5, IT6,
  IT7, IT8, IT9, IT10, IT11, IT12) require a real model load;
  `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` is not allowed for
  these rows per part-12 rule.
- Synthetic rows TP-17-SY1..SY5 must all PASS or BLOCKED with a
  documented harness/setup reason. Any FAIL opens the bug-fix
  loop. Generated prompt lengths are nominal; the executor
  records the actual measured token count.
- Stress-longrun rows TP-17-ST1..ST3 reuse the Stage 12/15
  framework and apply the Stage 15 1000 hits+misses threshold for
  S rows; L rows are classified on intent. A row that cannot run
  in the test-execution session is `BLOCKED-test-session-scope`,
  not `SKIP`.
- Heavy rows TP-17-HV1, TP-17-HV2 are NOT a normal PR gate.
  They are tracked as `PASS-meets-intent` or
  `BLOCKED-test-session-scope` per part-25 stress-tier rules.
- Coverage T114 combined rate `>= 0.80`, T114a product-only rate
  `>= 0.70`, T115 per-file dedup apply as closure contracts from
  Stage 10 and continue at Stage 17. Coverage setup gaps
  (Release without `/Zi`, Start-Process colon-prefix export bug)
  are `BLOCKED-coverage-setup`, not FAIL, per
  `distinguish Release-build coverage gap from Start-Process bug`
  improvement memory. Missing coverage on a Stage 17 code path is
  FAIL, not BLOCKED, per `classify available fixture no-evidence
  runs` improvement memory.
- Clean-build rule applies: full clean build of
  `llama-server.exe` and `test-cache-controller.exe` is mandatory
  before any test session per the part-26 clean-build rule.
  Binary freshness check within 10 minutes of session start.
- Test report and benchmark report use plain ASCII status labels
  (`PASS`, `FAIL`, `SKIP`, `BLOCKED`); no unicode icons.

## Evidence

Each test session creates one durable QA test report at
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` and stores
non-durable artifacts under `._test_output/`. Per-tier capture:

- Unit: ctest log under `._test_output/ctest-YYYYMMDD-NN.log`;
  per-test PASS/FAIL counts and assertion source line numbers in
  the QA test report.
- Integration: per-row `server.out.log`, `server.err.log`,
  `/metrics` before/after text, prompt evidence JSONL sample
  (redacted mode). Evidence paths under
  `._test_output/stage17-int-YYYYMMDD-NN/<row>/`.
- Synthetic: per-row prompt token count measured via `/tokenize`,
  per-request response body with `cache_n` value, JSONL record
  per lookup. Evidence paths under
  `._test_output/stage17-syn-YYYYMMDD-NN/<row>/`.
- Stress-longrun: reuses the Stage 15 per-row evidence format
  from part-25; redacted JSONL tail at
  `._test_output/stage17-st-YYYYMMDD-NN/<row>/server.err.log` plus
  cold-byte and skipped-demotion counters.
- Heavy: per-hour metric snapshot, JSONL tail, and comparison
  table to Stage 16 model-log baseline in the heavy run report.

The QA test report cites the per-row evidence path and the verdict
per row. The Stage 17 implementation review (part 5) is the
authoritative source for which code paths and tests exist; the
executor reconciles any drift with the test report header.

## Risks and open questions

| ID | Risk or question | Owner | Mitigation |
| --- | --- | --- | --- |
| R17-TP-01 | Two deferred items from implementation part 4 (cold startup ownership reconciliation, semantic-boundary dense-checkpoint filter) are explicitly out of scope for Stage 17. Rows that would require those (TP-17-IT3 startup scan, TP-17-SY5 partial filter) are bounded so the test plan does not depend on deferred work. | Manager | Confirmed accepted by implementation review part 5. Test plan does not assert on the deferred paths. |
| R17-TP-02 | Live `/metrics` scrape was not captured in the implementation session (deferred). TP-17-IT11 and IT12 require a live scrape; if the test-execution session cannot produce a live scrape with a model fixture, the rows become `BLOCKED-live-metrics-scrape` with a focused substitute (build-side metric emission check). | Manager | Document the BLOCKED state in the test report; do not soften to PASS. |
| R17-TP-03 | Heavy rows TP-17-HV1, TP-17-HV2 require a multi-hour run window and the Qwen3.6-27B-MTP fixture; both may be unavailable in a single test-execution session. | Manager | Classify as `BLOCKED-test-session-scope` and route to a follow-up session; do not soften to PASS or SKIP. |
| R17-TP-04 | Raw evidence mode requires an explicit `--log-prompts-dir`. If the operator does not configure one, raw mode is rejected (TP-17-IT5). The test plan does not exercise raw mode with an actual raw prompt file; per design part 4 raw prompt file reference emission is deferred. | Manager | Test plan covers raw-mode gating only; raw-mode content emission is a follow-up. |
| R17-TP-05 | TP-17-UT6 and TP-17-IT2 both test the same cold-budget rejection rule at different layers. If the implementation review's N17-IMPL-03 finding (cold budget `0` rejected without hybrid mode) holds, the unit assertion is `0` accepted only with hybrid. The test plan records the rule explicitly to avoid executor drift. | Manager | Executor confirms mode flag at test start; rule is recorded in the test report. |
| R17-TP-06 | Coverage measurement on `build-cov` Release without `/Zi` is a known setup blocker. Stage 17 inherits the Stage 16 F-16-TR-03 handoff. If coverage is BLOCKED, the Stage 17 rows continue on focused evidence. | Developer | Test report records the BLOCKED state with the same handoff citation. |

## Handoff

Status: `authored; pending QA test-plan review`. Next owner is **QA**
in a new fresh session for the test-plan review gate. The reviewer
verifies the 40 rows map to the implementation plan's Tests and
evidence plan section, the Manager decisions D17-01..D17-03 and
D17-IP-01..D17-IP-03 are honored verbatim, the deferred items are
out of scope, and the evidence and report format match the test
plan's quality rules at [part-07](./part-07-test-report-quality-and-templates.md).

If the test-plan review PASSes, the next gate is Manager test-plan
gate, then QA test execution in a fresh session, then Developer
test-results review, then Manager closure. If REWORK, the next
owner is QA in a new fresh session. No source code, design,
implementation, architecture, or other durable docs are modified
by this plan; REWORK is a test-plan concern, not a product concern.

This file uses LF line endings, plain ASCII status labels, and
stays under the 300-line durable-doc cap. The
`document-index.md`, `cache-handling-stage-tracker.md`,
implementation log, design docs, and other durable docs are
unchanged by this session.
