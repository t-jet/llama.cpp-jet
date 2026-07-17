# Part 19: Architect implementation review

Date: 2026-07-12
Verdict: REWORK REQUIRED

## Scope

Reviewed Stage 39 production changes, controller tests, live driver, approved
design Parts 1-3, implementation plan, and implementation evidence Parts 9-18.
The review excluded `tools/server/grafana/dashboard.json`.

Release `test-cache-controller` builds and passes. That result does not close the
findings below because current focused coverage does not drive the affected
production decision branches.

## Blocking findings

### F39-IR-01: production never emits `oversized_both`

Owner: Developer.

`mark_payload_kind_evicted()` records every capacity failure from
`tx_demote_payload()` as `evicted/both_filled`. `tx_demote_payload()` detects an
incoming object larger than the cold budget, but it does not distinguish whether
the complete pair also exceeds the positive hot budget. As a result,
`oversized_both` appears only through the metric debug helper.

This conflicts with design Part 1's oversized rule, Part 2's layer-case table,
and TP-39-04. It also breaks the acceptance requirement that production and docs
use the same reason taxonomy.

Acceptance check: production pressure tests must prove `evicted/oversized_both`
when the exact pair exceeds both positive budgets, and `evicted/both_filled`
when cold room-making fails for a pair that is not oversized in both layers.

### F39-IR-02: cold-disabled pressure emits no Stage 39 decision

Owner: Developer.

`mark_payload_kind_evicted()` calls the Stage 39 demotion and decision path only
when `cold_store.is_configured()` is true. With cold disabled or unconfigured,
it proceeds through the legacy eviction block without recording
`bypassed/cold_disabled`.

This conflicts with design Part 2's disabled-layer contract and TP-39-05. Current
tests enumerate the tuple through `debug_record_two_layer_decision_for_tests()`;
they do not prove the production pressure branch.

Acceptance check: a focused production-path test must trigger hot pressure with
cold disabled, assert one `bypassed/cold_disabled` decision for each candidate,
and confirm existing hot-only eviction behavior. The `--cache-ram 0` case must
still emit no Stage 39 row.

### F39-IR-03: QA handoff lacks production proof for required reason rows

Owner: Developer, then QA.

The typed-cardinality test injects all 32 decision tuples directly. It cannot
prove that production selects the required tuple for TP-39-04 or the
cold-disabled half of TP-39-05. The live driver contains no assertion for either
`oversized_both` or `cold_disabled`. Parts 13 and 18 therefore overstate test
readiness for the approved TP matrix.

Acceptance check: add focused production-path assertions for F39-IR-01 and
F39-IR-02, then add or document executable live-driver rows for those public
metric tuples. QA may measure coverage and execute the full matrix after
Architect re-review PASS.

## Conformance result

Core demotion-before-eviction flow, reversible multi-victim storage work,
persistent ownership claims, typed label mapping, and existing focused tests are
present. The two production taxonomy gaps leave code, design, and evidence out
of sync. Stage 39 is not ready for QA execution.

## Handoff

REWORK REQUIRED. Developer owns F39-IR-01 through F39-IR-03. After corrections,
request fresh Architect implementation re-review. Manager and QA gates remain
closed until PASS.
