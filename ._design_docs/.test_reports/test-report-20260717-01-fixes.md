# Stage 39 D39-QA-01 fixes

Date: 2026-07-17
Status: ARCHITECT RE-REVIEW PASS; READY FOR QA RERUN
Scope: canonical TP-39-03 PowerShell driver and pure self-tests

## Finding

D39-QA-01 stopped at TP-39-03 because the canonical driver still used four
admissions, erased the incoming slot reference, selected a historical cold
checkpoint, and sent owner-reassignment fields. The current guarded route uses
one source request followed by one incoming request. That lifecycle leaves the
source exact row eligible and the incoming slot referenced.

## Correction

The `both-filled` path now:

- submits source then incoming once and does not erase the incoming slot;
- requires one eligible hot source exact row and one empty cold set;
- requests guarded proof for that source and requires ordered hot exact and
  checkpoint rows with one owner, matching pair state, positive target, draft,
  and resident component sizes, plus stable process and generation bindings;
- builds the two `prepared_bindings`, sends
  `tp39_03_setup:"same_owner_kind_sequence"`, and rejects any extra or
  historical request field;
- derives `H_low = R_exact` and
  `C_low = max(S_exact, S_checkpoint)`, where each serialized size is the
  checked component sum plus the 64-byte cold header. The helper checks
  `R_exact <= H_low < R_exact + R_checkpoint` and
  `max(S_exact,S_checkpoint) <= C_low < S_exact + S_checkpoint`;
- preserves the existing caps, guarded HMACs, token redaction, terminal checks,
  accounting, metrics, logs, and artifact capture.

## Pure regression evidence

The preflight-free self-test now rejects a second eligible owner, nonempty cold
inventory, missing or reordered proof kinds, owner drift, a zero component,
stale generation, missing process identity, and every forbidden historical
field. It also checks the exact natural request schema and budget formulas.

| Command | Result |
| --- | --- |
| PowerShell parser API | PASS, 0 errors |
| `pwsh.exe -NoProfile -File stage39-two-layer-pressure.ps1 -ModelPath ignored -MetricValidationSelfTest` | PASS, exit 0 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File stage39-two-layer-pressure.ps1 -ModelPath ignored -MetricValidationSelfTest` | PASS, exit 0 |

No model, build, coverage, product, seam, fixture, test-plan, or threshold work
ran in this correction.

## Next gate

Part 143 closes F142-01 through F142-03. The driver derives the checkpoint ID
from the guarded linked proof, requests both explicit IDs, authenticates and
retrieves byte-equivalent successful terminal proof, redacts terminal HMAC
artifacts, and uses a genuinely distinct second owner in the negative.

Parser validation and preflight-free self-tests passed under PowerShell 7 and
Windows PowerShell 5. Fresh Architect re-review is next. TP-39-03 and coverage
execution remain blocked until that review passes.

## Architect re-review

Part 144 records REWORK. F142-01 and F142-03 close. F142-02 remains open because
the driver compares reserialized parsed objects instead of response bytes,
cannot assert retrieval consumption through the current response body, and
does not assert the terminal proof's accounting or forbidden-effect fields.
Developer correction and another Architect re-review are required before any
canonical TP-39-03 or coverage run.

## F142-02 terminal proof rework

Part 145 records the bounded correction. The driver now compares preserved raw
apply-proof bytes with raw retrieval bytes, exposes consumption through a
required rejected apply retry, and checks the full successful TP-39-03 terminal
accounting, diagnostics, observation, effect, descriptor, file, byte-map, and
row-state contract. Pure rejecting mutations cover each assertion group.

Parser validation and preflight-free self-tests pass under PowerShell 7 and
Windows PowerShell 5. No model, build, coverage, product, fixture, seam,
test-plan, or threshold command ran. This evidence was the input to Part 146;
canonical TP-39-03 and coverage remained blocked.

## Architect terminal-proof re-review

Part 146 records REWORK. Raw apply-proof bytes and raw authenticated retrieval
bytes are compared directly; successful apply consumption, rejected original
apply retry, complete successful terminal assertions, and artifact redaction
are present. F142-02 remains open because pure tests do not reject terminal
identity, generation, record, retained-state, cold/staging inventory, topology,
checkpoint-link, or credential-leak mutations. Developer must add those focused
negatives before another Architect re-review.

## F146-01 terminal negative matrix fix

Part 147 adds isolated rejecting mutations for terminal status and identity,
generation order, prepared records, entry and branch state, cold and staging
inventories, topology, and the checkpoint link. Separate nonempty logs contain
the snapshot token, proof token, and terminal HMAC. Shared fixture values are
restored in `finally`.

Parser validation reports 0 errors. Preflight-free pure self-tests pass with
exit 0 under PowerShell 7 and Windows PowerShell 5. No model, build, coverage,
product, fixture, seam, test-plan, or threshold command ran. F146-01 correction
is ready for fresh Architect review; canonical TP-39-03 and coverage remain
blocked.

## Architect terminal negative matrix re-review

Part 148 records PASS. Each F146-01 group has an isolated meaningful reject:
status, identity, generation, prepared records, entry, branch, cold inventory,
staging inventory, topology, checkpoint link, and separate nonempty-log cases
for snapshot token, proof token, and terminal HMAC. Stateful fixture edits
restore in `finally`; log cases do not mutate the fixture.

Parser validation reports 0 errors. Preflight-free pure self-tests pass with
exit 0 under PowerShell 7 and Windows PowerShell 5. No model, build, coverage,
product, fixture, seam, test-plan, or threshold command ran. F146-01 and
F142-02 are closed. QA owns the already approved bounded canonical TP-39-03 and
coverage rerun.
