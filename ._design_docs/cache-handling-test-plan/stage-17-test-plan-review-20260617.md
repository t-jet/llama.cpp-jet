# Stage 17 test plan review

Status: PASS
Date: 2026-06-17
Stage: 17 (Agentic Cache Reuse, Cold Budget, and Checkpoint Policy)
Branch: work-branch
Reviewer: QA (test-plan review, fresh session)
Source: [part-27-stage17-agentic-cache-reuse.md](./part-27-stage17-agentic-cache-reuse.md)
Scope: Stage 17 test-plan review only. Not re-review of design, plan,
implementation, or any other stage.

## Inputs reviewed

| Input | Result |
| --- | --- |
| `part-27-stage17-agentic-cache-reuse.md` (test plan) | Reviewed |
| `cache-handling-phase17-design.md` and parts 1-4 | Reviewed |
| `cache-handling-phase17-design/part-06-manager-design-gate.md` (D17-01..D17-03) | Reviewed |
| `cache-handling-phase17-implementation/part-01-implementation-plan.md` | Reviewed |
| `cache-handling-phase17-implementation/part-04-implementation-evidence.md` | Reviewed |
| `cache-handling-phase17-implementation/part-05-architect-implementation-review-gate-01.md` | Reviewed |
| `cache-handling-test-plan.md` (entry doc, format/scope rules) | Reviewed |
| `part-25-stage15-full-test-suite-validation.md` (full-suite example) | Reviewed |
| `part-26-stage16-chat-path-prompt-boundary.md` (prior per-stage plan) | Reviewed |
| `part-12-stage10-observability-security-hardening.md` (preload rule) | Reviewed |
| `part-07-test-report-quality-and-templates.md` (quality rules) | Reviewed |

## Verification checklist

| # | Area | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Scope alignment (Stage 17 implementation items have rows; deferred items out of scope; non-Stage 17 work excluded) | PASS | All 9 in-scope items covered by rows (UT1..UT18, IT1..IT12, SY1..SY5, ST1..ST3, HV1..HV2). Deferred items listed in "Out of scope" lines 60-68. Stage 4-9 regression, S/L full re-run, B01..B08 full re-run all explicitly excluded. |
| 2 | Manager decision coverage (D17-01..D17-03, D17-IP-01..D17-IP-03) | PASS | D17-01 cold budget: UT1 (default -1), UT3 (0), UT4 (100), UT5 (-1), UT6 (-2 rejected), IT1, IT2. D17-02 JSONL: IT3, IT4, IT6, UT9. D17-03 prefix restore: UT12 classifies unsafe, UT13 verifies no slot mutation, ST3 stress; no row applies prefix restore. D17-IP-01 mode: UT2, UT7, UT8, IT3, IT5, IT10. D17-IP-02 dir: IT3, IT6. D17-IP-03 raw gating: UT10, IT5. |
| 3 | Positive and negative coverage (positive, negative, boundary) | PASS | Positive: IT1 startup with valid budget, IT3 redacted JSONL created, SY1-SY3 exact repeat restores. Negative: IT2 invalid budget rejected, IT5 raw mode rejected without log-prompts-dir, UT6 negative rejection, UT8 garbage mode rejected. Boundary: UT1 default -1, UT3 zero, UT4 positive 100, UT5 -1 explicit. |
| 4 | Observability checks (label allowlist, metric families, JSONL schema) | PASS | UT18 metric label allowlist. IT12 grep for forbidden patterns. IT11 lists 8 metric families matching design part 4 table. IT4 JSONL record shape lists 10 fields matching design part 1 required fields (minus raw_prompt_file which is correctly absent in redacted mode). |
| 5 | Clean-build and session rules (clean-build, freshness, ASCII, report naming, _test_output) | PASS | Lines 213-218: explicit clean-build rule for llama-server.exe and test-cache-controller.exe, binary freshness within 10 minutes of session start, plain ASCII labels (PASS, FAIL, SKIP, BLOCKED), test report at `test-report-YYYYMMDD-NN.md`, non-durable artifacts under `_test_output/`. |
| 6 | Test plan is generic (no specific test run or numbers) | PASS | Plan references durable prior docs (Stage 15 V2 B05 driver body, Stage 16 model-log baseline, Stage 16 F-16-TR-03 handoff) but contains no specific test run numbers. All row assertions describe the contract, not the outcome. |
| 7 | Risks and open questions (owners, mitigations, no silent re-introduction) | PASS | Six risk rows R17-TP-01..R17-TP-06, owners named (Manager x5, Developer x1), mitigations specific. N17-IMPL-03 (cold budget 0 rejected without hybrid mode) captured in R17-TP-05. Deferred items explicitly excluded in R17-TP-01, R17-TP-04. |
| 8 | Tier coverage (Unit 18, Integration 12, Synthetic 5, Stress-longrun 3, Heavy 2) | PASS | Measured: 18 unit rows TP-17-UT1..UT18, 12 integration rows TP-17-IT1..IT12, 5 synthetic rows TP-17-SY1..SY5, 3 stress-longrun rows TP-17-ST1..ST3, 2 heavy rows TP-17-HV1..HV2. Total 40 rows. All five tiers present. |
| 9 | Coverage and closure contracts (T114 >= 0.80, T114a >= 0.70, T115 dedup, BLOCKED-coverage-setup, BLOCKED-live-metrics-scrape, BLOCKED-test-session-scope) | PASS | Lines 209-211: T114 >= 0.80, T114a >= 0.70, T115 per-file dedup explicit. Lines 210-211: coverage setup gaps are BLOCKED-coverage-setup not FAIL, per qa.md improvement memory. R17-TP-02 names BLOCKED-live-metrics-scrape. R17-TP-03 names BLOCKED-test-session-scope for heavy rows. |
| 10 | Document quality (300-line cap, LF line endings, no unicode icons, references complete, decisions verbatim) | PASS | 264 lines, 0 CR bytes (LF only), 24385 total bytes. No unicode icons (grep finds only literal "unicode" word in the rule statement). References design parts 1-4 and 6, implementation parts 1, 4, 5, prior test plan parts 12, 25, 26. D17-01..D17-03 and D17-IP-01..D17-IP-03 listed verbatim (lines 35-40). |

## Findings table

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| (none) | BLOCKING | - | - | - |
| F-27-01 | non-blocking | Metric name drift between design and implementation for `cache_checkpoint_admissions_by_shape_total` | Design part 4 names the family `cache_checkpoint_admissions_total` (counter extension). Implementation review step 11 and the plan's IT11 row name it `cache_checkpoint_admissions_by_shape_total`. The plan uses the implementation's actual exposed name, which is correct for test execution; design/implementation naming drift is a pre-existing concern inherited from the implementation gate (PASS) and the test plan does not introduce it. | None for this gate. Note in test report which name was actually scraped. |
| F-27-02 | non-blocking | D17-IP-01..D17-IP-03 labeled as "Manager decisions (binding)" | Plan line 33 header reads "Manager decisions (binding)" then lists D17-01..D17-03 and D17-IP-01..D17-IP-03. The D17-IP-* prefix indicates these are implementation-plan decisions, not Manager design-gate decisions. D17-01..D17-03 come from design part 6; D17-IP-01..D17-IP-03 come from the implementation plan and are binding for code but not formally Manager-gated. Substance is correct: all six are honored throughout the plan. | None for this gate. Optional cosmetic relabel: "Binding decisions" with a note that D17-01..D17-03 are Manager-gate decisions and D17-IP-01..D17-IP-03 are implementation-plan decisions. |
| F-27-03 | non-blocking | Preload skip rule restated correctly but inverted from part-12 wording | Lines 102 and 172 say `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` "allowed only for startup and metric-shape rows" / "is not allowed for these rows" (referring to model-backed save/restore/checkpoint rows). Part-12 forbids the skip for model-backed save/restore/checkpoint rows. Both lines state the same rule, just inverted; the test plan rows IT4..IT12 are all MTP-backed and not startup-only or metric-shape, so the rule applies. Substantively correct. | None for this gate. The two restatements are consistent. |
| F-27-04 | INFO | Plan line count is 264, not 220 as cited in the brief | Measured: 264 lines, 24385 bytes, 0 CR characters. The brief said "220 lines" but the actual file is 264 lines (still under the 300-line cap). | None; the cap is satisfied. |
| F-27-05 | INFO | Test plan correctly captures implementation review non-blocking finding N17-IMPL-03 | R17-TP-05 (line 239) explicitly records "If the implementation review's N17-IMPL-03 finding (cold budget `0` rejected without hybrid mode) holds, the unit assertion is `0` accepted only with hybrid. The test plan records the rule explicitly to avoid executor drift." This is the test plan acknowledging the implementation review's non-blocking finding. | None; coverage adequate. |
| F-27-06 | INFO | R17-TP-02 acknowledges BLOCKED-live-metrics-scrape as a distinct verdict from PASS | Implementation evidence part 4 records that public `/metrics` samples were not captured in the implementation session. R17-TP-02 names `BLOCKED-live-metrics-scrape` as a distinct verdict for IT11/IT12 if the test-execution session cannot produce a live scrape. The plan correctly differentiates this from PASS, FAIL, and SKIP. | None. |
| F-27-07 | INFO | Deferred items not silently re-introduced | Plan excludes cold startup ownership reconciliation, orphan staging cleanup extension, semantic-boundary dense-checkpoint filter, and raw prompt file reference emission in the "Out of scope" block (lines 59-62). R17-TP-01 and R17-TP-04 reinforce the exclusion. IT3 (JSONL emission at startup) and SY5 (cold pressure bounded) are bounded so they do not depend on deferred work. | None. |

## Counts

- BLOCKING: 0
- non-blocking: 3
- INFO: 4

## Coverage verdict

The test plan covers all 9 Stage 17 implementation scope items with concrete
rows:

- bounded restore-miss reason model: UT11 (enum mapping)
- JSONL prompt evidence (off, redacted, raw): UT2, UT7, UT8, UT9, UT10, IT3, IT4, IT5, IT6
- prefix-candidate detection (no restore): UT12, UT13, ST3
- cold budget accounting (0, positive, -1, invalid): UT1, UT3, UT4, UT5, UT6, IT1, IT2
- skip-before-write cold pressure: UT14, IT7, ST2
- cold eviction: IT9, ST2, SY5
- target/draft atomicity: UT15, IT10
- checkpoint-density admission policy: UT16, UT17
- bounded metric label allowlist: UT18, IT11, IT12

Five tiers present:

- 18 unit
- 12 integration
- 5 synthetic
- 3 stress-longrun
- 2 heavy

Total: 40 rows.

## Manager decision verdict

| Decision | Coverage | Verdict |
| --- | --- | --- |
| D17-01 (`--cache-cold-max-mib`, reject < -1) | UT1, UT3, UT4, UT5, UT6, IT1, IT2 | PASS |
| D17-02 (JSONL, one record per lookup, no prompt text, no raw paths) | IT3, IT4, IT6, UT9 | PASS |
| D17-03 (prefix restore NOT implemented; only `unsafe_prefix_rejected`) | UT12, UT13, ST3 (no row applies restore) | PASS |
| D17-IP-01 (`--cache-prompt-evidence` mode, off/redacted/raw, default off) | UT2, UT7, UT8, IT3, IT5, IT10 | PASS |
| D17-IP-02 (`--cache-prompt-evidence-dir` PATH) | IT3, IT6 | PASS |
| D17-IP-03 (raw mode requires `--log-prompts-dir`) | UT10, IT5 | PASS |

## Deferred items verdict

| Item | Plan disposition | Verdict |
| --- | --- | --- |
| Cold startup ownership reconciliation | Out of scope, R17-TP-01 | PASS |
| Orphan staging cleanup extension | Out of scope, R17-TP-01 | PASS |
| Semantic-boundary dense-checkpoint filter | Out of scope, R17-TP-01 | PASS |
| Raw prompt file reference emission | Out of scope, R17-TP-04 | PASS |
| Live `/metrics` scrape (implementation session) | Tested by IT11/IT12 with BLOCKED-live-metrics-scrape fallback (R17-TP-02) | PASS |
| Stage 4-9 regression | Out of scope, deferred to prior stage parts | PASS |
| Stage 12/15 S/L full re-run | Out of scope, framework hooks only | PASS |
| Stage 15 B01..B08 full re-run | Out of scope, framework only | PASS |

## Verdict

PASS. The test plan maps the Stage 17 design and implementation to 40
verifiable rows across all five tiers, honors all six Manager and
implementation-plan decisions, explicitly excludes deferred items, applies
the standard clean-build and freshness rules, and routes handoff correctly.
Three non-blocking findings are scoped to cosmetic naming and do not block
the gate.

The implementation review's non-blocking findings (N17-IMPL-01 LRU order,
N17-IMPL-02 single-value reject reason, N17-IMPL-03 zero-value requires
hybrid mode) are either out of test-plan scope (LRU order, reject reason
fidelity) or correctly captured (N17-IMPL-03 in R17-TP-05).

## Handoff

Next owner: **Manager** for the test-plan gate. After Manager approval,
QA opens a fresh test-execution session per the plan's Handoff section.
If Manager determines REWORK is needed, next owner is QA in a new fresh
session. No source code, design, implementation, architecture, or other
durable docs were modified by this review.
