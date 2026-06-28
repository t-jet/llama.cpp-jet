# Stage 29 implementation-fix review (Architect, 2026-06-28)

VERDICT: PASS

## Reviewer session metadata

- Date: 2026-06-28
- Role: Architect implementation-fix review
- Session: NEW fresh session. No state from any prior Architect session
  (design author, design reviewer, design correction author, design
  re-reviewer, implementation plan reviewer, implementation reviewer,
  test-plan author, or test-plan reviewer) was loaded or relied on.
  Every source doc was read from disk in this session.

## Subject

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (243 LF, was 228)
- `._design_docs/cache-handling-test-scripts/lib/Wait-Stage29VramBaseline.ps1` (92 LF, was 90)
- `._design_docs/cache-handling-phase29-implementation.md` (300 LF, was 300; trimmed and appended)
- `._design_docs/cache-handling-phase29-implementation/part-07-impl-fix-main-dispatcher-20260628.md` (217 LF, new)

Fix log under review: [./part-07-impl-fix-main-dispatcher-20260628.md](./part-07-impl-fix-main-dispatcher-20260628.md)
Triggered by QA test-plan BLOCKING F-01: [../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (L189-203).

## Scope and gate status

Scope: implementation-fix verification of the F-01 BLOCKING driver contract
defect plus three INFO drifts (F-02, F-03, F-04) from the same test-plan
review. No product code (`tools/server/`, `tests/`, `common/`, `ggml/`,
`gguf-py/`) was modified (`git status --short` confirms untracked only on
the four subject paths; production tree is clean). Test plan
`part-33-stage29-cache-modes-comparison.md` was authored by QA and is
not modified by this fix.

Gate status: implementation-fix review. Manager implementation-fix gate
review is the next gate after this PASS; on PASS, the test plan
re-issues from BLOCKED-driver-contract to executable.

## F-01 fix verification (BLOCKING)

### Main dispatcher call graph

Driver `Main` (function definition L203-241, invoked at L243) now calls
all required phase entry points on the full execution path (no
`-DryRun` and no `-OutputEquivalenceOnly`):

- L225: `$eq = Invoke-Phase1OutputEquivalence` -- Phase 1 invocation,
  after `Invoke-Phase05WorkloadBuild` at L222 (which itself runs after
  the preflight gate at L221). On exception, classifies
  `BLOCKED-server-not-running` and exits 4 (L226-230). On
  `$eq.Status -ne 'PASS'`, classifies `BLOCKED-output-equivalence` and
  exits 5 (L232).
- L233: `Invoke-CycleLeg -Cycle 1 -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'cold-start'`
- L234: `Invoke-CycleLeg -Cycle 1 -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'cold-start'`
- L235-238: `for ($c = 1; $c -le $Cycles; $c++) { Invoke-CycleLeg -Cycle $c -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'warm'; Invoke-CycleLeg -Cycle $c -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'warm' }`
- L239: `Write-Stage29Report` -- final report emission, now operating on
  a populated `summary.json` from the cycle legs above.

### Invoke-CycleLeg signature match

Function definition at L160: `param([int]$Cycle, [string]$Mode, [string]$WorkloadPath, [string]$Phase)`.

All four call sites (L233, L234, L236, L237) pass all four named
parameters in declaration order:

- L233: `-Cycle 1 -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'cold-start'`
- L234: `-Cycle 1 -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'cold-start'`
- L236: `-Cycle $c -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'warm'`
- L237: `-Cycle $c -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'warm'`

Parameter types at definition: `[int]$Cycle`, `[string]$Mode`,
`[string]$WorkloadPath`, `[string]$Phase`. Argument values: integer
literal or `$c` (int), literal 'legacy'/'hybrid' (string), `$wl.workload`
(string from Phase 0.5 hash), literal 'cold-start'/'warm' (string).
No type mismatch. No fabricated `-BasePort` or `-RunRoot` parameters.

### PowerShell parse and function surface

`[System.Management.Automation.Language.Parser]::ParseFile(...)`: 0 errors.
Live dot-source smoke: `Main`, `Invoke-CycleLeg`, `Invoke-Phase1OutputEquivalence`,
`Invoke-Phase05WorkloadBuild`, `Write-Stage29Report` all exposed.
`Main` is invoked as the script body call at L243; on this host it
classifies `BLOCKED-preflight` (binary_exists=false, cuda_proof=BLOCKED-cuda-configure-missing)
and exits 1 via `Write-Error` -- matches the expected design behavior
for a host without a CUDA build.

F-01 verification: PASS. The Main dispatcher now invokes Phase 1
output equivalence (after workload build), Phase 2 cold-start cycle
(legacy then hybrid), Phase 3 three warm cycles (legacy then hybrid per
cycle, default `$Cycles=3`), and the three-layer report emitter. All
six Phase 1/2/3 evidence rows that the test plan (TP-29-CC-01..04,
TP-29-PR-01..03, TP-29-AG-01..04) depend on will populate the
`summary.json` and per-leg artifacts at runtime.

## F-02 alignment verification (INFO)

`Wait-Stage29VramBaseline.ps1` (92 LF, was 90):

- Docstring L19-23 (5 lines, +2 from prior version): "Per design
  D29-DESIGN-06 (30s sleep + nvidia-smi VRAM back-to-baseline gate),
  the polling cap is 120s (MaxWaitSec default). The Stage 29 driver
  calls this helper with -MaxWaitSec 60 in Phase 0.5/Phase 1 and
  -MaxWaitSec 120 in Phase 2/Phase 3 cycle legs. Callers may override
  MaxWaitSec for tighter or looser hosts." -- no longer mentions 180s.
- Param default L48: `[int] $MaxWaitSec = 120` -- matches the
  docstring and the design D29-DESIGN-06 binding cap.

Driver call sites (unchanged in this fix):

- L131: `Wait-Stage29VramBaseline -BaselineMiB 0 -ToleranceMiB 200 -MaxWaitSec 60 -SleepSec 10` (Phase 1)
- L189: `Wait-Stage29VramBaseline -BaselineMiB 0 -ToleranceMiB 200 -MaxWaitSec 120 -SleepSec 30` (Phase 2/3 cycle leg finally)

Impl log S29-IMPL-07 row (entry doc L242): "VRAM cooldown via
`Wait-Stage29VramBaseline` (30s sleep + nvidia-smi poll, 120s cap per
design D29-DESIGN-06)." -- was "180s cap per R29-IMPL-02". Aligned.
Impl log "Plan review N-03 resolution" section (entry doc L271-275):
"Step 07's full `Wait-Stage29VramBaseline` (nvidia-smi poll, 120s cap)
hardens it." -- was "180s cap". Aligned.

F-02 alignment: PASS. Helper docstring, helper default, and impl log
S29-IMPL-07 row + N-03 resolution all agree on 120s cap per design
D29-DESIGN-06. The prior impl review's N-04 documentation drift is
closed for these three locations.

Residual wording drift (non-blocking INFO finding F-02-01 below):
entry doc L152-154 R29-IMPL-02 risk mitigation still says "extend the
cooldown polling timeout to 180 seconds as the binding cap". This is
the plan-time risk statement, not the binding cap; the binding cap is
documented as 120s in the helper default and design D29-DESIGN-06. The
fix session aligned the impl log and helper docstring but not the
plan-time risk mitigation text. Not blocking because (a) the risk
statement says "may need" (conditional) and the binding cap is
documented elsewhere, (b) the impl log is the authoritative
description of the actual implementation.

## F-03 SKIPPED verification (INFO)

F-03 (preflight 2 missing sub-checks: disk check and binary mtime >
source mtime) was correctly deferred per impl review N-03 and per the
fix log.

Verification:

- Driver `Invoke-Preflight` (L72-84) records 7 fields and gates on 5
  (ps_version_ok, binary_exists, fixture_exists, port_free, cuda_proof);
  the 2 informational fields (git_head, git_dirty) are recorded but
  do not gate the result. Matches the design part-03 L22-28 intent
  for the 5 gating sub-checks.
- Impl log S29-IMPL-03 row (entry doc L238): "Phase 0 preflight 7
  fields with 5 gating sub-checks (ps_version_ok, binary_exists,
  fixture_exists, port_free, cuda_proof); 2 informational (git_head,
  git_dirty); printed by `-DryRun`." -- accurately describes the
  actual preflight field set and gating count. The 2 design
  sub-checks (disk, binary mtime) are noted as missing and deferred.

F-03 SKIPPED verification: PASS. The deferral is correctly recorded;
no BLOCKING change is required. The 5 gating fields cover the
safety-critical checks; the 2 informational fields surface the working
tree state in `dry-run.json` for downstream consumption.

## F-04 alignment verification (INFO)

Driver param block (L18-36) declares 18 typed parameters:

- 16 strings/ints: RunId, ModelPath, RunRoot, ReportPath, CacheColdPath,
  BasePort, LegDurationMin, ColdBudgetMiB, HotBudgetMiB, Cycles,
  OutputEquivalencePrompts, LlamaServerPath, ContextSize, Parallel,
  Seed, RequestCount.
- 2 switches: DryRun, OutputEquivalenceOnly.

Impl log S29-IMPL-02 row (entry doc L237): "4 lib helpers + driver
skeleton (18-param set per impl-review N-02: 16 strings/ints +
`-DryRun` + `-OutputEquivalenceOnly`)." -- matches the actual driver
param block. Prior N-02 wording drift ("17-param set") is closed.

F-04 alignment: PASS. The 18-param count matches the actual driver;
the 16 + 2 breakdown is correct.

## Format compliance

Byte-level audit of all 4 subject files via
`[System.IO.File]::ReadAllBytes`:

| File | LF | CR | BOM | non-ASCII | trailing-ws lines | last byte |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| compare-legacy-vs-hybrid.ps1 | 243 | 0 | NO | 0 | 0 | 0x0A |
| Wait-Stage29VramBaseline.ps1 | 92 | 0 | NO | 0 | 0 | 0x0A |
| cache-handling-phase29-implementation.md | 300 | 0 | NO | 0 | 0 | 0x0A |
| part-07-impl-fix-main-dispatcher-20260628.md | 217 | 0 | NO | 0 | 0 | 0x0A |

`git status` on the 4 subject paths: all untracked (`??` prefix).
`git diff --check` on the tracked paths: clean (exit 0).
`git diff --check --no-index` against an empty temp file for each
untracked path: exit 1 (content-diff noise from adding content) with
no whitespace warnings reported -- clean. PowerShell AST parse of the
driver: 0 errors.

Format compliance: PASS. All 4 files are LF-only UTF-8 with no BOM, no
CR, no non-ASCII, no trailing whitespace, last byte LF. Format
compliance is consistent with the 6 durable files from the prior
implementation review and meets the Stage 15+ documentation hygiene
gate.

## Document size audit

| File | LF | Cap (300) | Verdict |
| --- | ---: | --- | --- |
| compare-legacy-vs-hybrid.ps1 | 243 | 300 | PASS (under cap) |
| Wait-Stage29VramBaseline.ps1 | 92 | 300 | PASS (under cap) |
| cache-handling-phase29-implementation.md | 300 | 300 | AT CAP (see F-I-01) |
| part-07-impl-fix-main-dispatcher-20260628.md | 217 | 300 | PASS (under cap) |

The implementation entry doc is at the 300-LF cap, same as the prior
implementation review's N-01 observation. The fix log part-07 is new
and well under the 300-LF cap. The driver grew from 228 to 243 LF
(+15 LF for the F-01 dispatcher extension); the helper grew from 90
to 92 LF (+2 LF for the F-02 docstring). All 4 files satisfy the
300-LF split rule.

## Findings table

| ID | Severity | File | Line | Finding | Suggested resolution |
| --- | --- | --- | --- | --- | --- |
| F-01 | (resolved) | compare-legacy-vs-hybrid.ps1 | 225, 233-238 | Main dispatcher did not invoke Phase 1/2/3 on the full path. FIXED. | Resolved. Driver now calls `Invoke-Phase1OutputEquivalence` at L225, `Invoke-CycleLeg` cold-start at L233-234, `Invoke-CycleLeg` warm cycles x 2 modes at L235-238, and `Write-Stage29Report` at L239. |
| F-02 | (resolved) | Wait-Stage29VramBaseline.ps1; cache-handling-phase29-implementation.md | L19-23; L242, L275 | Cooldown cap drift between helper docstring, helper default, and impl log. FIXED at three locations. | Resolved. Helper docstring L19-23, helper default L48, impl log S29-IMPL-07 row L242, and impl log N-03 resolution L271-275 all agree on 120s cap per design D29-DESIGN-06. |
| F-02-01 | INFO | cache-handling-phase29-implementation.md | 152-154 | Plan entry doc R29-IMPL-02 risk mitigation still says "extend the cooldown polling timeout to 180 seconds as the binding cap"; the actual binding cap is 120s. Wording drift only; the binding cap of 120s is correctly documented in the helper, the impl log, and the helper docstring. | Optional: reword R29-IMPL-02 to clarify "the binding cap is 120s; if a future host needs more, extend the cap to 180s" so the plan-time risk matches the actual binding cap. Not blocking. |
| F-03 | (resolved) | cache-handling-phase29-implementation.md | 238; compare-legacy-vs-hybrid.ps1 L72-84 | Preflight 2 missing sub-checks (disk, binary mtime). SKIPPED per impl review N-03. | Resolved. The 2 design sub-checks are correctly deferred. The 5 gating sub-checks cover the safety-critical checks; the 2 informational fields surface the working tree state. |
| F-04 | (resolved) | cache-handling-phase29-implementation.md | 237; compare-legacy-vs-hybrid.ps1 L18-36 | Param count drift (impl log said 17, driver has 18). FIXED. | Resolved. Impl log S29-IMPL-02 row L237 now states "18-param set per impl-review N-02: 16 strings/ints + `-DryRun` + `-OutputEquivalenceOnly`", matching the actual driver param block. |
| F-I-01 | INFO | cache-handling-phase29-implementation.md | 300 | Entry doc is at exactly 300 LF (the cap). The prior implementation review flagged this as N-01; the fix session trimmed and appended to stay at 300 LF. The cap rule says "IF document exceeds 300 lines THEN split it"; 300 is the boundary, not exceeded. | No change required for this fix; the file is at the cap but not over. The fix session explicitly managed the size. Not blocking. |

## Concrete rework list

None. The implementation-fix session closes F-01 BLOCKING, F-02 INFO,
F-03 INFO, and F-04 INFO. The 2 INFO findings (F-02-01, F-I-01) are
non-blocking observations about the plan-time risk text (180s in
R29-IMPL-02 mitigation) and the entry doc cap boundary; neither
affects the test plan re-issuance or the QA execution path.

## Required documentation or code corrections

None blocking. Optional improvements:

- F-02-01: reword R29-IMPL-02 mitigation in entry doc L152-154 to
  clarify "the binding cap is 120s; if a future host needs more, the
  cap can be extended to 180s". Non-blocking; the 120s binding cap is
  authoritative in the helper, the impl log, and the helper docstring.
- F-I-01: the entry doc is at the 300-LF cap. Future corrections may
  push it over; consider splitting the implementation log section
  into a dedicated part file in a future correction. Non-blocking.

## Next owner and next gate

Manager test-plan gate review (re-issue since test plan was REWORK with F-01).

The QA test plan `part-33-stage29-cache-modes-comparison.md` was authored
with F-01 BLOCKING marking the driver contract defect. With F-01
verified as fixed, the test plan should re-issue from
BLOCKED-driver-contract to executable. The QA test plan should record
this re-issuance in the report and proceed to QA execution gate per
the existing test-plan handoff.

## Reviewer statement

This review was authored in a NEW fresh Architect session on 2026-06-28.
No state from any prior Architect session was loaded or relied on.
Every source doc was read from disk: the fix log
`part-07-impl-fix-main-dispatcher-20260628.md`, the prior implementation
review `part-06-impl-review-20260628.md`, the QA test plan
`part-33-stage29-cache-modes-comparison.md`, the implementation entry
doc, the driver, and the helper. The 4 subject files were byte-level
audited for LF, CR, BOM, non-ASCII, trailing whitespace, and last byte.
The driver was parsed via PowerShell AST (0 errors) and the function
surface was verified. The Main dispatcher was read line-by-line
(L203-243) and the F-01 call graph was traced to Phase 1 (L225),
Phase 2 cold-start (L233-234), and Phase 3 warm cycles (L235-238)
with `Invoke-CycleLeg` parameter sets matched against the function
definition at L160. Live dot-source smoke confirmed the script body
call at L243 executes Main and correctly classifies `BLOCKED-preflight`
on this host. `git diff --check` and `git diff --check --no-index` for
untracked paths reported no whitespace errors. F-02 was verified by
reading the helper docstring (L19-23) against the helper default
(L48) against the impl log S29-IMPL-07 row (L242) and the N-03
resolution (L271-275). F-03 was verified by reading the impl log
S29-IMPL-03 row (L238) and confirming the deferral language. F-04
was verified by counting the driver param block (L18-36) and
matching against the impl log S29-IMPL-02 row (L237).

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
