# Stage 23 L03 runner-contract fix review 20260622-01

Verdict: PASS
Owner: Architect
Scope: Review of the L03 runner-contract fix before QA rerun. No product code, public flags, public metrics, tests, fixtures, commits, or pushes reviewed as changed.

## Inputs

- Stage 23 design: `._design_docs/cache-handling-phase23-design.md`
- Stage 23 implementation log: `._design_docs/cache-handling-phase23-implementation.md`
- Stage tracker and document index
- Test plan: `._design_docs/cache-handling-test-plan.md`, Stage 17 part 27, Stage 12 parts 18/18a
- Blocked L03 report: `stage23-remaining-l03-20260622-01.md`
- Developer fix report: `stage23-remaining-l03-20260622-01-fixes.md`
- Scripts:
  - `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l03_2h_mixed_workload.ps1`
  - `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
  - `._design_docs/cache-handling-test-scripts/lib/Write-LongrunEvidence.ps1`

## Decision

The fix satisfies the Stage 23 L03 runner contract enough for QA to rerun focused L03 with a fresh suffix.

The old blocked run was still a legacy-control loop: `Variant: legacy-2h`, one repeated probe, one public profile, one lookup outcome, and root `evidence-summary.md` left at `PENDING`. The fixed child runner now starts hybrid mode, divides the row cap across four harness prompt classes, writes machine-readable mixed-workload evidence, and ends the root summary with a non-PENDING result when all classes make requests.

## Findings

No blocking findings.

Advisory A-23-L03-01: The Qwen3.5 MTP public prompt evidence still reports `profile=checkpoint_dependent` for all smoke requests and `lookup_outcome=exact_entry_absent` in the 60 second smoke. This does not block the QA rerun. Stage 23 L03 is a runner-contract rerun gate, and the fixed artifact records the harness prompt class mix, request counts, distinct token-span checksums, distinct lookup paths, metrics deltas, server flags, and status. QA should cite both the harness class counts and the public prompt evidence spread in the rerun report. If the full two hour row again shows only one token-span checksum or one harness class, classify it as a runner evidence failure.

Advisory A-23-L03-02: Stage 12 operational text still describes L03 as a legacy control run. Stage 23 intentionally overrides L03 for this stage with a mixed-workload longrun. No Stage 12 documentation correction is required for the focused Stage 23 rerun.

## Evidence checked

- Parser checks passed for the L03 child runner and Stage 20 wrapper.
- Wrapper dry-run for L03 only passed with `BatchSize 1`, port 8990, Stage 23 flags, and side-log plan:
  - `rowCapSeconds=7200`
  - `exact_cache_prompt_seconds=2160`
  - `checkpoint_dependent_seconds=2160`
  - `near_non_exact_seconds=1440`
  - `new_uncached_seconds=1440`
  - `artifact=l03-mixed-workload.json`
- Child dry-run with generated Stage 17 base64 flags passed and printed the 60 second plan:
  - exact/cache-prompt 18 s
  - checkpoint-dependent 18 s
  - near/non-exact 12 s
  - new/uncached 12 s
- Developer smoke artifact `._test_output/stage23-l03-devfix-smoke-child-v2/l03-mixed-workload.json` records:
  - status `PASS`
  - 14 requests across all four harness classes
  - HTTP 200 for all requests
  - metrics before/after and deltas
  - 14 prompt evidence records
  - 8 distinct token-span checksums
  - 8 distinct lookup paths
- Developer smoke `evidence-summary.md` records `Variant: mixed-workload` and `Result: PASS`.
- Wrapper `Write-RowGate` requires `l03-mixed-workload.json` and `evidence-summary.md` only for `Row.Base -eq 'L03'`. L02 keeps its comparison artifact requirement. Other rows keep the existing base evidence list.
- `git diff --check` reported no whitespace errors for the reviewed runner paths and Stage 23 docs before this report was added.

## Contract assessment

Cap and split: PASS. The planned two hour cap is split 30/30/20/20 across exact/cache-prompt, checkpoint-dependent, near/non-exact, and new/uncached classes. Normal sampler granularity may add a small runtime tail; QA should report actual wall time from the rerun.

Machine-readable evidence: PASS. `l03-mixed-workload.json` is sufficient for plan, request counts, class counts, HTTP status counts, server flags, metric deltas, prompt evidence counts, checksum/path spread, and status.

Dry-run evidence: PASS. Wrapper dry-run exposes the two hour L03 mixed-workload plan. Child dry-run exposes the same plan shape at a short cap.

Regression risk: PASS. The L03-specific child change does not alter product code. The wrapper gate addition is row-scoped to L03; already accepted S06/S07/L02 wrapper changes remain unchanged in this review. No new risk was found for S01..S08, L01, or L02.

## Handoff

State: ready for Manager gate.

Next owner: Manager to open a focused L03 QA rerun with a fresh report suffix and fresh output/cold roots. QA does not need to rerun S01..S08, L01, or L02 for this fix.
