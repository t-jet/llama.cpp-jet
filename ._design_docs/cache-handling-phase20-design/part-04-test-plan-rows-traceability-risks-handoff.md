# Stage 20 design Part 4: test plan rows, traceability, risks, and handoff

Source: [../cache-handling-phase20-design.md](../cache-handling-phase20-design.md)

## Test plan rows proposed (consolidated)

Stage 20 reopens 10 Stage 17 BLOCKED-acceptable rows across three
tiers. The test plan at Stage 20 test-plan authoring renames the
rows to TP-20-XX and reclassifies them from `BLOCKED-*` to PASS or
BLOCKED with a documented harness/setup reason.

| Stage 20 row | Type | Tier | Reopens | Manager gate |
| --- | --- | --- | --- | --- |
| TP-20-SY1 | synthetic | synthetic | TP-17-SY1 | Item 1 |
| TP-20-SY2 | synthetic | synthetic | TP-17-SY2 | Item 1 |
| TP-20-SY3 | synthetic | synthetic | TP-17-SY3 | Item 1 |
| TP-20-SY4 | synthetic | synthetic | TP-17-SY4 | Item 1 |
| TP-20-SY5 | synthetic | synthetic | TP-17-SY5 | Item 1 |
| TP-20-ST1 | stress | stress-longrun | TP-17-ST1 | Item 3 |
| TP-20-ST2 | longrun | stress-longrun | TP-17-ST2 | Item 3 |
| TP-20-ST3 | stress | stress-longrun | TP-17-ST3 | Item 3 |
| TP-20-HV1 | heavy | heavy | TP-17-HV1 | Item 2 + R-20-DESIGN-MGR-01 |
| TP-20-HV2 | heavy | heavy | TP-17-HV2 | Item 2 + R-20-DESIGN-MGR-01 |

Counts by tier:

- Synthetic: 5 (from Item 1).
- Stress-longrun: 3 (from Item 3).
- Heavy: 2 (from Item 2, gated by R-20-DESIGN-MGR-01).
- Total: 10.

The test plan author MAY keep the TP-17-SY1..SY5, TP-17-ST1..ST3,
TP-17-HV1..HV2 names instead of renaming to TP-20-XX, depending on
the test plan author preference. The Stage 20 design does not
mandate the rename; the test plan author decides.

## Traceability

| Stage 17 deferred item | Stage 17 closure decision | Stage 20 item | Stage 20 row(s) | Owner |
| --- | --- | --- | --- | --- |
| Agentic prompt generator | D17-CLOSURE-01 SY1..SY5 BLOCKED-prompt-generator-missing | Item 1 | TP-20-SY1..SY5 | Developer |
| Qwen3.6-27B-MTP fixture | D17-CLOSURE-01 HV1..HV2 BLOCKED-test-session-scope (fixture absent) | Item 2 + R-20-DESIGN-MGR-01 | TP-20-HV1..HV2 | Developer (after Manager decision) |
| S/L framework re-invocation | D17-CLOSURE-01 ST1..ST3 BLOCKED-test-session-scope (framework drivers not invoked) | Item 3 | TP-20-ST1..ST3 | Developer |
| Stage 17 design part-04 synthetic tier rows | D17-CLOSURE-01 | Item 1 (generator) | TP-20-SY1..SY5 | Developer |
| Stage 17 design part-04 stress-longrun tier rows | D17-CLOSURE-01 | Item 3 (kickoff + wrapper) | TP-20-ST1..ST3 | Developer |
| Stage 17 design part-04 heavy tier rows | D17-CLOSURE-01 | Item 2 (fixture + kickoff) | TP-20-HV1..HV2 | Developer (after Manager decision) |

The traceability covers the three deferred items and the three
design-part-04 tier rows that the Stage 17 closure referenced. No
new test rows are added beyond the reopenings.

## Requirement traceability

Stage 20 does not add new cache behavior, CLI flags, or metrics.
It reopens blocked test rows from a closed stage. Requirement
coverage is unchanged from Stage 17 closure; the reopened rows
exercise the same Stage 17 contracts (R8, R9, R10, R14, R21, R21a,
R27-R33, R37-R48, R49-R60, R61-R68, R69-R83a, R87-R89, R90-R92,
R93, R99-R107, R120-R129). The reopened rows do not extend
requirement coverage; they re-verify it on agentic-sized inputs and
the framework drivers.

## Risks and open questions

| ID | Risk or question | Owner | Mitigation |
| --- | --- | --- | --- |
| R-20-01 | The agentic prompt generator (Item 1) is a new script. If the generator has a runtime bug (overshoot beyond +5%, deterministic seed collision), TP-20-SY1..SY5 fail. | Developer | Implementation plan includes a focused unit test for the generator (target vs actual token delta). A row that exceeds `MaxIterations` returns `FAIL` (not `BLOCKED`). |
| R-20-02 | Qwen3.6-27B-MTP fixture acquisition is gated by R-20-DESIGN-MGR-01. If the Manager picks option D (defer), TP-20-HV1/HV2 stay `BLOCKED-test-session-scope` and Stage 20 closure records the exception. | Manager | R-20-DESIGN-MGR-01 is a binding Manager decision before implementation planning. The implementation plan defers Item 2 until the decision is recorded. |
| R-20-03 | The Stage 20 kickoff is a new wrapper around existing S/L scripts. If the wrapper mis-translates the Stage 17 flags, the rows run without redacted evidence or bounded cold budget. | Developer | Implementation plan includes a wrapper dry-run that asserts the flags are present in the per-row command line. QA test plan asserts the JSONL tail is non-empty per row. |
| R-20-04 | The S/L framework session scope is 8+ hours wall-clock. The test session may not fit the full 22-row matrix in one go. | Manager | Implementation plan proposes splitting across two sub-sessions (stress in A, longrun in B). The QA test report records the per-sub-session boundary. |
| R-20-05 | The Stage 16 chat-path prompt-span boundary invariant (architecture part-09) interacts with the agentic prompt generator. If the generator's `messages` array shape differs from the V2 baseline, the boundary metadata may be incomplete. | Developer | Generator emits the same `messages` array shape as the Stage 16 chat-path boundary code path (system + user + assistant turns). QA test plan asserts `first_user_boundary` and `boundary_count` per row. |
| R-20-06 | The heavy-tier rows (TP-20-HV1/HV2) under option C (Qwen3.5-4B-MTP substitute) produce a size-mismatch result. The Stage 16 baseline comparison in HV2 is weakened. | Manager | Option C explicitly accepts the size-mismatch annotation. The heavy run report records the annotation and the comparison table is marked `BLOCKED-size-mismatch`. |
| OQ-20-01 | Agentic prompt generator Joriginal vs Jmarked variant for S/L rows. | Developer | Implementation plan decides per-row. Default is `new` (chat_template_new.jinja). |
| OQ-20-02 | Is Qwen3.6-27B-MTP GGUF published on HuggingFace? | Manager | Manager researches before picking option A. |
| OQ-20-03 | Does the 27B model require a separate license acceptance click? | Manager | Manager researches before picking option A. |
| OQ-20-04 | Does the 27B model fit in 8 GiB hot cache plus bounded cold budget? | Manager | If not, option C may be the only viable path. |
| OQ-20-05 | Stage 20 kickoff cap: V2 (L01 2h, L02 30m, L03 2h) or Stage 12 design (L01 6h, L02 30m, L03 2h)? | Developer | Implementation plan proposes V2 cap for predictability. |
| OQ-20-06 | Agentic prompt generator reuse for S/L rows vs short deterministic prompts? | Developer | Implementation plan decides per-row. |

## Handoff

Next owner: Architect for design review in a fresh session.

After Architect design review PASS, the design advances to Manager
for the design gate. The Manager design gate MUST record
R-20-DESIGN-MGR-01 with one of the four options in part 2 before
implementation planning opens for Item 2. Item 1 and Item 3 may
proceed in parallel with the Manager decision.

After Manager design gate PASS, the design advances to Developer
for implementation planning and implementation. The implementation
plan covers:

- Item 1: the generator script, its unit tests, the wrapper
  parameters, and the synthetic-tier test plan.
- Item 2: the fixture acquisition step (per Manager decision), the
  `kickoff-stage20-heavy.ps1` script (or a stub), and the
  heavy-tier test plan (or the BLOCKED reclassification).
- Item 3: the `kickoff-stage20-stress-longrun.ps1` wrapper, the
  wrapper parameters, and the stress-longrun-tier test plan.

The Stage 17 implementation log, tracker, document-index, and any
other durable doc are NOT modified by this design. The Stage 20
design files are untracked until the user approves their inclusion
in the index; the Manager adds the Stage 20 row to
`document-index.md` and the design entry description only after
Manager design gate PASS.

## Acceptance criteria for Stage 20 design

The design is acceptable when:

- All three items have a concrete design (script + wrapper +
  test plan rows) that maps to the Stage 17 deferred rows.
- R-20-DESIGN-MGR-01 is explicitly listed as a Manager decision
  with four options, each with rationale and consequence.
- The Architect has NOT picked a fallback for Item 2; the
  decision is deferred to Manager.
- The test plan rows reopen TP-17-SY1..SY5, TP-17-ST1..ST3, and
  TP-17-HV1..HV2 with clear evidence paths and pass/fail criteria.
- The traceability table maps each Stage 17 deferred item to its
  Stage 20 row and owner.
- The risks and open questions table lists R-20-01..R-20-06 and
  OQ-20-01..OQ-20-06 with mitigation and owner.
- The handoff section names Architect for design review, then
  Manager for the design gate, then Developer for implementation
  planning.

## File summary

| File | Lines | Purpose |
| --- | --- | --- |
| `cache-handling-phase20-design.md` | entry doc | scope, non-goals, prerequisites, Manager decision reference, gate status, handoff |
| `part-01-item1-agentic-prompt-generator.md` | Item 1 design | generator design, output format, prompt classes, TP-20-SY1..SY5 rows |
| `part-02-item2-mtp27b-fixture-and-manager-decision.md` | Item 2 design | fixture requirement, acquisition candidates, stub design, R-20-DESIGN-MGR-01 options, TP-20-HV1/HV2 stub rows |
| `part-03-item3-sl-framework-reinvocation.md` | Item 3 design | framework status, wrapper parameters, kickoff-stage20-stress-longrun.ps1, TP-20-ST1..ST3 rows |
| `part-04-test-plan-rows-traceability-risks-handoff.md` | consolidated | test plan rows by tier, traceability, requirements, risks, handoff |

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap.
