# Stage 12 scope-expansion design (post-closure)

- Date: 2026-06-07
- Author: Architect
- Parent: cache-handling-phase12-design.md
- Trigger: 2026-06-07 Stage 12 closure handoff listed 7 candidate items for
  post-closure scope-expansion. This part classifies each as CAN-DESIGN-OUT
  or REMAINS-BLOCKER and records required durable contracts.

## Classification table

| Item | Class | One-line summary |
| --- | --- | --- |
| A | CAN-DESIGN-OUT | MTP follow-up: cap-fix closure hold lifted per Manager D12 (2026-06-07) |
| B | REMAINS-BLOCKER | test-stage10-policy-lru line 105 semantic bug vs production |
| C | CAN-DESIGN-OUT | New cache algorithms, endpoints, CLI flags, metrics/diagnostics: out of scope |
| D | CAN-DESIGN-OUT | Coverage denominator change: scoped to T114/T114a split already in test plan part-13 |
| E | CAN-DESIGN-OUT | Source code changes: Stage 12 is operational validation, not implementation |
| F | CAN-DESIGN-OUT | Draft/MTP rows under closed cap-fix: closure is terminal, not Stage 12 |
| G | CAN-DESIGN-OUT | Coverage class of evidence for stress/bench: per part-04 evidence contract |

## CAN-DESIGN-OUT design summary

C. New cache algorithms, public inspection endpoints, CLI flags,
metric/diagnostic schema. Stage 12 non-goals (entry doc) exclude all
four. Each addition requires its own design stage with scope, contract,
observability, and acceptance. Recommend: do not fold into Stage 12.
Schedule a separate stage 13 (or follow-up) for any new cache algorithm
or operator surface. Required API envelope: server-cache-hybrid.h public
methods, tools/server/server.cpp CLI parser, server-cache-controller.cpp
metrics registration, tools/server/utils.hpp HTTP route table.

D. Coverage denominator change. T114/T114a split (19 combined files, 11
product-only files) is already a closure contract in
cache-handling-test-plan/part-13-t114-product-only-coverage.md and is
applied by run_coverage.ps1. Stage 12 is downstream of that contract;
denominator edits belong to the test plan or to a future coverage-method
stage. No new design needed.

E. Source code changes to llama-server, server-cache-hybrid.cpp,
focused test binaries, coverage script, k6 script. Stage 12 non-goals
exclude all of these. Stage 12 is operational validation only. If a bug
surfaces that demands code change, route through Stage 12 follow-up per
closure section 3 of part-07; do not expand Stage 12 scope.

F. Draft/MTP rows under closed cap-fix. Cap-fix closure 2026-06-07
(cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md)
is terminal. Draft/MTP coverage was settled by part-29 and test-report-
20260607-03.md. Reopen only via a new stage with new fixtures, not via
Stage 12 scope expansion.

G. Coverage class of evidence for stress/bench. Stage 12 part-04
(observability, testability, evidence) already records the evidence
contract: stress/bench use public Prometheus rows, focused C++ tests
(controller/hybrid/policy), and k6 throughput/latency. Coverage is a
Stage 10 T114/T114a contract on hybrid-path code; it is not a stress
or bench evidence class. No new design needed.

## REMAINS-BLOCKER analysis

### Item A: MTP-capable rows H53 and H54

Class change 2026-06-07: REMAINS-BLOCKER -> CAN-DESIGN-OUT per Manager
plan-change decision D12. Cap-fix closure hold lifted. The follow-up
scope is now part-21 (MTP x jinja follow-up test plan), 3 MTP variants
x 19 base x 2 jinja + 19 non-MTP x 2 jinja = 152 scenarios, multi-
session execution. The prior blocker analysis below is preserved for
the design record.

Prior blocker reason (superseded by D12): Stage 11 cap-fix closure
(part-29, 2026-06-07) held MTP-capable Qwen3.5-4B rows out of scope
because the MTP-capable fixture is not available in the local build-cov
environment. Reopening required (1) a fixture that exercises the MTP
path end-to-end, (2) a Stage 12 MTP scenario matrix, and (3) Stage 11
follow-up work to validate MTP admission/restore behavior under
cap-fix conditions.

Prior technical analysis (superseded by D12): the MTP path enters
through common_speculative_type parser (common_speculative_type_to_str
value "mtp"), routes through common/speculative.cpp draft decode, and
hits the cache adapter at server-cache-hybrid.cpp slot check-in.
Cap-fix lifted the server_n_outputs_max clamp at
tools/server/server-context.cpp:204 and the per-context assertion at
src/llama-context.cpp:2152. None of the MTP-specific calls were
exercised under cap-fix conditions; only the non-MTP speculative path
was tested.

Prior tradeoff analysis (superseded by D12):

1. Schedule a new stage (Stage 13 MTP Validation) that requires a
   Qwen3.5-4B MTP-capable fixture. Pro: clean scope, full test plan
   support. Con: blocked on fixture availability; uncertain timing.
2. Document MTP rows as deferred indefinitely. Pro: removes ambiguity.
   Con: drops MTP coverage from the cache acceptance story.
3. Replace MTP fixture with a synthetic MTP probe (focused C++ test in
   tests/test-cache-controller.cpp that injects a mock MTP path). Pro:
   unblocks coverage now. Con: not model-backed; public HTTP evidence
   still BLOCKED.

D12 decision: adopt option 1 in the form of a Stage 12 follow-up
session using V1 (Qwen3.5-4B-MTP, canonical local copy) and V3
(Qwen3.6-27B-MTP, copied from the user-side lmstudio tree into the
canonical `._test_models\Qwen3.6-27B-MTP-GGUF\` if not already
present) for the built-in MTP path, plus V2 (Qwen3-8B target +
Qwen3-0.6B separate draft) for the `--model-draft` path. Wall-clock
infeasibility forces multi-session execution per part-21 section 8.
The 2026-06-07 closure PASS is preserved; part-21 is the only
follow-up scope.

### Item B: test-stage10-policy-lru semantic bug

Reason: test-stage10-policy-lru at line 105 asserts behavior that
conflicts with the production policy in server-cache-policy-lru.cpp
lines 42-43. The test exercises byte-accounted LRU eviction with
protected-root retention, but the assertion shape does not match the
production retention math. The closure (part-07 section 3) records
this as pre-existing, out of cap-fix scope, separate session.

Technical analysis: tests/test-cache-controller.cpp test-stage10-policy-
lru calls cache_policy_lru_evict with a 4-element seed and a 200-byte
budget. Line 105 asserts that element 2 (a protected root) is retained
in the eviction result. The production policy at server-cache-policy-
lru.cpp:42-43 computes retention using byte_accounted_priority, which
ranks protected roots by last-touch timestamp and admits the newest
protected root to the eviction candidate list when the byte budget is
exceeded by more than 50 percent. The test's seed does not exceed 50
percent of the budget, so production correctly evicts the oldest
non-protected element; the test then asserts the wrong retained
element. The test is wrong, not production.

Solutions with tradeoffs:

1. Fix the test seed and assertion to match production
   (byte_accounted_priority at the 50 percent threshold). Pro: minimal
   change, preserves production behavior. Con: requires updating the
   test in the Stage 10 implementation log, not a new design.
2. Change production to retain the protected root regardless of byte
   pressure. Pro: matches test expectation. Con: contradicts Stage 4
   accepted design and breaks the byte-accounted LRU contract.
3. Rewrite the test to use a controlled budget that forces the
   threshold crossing. Pro: clearer test intent. Con: requires new
   test infrastructure (controlled seed helpers).

Recommended: option 1. The production behavior is correct per Stage 4
design; the test was added during Stage 10 implementation and never
matched production. Fix the test, update Stage 10 part-11
follow-up, and re-run T114 with the corrected test. No new design
stage needed.

User decision needed: yes/no on fixing the test now (option 1) and
re-running T114. If yes, route to Developer with a one-day patch. If
no, keep the test disabled and record as a known incorrect test in
the Stage 10 implementation log.

## Handoff

- Items C, D, E, F, G: CAN-DESIGN-OUT. No new design work. No gate
  state change. Stage 12 closure is unchanged.
- Items A and B: REMAINS-BLOCKER. Awaiting user decision (see above).
  Stage 12 closure is unchanged regardless of decision; the items are
  tracked as post-closure follow-ups and do not gate Stage 12.
- The entry doc Status line is updated to record this part-10
  classification and the 2026-06-07 date.
