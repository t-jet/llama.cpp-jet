VERDICT: PASS

# Stage 29 implementation plan review (Architect, 2026-06-28)

Reviewer: Architect (implementation plan review)
Reviewer session: 2026-06-28 (NEW fresh session; explicitly distinct from
the Stage 29 design author, the prior independent Architect design
reviewer, the Architect design correction author, the prior
independent Architect design re-reviewer, and any prior implementation
plan sessions).
Subject:
- `._design_docs/cache-handling-phase29-implementation.md` (entry doc)
- 5 part files in
  `._design_docs/cache-handling-phase29-implementation/part-01a..04-*.md`
Approved design baseline:
- `._design_docs/cache-handling-phase29-design.md` (entry doc)
- 13 part files in `._design_docs/cache-handling-phase29-design/`
  (part-01..11, part-12 review, part-13 re-review)

## Scope and gate status

The implementation plan is a 6-file bundle (entry + 5 parts) with 10
ordered steps (S29-IMPL-01..10), 2 implementation-specific risks
(R29-IMPL-01..02), and resolutions for the 3 re-review INFO observations
(C-01..C-03) plus the 1 Manager-bound open question (OQ-29-01). The
plan covers the new driver
`compare-legacy-vs-hybrid.ps1`, four new lib helpers
(`metric-delta.ps1`, `cold-store-drift.ps1`, `output-equivalence.ps1`,
`workload-classify.ps1`), and a smoke-test of the existing design-
correct wrapper
`lib/compare-legacy-vs-hybrid-workload.ps1` (200 lines, NOT modified by
the plan). Production code, test code, runner scripts, the test plan,
the 14 design files, and the design-correct wrapper are bindingly
excluded from this plan's edits.

Gate status: implementation plan authoring. Manager implementation-plan
gate review is the next gate after this review.

## Reviewer session metadata

- Date: 2026-06-28
- Role: Architect implementation plan review
- Session: NEW fresh session. No state from any prior Architect session
  (design author, design reviewer, design correction author, design
  re-reviewer, or earlier plan reviewers) was loaded.
- Method: byte-level read of every source doc on disk; wrapper script
  byte-level read against its public `New-ComparisonWorkload` signature;
  Stage 20 lib byte-level read against its public
  `New-AgenticChatPrompt` signature at lines 82-99; design part-04 metric
  count verified by row-count; plan format audit (LF, CR, BOM, last byte)
  via PowerShell byte scan over all 6 plan files.

## 1. Design conformance

Each approved design section that requires an implementation step has a
matching step in the plan:

| Design section | Plan step |
| --- | --- |
| part-02 wrapper invocation (`New-ComparisonWorkload`) | S29-IMPL-01 smoke test |
| part-08 new artefacts (driver + 4 lib helpers) | S29-IMPL-02 author skeletons |
| part-03 Phase 0 preflight (7 sub-checks) | S29-IMPL-03 |
| part-03 Phase 0.5 tokenize helper sub-phase | S29-IMPL-04 |
| part-03 Phase 1 output equivalence (5 prompts, byte-identical) | S29-IMPL-05 |
| part-03 Phase 2 cold-start cycle (1 x 2 modes) | S29-IMPL-06 |
| part-03 Phase 3 warm cycles (3 x 2 modes) | S29-IMPL-06 |
| part-03 cooldown logic (30s sleep + nvidia-smi, max 120s design cap; plan extends to 180s per R29-IMPL-02) | S29-IMPL-07 |
| part-04 metric scraping + ground-truth cross-checks | S29-IMPL-08 |
| part-05 three-layer report + decision-support Q1..Q5 | S29-IMPL-09 |
| part-03 driver interface + `-DryRun` switch | S29-IMPL-10 pre-execution self-test |

All 11 design parts are covered by at least one plan step. No design
section is left without implementation hook.

## 2. Code correctness review (planning level)

The 10 steps form a coherent dependency chain:

- S29-IMPL-01 depends on PowerShell 5+ and the wrapper script being on
  disk; both are documented prerequisites.
- S29-IMPL-02 depends on S29-IMPL-01 PASS; the four lib helper names
  match design part-08 lines 26-31 (`metric-delta`, `cold-store-drift`,
  `output-equivalence`, `workload-classify`). Each helper is named
  exactly as design part-08 names it.
- S29-IMPL-03..10 each depend on the prior step's PASS plus the prior
  step's named postconditions.

The wrapper script's `New-ComparisonWorkload` signature (verified by
byte-level read of
`._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`)
declares `RequestCount`, `ServerUrl`, `OutPath`, `Distribution`,
`Seed`, `MaxTokens`, `Temperature`, `MinAnchors`, `SizeClass`,
`TokenizeTimeoutSec`. The plan's claim of four throws (RequestCount=0,
MaxTokens=0, Distribution sum != 1.0, missing key 'exact') matches
wrapper lines 80, 83, 87-89, 91-95 exactly. The plan's `TokenizeTimeoutSec
= 60` default matches wrapper line 65. The plan's claim that the Stage 20
lib default is 30s is correct (lib line 96). The plan's claim that the
wrapper has a `#requires -Version 5` directive at L1 is correct
(wrapper line 1).

The metric reconciliation in plan entry doc lines 73-75 ("13 per-request
direct stats", "4 gauge snapshots", "4 filesystem ground-truth cross-
checks", "4 process/GPU samples") matches design part-04 (per-request
13 rows, gauge 4 rows, filesystem 4 rows, process/GPU 4 rows). The
"12 per-leg Prometheus counter deltas (4 general + 8 hybrid-only)" claim
is OFF BY ONE against design part-04 (13 deltas: 3 general + 10 hybrid-
only). This is an INFO observation, not a blocker; see finding N-01.

The plan's total wall-clock budget (160 min authoring) and the design's
80 min execution budget match the design part-03 sequencing budget. The
plan entry doc "Total session wall-clock estimate" paragraph correctly
notes the Manager may approve a reduced 2-cycle warm run (40 min) for
budget pressure.

## 3. Doc-code consistency

The plan's affected-files list
(`._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
plus 4 lib helpers) matches design part-08 lines 26-31. The wrapper
script (`lib/compare-legacy-vs-hybrid-workload.ps1`) is correctly
EXCLUDED from the plan's affected-files list (the design-correction
option (a) wrapper is smoke-tested only, not modified). The Stage 20
lib (`lib/agentic-prompt-generator.ps1`) is correctly excluded (closed).
The Stage 24 runner (`stage24-chat-s02-s03-comparison.ps1`) is
correctly excluded (reference only per design part-08 line 17).

The plan's claim that `summary.json` records
`cooldown_duration_seconds`, `vram_baseline_mib`,
`vram_after_sleep_mib`, `vram_after_release_mib` (per leg) is
internally consistent with the cooldown logic in design part-03 lines
95-110. The plan's claim of `cold_store_drift_ratio` thresholds (1.10
warning, 5.0 BLOCKED) matches design part-04 lines 109-120.

## 4. Correction ownership

Every step (S29-IMPL-01..10) names the Developer as executor per the
AGENTS.md workflow ("The implementation session executes one step at a
time and updates the part file with the actual evidence at the end of
each step"). The Manager is the implementation-plan gate reviewer (per
plan entry doc line 142). The QA session authors the test plan in a
fresh session after this plan PASS (per plan entry doc line 79 and
design part-10 test plan mapping).

## 5. Format compliance

Byte-level audit of all 6 plan files on 2026-06-28:

| File | Lines | LF | CR | BOM | Last byte |
| --- | ---: | ---: | ---: | --- | --- |
| cache-handling-phase29-implementation.md | 233 | 233 | 0 | NO | 0x0A |
| part-01a-steps-1-5.md | 251 | 251 | 0 | NO | 0x0A |
| part-01b-steps-6-10.md | 236 | 236 | 0 | NO | 0x0A |
| part-02-affected-files.md | 122 | 122 | 0 | NO | 0x0A |
| part-03-evidence-plan.md | 206 | 206 | 0 | NO | 0x0A |
| part-04-risks-and-oq-resolutions.md | 172 | 172 | 0 | NO | 0x0A |

All 6 files are LF-only UTF-8 (no BOM, no CR, no non-ASCII, last byte
0x0A). Largest is 251 lines, under the 300-line durable-doc cap. The
plan bundle satisfies the format compliance requirements.

## 6. Findings table

| ID | Severity | File | Line | Finding | Suggested resolution |
| --- | --- | --- | --- | --- | --- |
| N-01 | INFO | cache-handling-phase29-implementation.md | 73 | Plan claims "12 per-leg Prometheus counter deltas (4 general + 8 hybrid-only)". Design part-04 lines 36-50 lists 13 deltas (3 general + 10 hybrid-only). Same off-by-one wording repeats in part-01b Step 08 line 44 and part-03 line 82. Non-blocking: implementation will scrape whatever counters the metrics endpoint actually exposes. | Implementation session: when scraping counters, use the 13 names from design part-04 directly (or whatever the post-Stage-26 namespace actually emits). Plan text correction can be applied during implementation log authoring or in a future design-update pass. |
| N-02 | INFO | cache-handling-phase29-implementation.md | 79 | Plan entry doc says "writes the four-row table from part-10" but the parenthetical lists 9+ test plan mapping row identifiers (TP-29-PRE-01, TP-29-OEQ-01, TP-29-CS-01, TP-29-WARM-01..03, TP-29-METRIC-01, TP-29-DRIFT-01, TP-29-COOLDOWN-01, TP-29-DECISION-01..05). The "four-row" wording is internally inconsistent with the listed content. Non-blocking: the QA test plan will use the row names from design part-10 lines 57-67. | Optional: rephrase "four-row table" to "test plan mapping table from part-10". Not blocking because the listed row identifiers are correct. |
| N-03 | INFO | cache-handling-phase29-implementation/part-01b-steps-6-10.md | 22 | Step 06 (Phase 2 + Phase 3) precondition says "the cooldown gate (Step 07) is in place". Step 07 (cooldown gate) is numbered AFTER Step 06 in the plan. Strict reading of the dependency rule ("each step starts with the prior step's postcondition") makes this circular. Implementation session can resolve by either (a) authoring cooldown logic inside Step 06's loop, (b) renumbering so the cooldown infrastructure is authored before the cycle loop, or (c) documenting the cooldown as a basic sleep gate in Step 06 with Step 07 hardening it. Non-blocking: the plan is reviewable as written; the implementation session will exercise one of the three resolutions. | Implementation session: choose (a), (b), or (c) and record the choice in the implementation log. |
| N-04 | INFO | cache-handling-phase29-implementation/part-04-risks-and-oq-resolutions.md | 116-122 | Plan correctly forwards OQ-29-01 (optional one-shot proxy capture) to Manager with three options (DEFER / APPROVE for one run / REJECT). The plan does not pre-resolve; this is the right gating. Manager will resolve at implementation-plan gate or execution gate. | No plan change required. Manager resolves OQ-29-01 at the gate. |

## 7. Concrete rework list

None. The plan passes the review.

## 8. Decision

PASS. The implementation plan conforms to the approved design (entry +
13 part files plus the wrapper). Each design section that requires an
implementation step has a matching plan step. The wrapper script's
actual API surface matches the plan's invocation claims. The
documentation drift between the plan's "12 Prometheus counter deltas"
wording and the design's 13-counter list is a documentation quality
issue (non-blocking) that the implementation session will resolve by
scraping the actual emitted counter set. The dependency-graph concern
in N-03 is a non-blocking observation; the implementation session will
pick one of the three resolutions and record it.

## 9. Required documentation or code corrections

None blocking. The implementation session is authorized to proceed with
authoring the 10 ordered steps on Manager implementation-plan gate PASS.

## 10. Next owner and next gate

Manager implementation-plan gate review. After Manager gate PASS:
Developer implementation session in a fresh session. After Developer
implementation PASS: QA test plan in a fresh session (per design
part-10 test plan mapping rows). After QA test plan PASS: Manager
execution gate. After execution: Developer test-results review. After
Developer review PASS: Manager closure per D-CLOSURE-29-NN.

## 11. Reviewer statement

This review was authored in a NEW fresh Architect session on 2026-06-28.
No state from any prior Architect session (design author, design
reviewer, design correction author, design re-reviewer, or earlier plan
reviewers) was loaded or relied on. All 6 plan files plus all 14
design files plus the wrapper script and the Stage 20 lib were read
from disk and independently verified. Format compliance was confirmed
by byte-level audit of all 6 plan files. Doc-code consistency was
confirmed by independent byte-level read of the wrapper script's public
function and comparison against the plan's claimed signature and throw
behavior. The 4 INFO observations are non-blocking and do not affect
the implementation-plan gate verdict.
