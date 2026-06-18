# Stage 20 design Part 2: Item 2 - Qwen3.6-27B-MTP fixture and Manager decision

Source: [../cache-handling-phase20-design.md](../cache-handling-phase20-design.md)

## Overview

Item 2 closes the `BLOCKED-test-session-scope` classification on
Stage 17 heavy-tier rows TP-17-HV1 and TP-17-HV2 by providing the
Qwen3.6-27B-MTP model fixture. The fixture is currently absent from
`._test_models/`. The Architect does NOT pick a fallback. The
Architect surfaces the fixture acquisition path as a Manager
decision: **R-20-DESIGN-MGR-01**.

This part records:

- The fixture requirement (what the rows need).
- The four acquisition candidates.
- A stub design that becomes concrete after Manager decision.
- The R-20-DESIGN-MGR-01 options, each with rationale and
  consequences.

## Fixture requirement

TP-17-HV1 and TP-17-HV2 are the Stage 17 heavy-tier rows that mirror
the Stage 16 long-run model-log analysis. They require:

- A Qwen3.6-27B-MTP model (or compatible successor) sized for an
  8 GiB hot cache plus a bounded cold budget.
- The model must be MTP-capable so that Stage 9 checkpoint
  integration is exercised end-to-end.
- The fixture must produce near-60k agentic chat prompts under
  realistic load.
- The fixture must be reachable from the test environment (the
  test scripts run on Windows 11 per
  [cache-handling-test-plan.md](../../cache-handling-test-plan.md)).

The fixture is consumed by:

- TP-17-HV1: long agentic workload with mixed exact, near-prefix,
  and new-user-turn prompts. Several-hour run.
- TP-17-HV2: comparison of TP-17-HV1 metrics and JSONL to the
  Stage 16 model-log baseline.

Both rows are NOT a normal PR gate. They are heavy manual or
nightly tier per test plan part-27 row classification.

## Acquisition candidates

The Architect surfaces four acquisition candidates for Manager
decision. Each is described below with cost, time, and risk.

### Candidate A: HuggingFace download

A developer or CI job downloads the Qwen3.6-27B-MTP GGUF from a
specific HuggingFace repo (revision pinned) and stores it under
`._test_models/Qwen3.6-27B-MTP-GGUF/`.

- Cost: ~16 GiB download (Q4_K_M quant) plus a one-time
  `huggingface-cli` setup.
- Time: 30-60 minutes on a fast link.
- Risk: model availability on HuggingFace is not confirmed. The
  repo name and revision require Manager research. License terms
  may require acceptance. The Architect has NOT verified that the
  Qwen3.6-27B-MTP GGUF is published; the family name and exact
  revision must be confirmed before download.

### Candidate B: tracked local copy

A developer who has the fixture on a personal volume copies it into
`._test_models/Qwen3.6-27B-MTP-GGUF/`. The fixture is then tracked
locally but NOT committed to git (the `.gitignore` pattern for
`._test_models/*` already excludes it).

- Cost: zero (already on a developer volume).
- Time: 5-10 minutes if the source is reachable.
- Risk: only one developer has the copy; if that developer's
  volume is offline, the fixture is unavailable. No audit trail of
  provenance.

### Candidate C: substitute with Qwen3.5-4B-MTP

Use the existing `._test_models/Qwen3.5-4B-MTP-GGUF/` fixture and
accept the size mismatch as a Stage 20 closure exception. The 4B
model is smaller than the 27B target, so the heavy-tier row
semantics change from "near-60k agentic prompts with 8 GiB hot
cache" to "near-60k agentic prompts with proportionally smaller
hot cache".

- Cost: zero.
- Time: zero (fixture already present).
- Risk: the heavy-tier rows no longer exercise the target workload
  shape. The Stage 16 model-log analysis was on the 27B class;
  comparison to that baseline via the 4B class is approximate.
  TP-17-HV2 becomes `BLOCKED-size-mismatch` rather than
  `BLOCKED-test-session-scope` and the comparison table is
  weakened.

### Candidate D: defer to a follow-up stage

Keep TP-17-HV1 and TP-17-HV2 at `BLOCKED-test-session-scope` for
Stage 20 closure and route the fixture acquisition to a separate
follow-up stage (Stage 21 or later).

- Cost: zero for Stage 20.
- Time: defer indefinitely.
- Risk: the heavy-tier rows stay blocked forever. The Stage 16
  model-log analysis never gets a comparative heavy-tier run. The
  contract from Stage 17 part-27 ("heavy manual or nightly tier")
  remains unmet.

## R-20-DESIGN-MGR-01 options

The Manager must pick exactly one option. The Architect records the
decision verbatim in the Stage 20 implementation log and propagates
the consequence into the test plan and the implementation plan.

| Option | Decision | Consequence |
| --- | --- | --- |
| A | Download Qwen3.6-27B-MTP from HuggingFace (specific repo + revision required) | Implementer adds `huggingface-cli download` step; fixture lands in `._test_models/Qwen3.6-27B-MTP-GGUF/`; TP-17-HV1/HV2 reopen as TP-20-HV1/HV2 with the 27B fixture |
| B | Track a developer local copy | Implementer copies from the named developer volume; fixture path is `._test_models/Qwen3.6-27B-MTP-GGUF/`; TP-17-HV1/HV2 reopen with the same fixture path; provenance recorded in the implementation log |
| C | Substitute with Qwen3.5-4B-MTP and accept size mismatch | Fixture path stays `._test_models/Qwen3.5-4B-MTP-GGUF/`; TP-17-HV1/HV2 reopen as TP-20-HV1/HV2 with `BLOCKED-size-mismatch` annotation on the row; Stage 20 closure records the exception |
| D | Defer to a follow-up stage | TP-17-HV1/HV2 stay at `BLOCKED-test-session-scope`; Stage 20 closes with the heavy-tier rows still blocked; a separate stage opens to acquire the fixture |

The Manager decision MUST include:

- The chosen option (A, B, C, or D).
- For option A: the HuggingFace repo name, the revision SHA, and
  the license acceptance status.
- For option B: the developer volume path and the date of copy.
- For option C: explicit acceptance of the size-mismatch
  annotation as a closure exception.
- For option D: the planned follow-up stage number.

The decision is recorded at Manager design gate, before
implementation planning opens. The Architect does NOT proceed to
implementation planning for Item 2 until the decision is recorded.

## Stub design (becomes concrete after Manager decision)

The Architect proposes the following stub design. After Manager
decision, the implementation plan fills in the missing detail.

### Stub: fixture path and evidence layout

The expected fixture path is `._test_models/Qwen3.6-27B-MTP-GGUF/`
with the following files:

- `Qwen3.6-27B-Q4_K_M.gguf` (or the Manager-specified quant).
- `chat_template_new.jinja` (chat template variant for the
  model; if not shipped with the GGUF, the implementer reuses
  the Qwen3.5-4B-MTP `chat_template_new.jinja` as a fallback).
- `mmproj-F32.gguf` only if multimodal is in scope; Stage 17
  heavy-tier rows are text-only, so the mmproj is optional and
  recorded as `BLOCKED-mmproj-not-required`.

The expected evidence path for TP-20-HV1/HV2 (post-decision) is:

- `._test_output/stage20-hv-YYYYMMDD-NN/hv1/` or `hv2/` per row.
- `server.out.log`, `server.err.log`, per-hour metric snapshot,
  JSONL tail.
- `._design_docs/.test_reports/stage20-heavy-YYYYMMDD-NN.md` (QA
  report for heavy tier).

### Stub: per-row scope

TP-20-HV1 (reopened from TP-17-HV1):

- Cold budget enabled, 8 GiB hot cache, several-hour run.
- Mixed exact, near-prefix, and new-user-turn prompts.
- Capture prompt identity drift, restore miss reasons, cold byte
  growth, cold write failures, host allocation failures.
- Pass/fail: bounded counters, no crash, no corrupt restore.

TP-20-HV2 (reopened from TP-17-HV2):

- Same setup as HV1 plus the Stage 16 model-log baseline available.
- Compare HV1 metrics and JSONL to the Stage 16 baseline.
- Pass/fail: comparison table in the heavy run report; no new
  product bug introduced.

### Stub: per-row caps

HV1 and HV2 are several-hour rows per test plan part-27. The
framework that drives them is NOT yet decided (the S/L framework
runs hours-long, but the heavy tier may use a separate harness).
The implementation plan proposes a kickoff script
`kickoff-stage20-heavy.ps1` based on the
`kickoff-v2-stress-longrun.ps1` template with a 4-hour per-row
cap (down from the "several-hour" Stage 17 wording) for
predictable session scope. The 4-hour cap is a stub; the
implementation plan may revise it after Manager decision.

## Test plan rows proposed (stub state)

Two heavy-tier rows reopen TP-17-HV1 and TP-17-HV2. Until Manager
decision, the rows stay at `BLOCKED-test-session-scope`. After
Manager decision:

| ID | Type | Fixture | Preconditions | Command or call | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TP-20-HV1 | heavy | per Manager decision (27B or 4B substitute) | cold budget enabled, 8 GiB hot cache (or proportionally scaled for 4B substitute), several-hour run, kickoff-stage20-heavy.ps1 | run a long agentic workload with mixed exact, near-prefix, and new-user-turn prompts | bounded counters, no crash, no corrupt restore; for option C, also `BLOCKED-size-mismatch` annotation | per-hour snapshot of metrics + JSONL tail + server logs | heavy MTP run reproduces Stage 16 log class with bounded outcomes; mirrors TP-17-HV1 |
| TP-20-HV2 | heavy | same as HV1 | same as HV1 plus Stage 16 baseline | compare HV1 metrics and JSONL to Stage 16 baseline | comparison table; no new product bug | comparison table in heavy run report | Stage 16 baseline comparable; mirrors TP-17-HV2 |

The fixture column reflects the Manager decision. Option A or B
yields the 27B fixture; option C yields the 4B fixture with the
`BLOCKED-size-mismatch` annotation; option D leaves the rows at
`BLOCKED-test-session-scope` and skips the test plan reopening.

## Open questions

- OQ-20-02: is the Qwen3.6-27B-MTP GGUF published on HuggingFace?
  If not, option A is not viable and the Manager must pick B, C,
  or D. The Architect has NOT verified publication.
- OQ-20-03: does the model require a separate license acceptance
  click on HuggingFace? If yes, option A requires the user to
  accept the license before the download starts.
- OQ-20-04: does the 27B model fit in 8 GiB hot cache plus a
  bounded cold budget on the test environment? The Stage 17
  part-27 wording assumes 8 GiB hot cache; if the system has less,
  option C (4B substitute) may be the only viable path.

## Handoff for Item 2

Implementation plan and implementation are NOT STARTED. The Manager
design gate MUST record R-20-DESIGN-MGR-01 before implementation
planning opens. The implementation plan may run in parallel with
Item 1 and Item 3, but the test plan author MUST NOT reopen
TP-17-HV1/HV2 until the decision is recorded.

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap.
