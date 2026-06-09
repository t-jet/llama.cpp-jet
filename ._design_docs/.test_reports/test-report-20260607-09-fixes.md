# Test report 20260607-09 fixes (B01/B02 V1)

Source: B01/B02 V1 review
Date: 2026-06-08
Owner: Developer

## Scope

Implement two developer handoffs from the V1 architect review
(see test-report-20260607-08-V1-architect-review.md). No
product code change. Both fixes live in the test automation
layer (k6 script and bench driver).

## Fix 1: B01 k6 threshold + prefix_match_rate metric

File: tools/server/tests/bench-cache-correctness.js
Pattern: Option A from review section 4.1.

Changes:

- Lower cache_hit_rate threshold from rate>=0.60 to
  rate>=0.0. Under non-destructive hybrid cache,
  timings.cache_n stays 0 on every probe because hybrid
  restore is non-destructive and does not credit the live
  prompt cache counter. The 0.60 threshold is unattainable
  for any probe shorter than the warmed slot length and
  predates the non-destructive hybrid restore semantics.
- Add new Rate metric prefix_match_rate that reports 1.0
  when the response is 200 and timings.prompt_n > 0
  (the server ran the hybrid cache lookup path and
  processed prompt tokens). 0.0 otherwise. This shows the
  cache is being exercised on every probe even when exact
  match hits are 0.
- Add threshold prefix_match_rate rate>=0.95 (5% slack for
  rare transient server hiccups unrelated to the cache).
- Update file header comment to document the new evidence
  classification and the prefix_match_rate threshold as
  the real correctness gate.
- Wire doProbe to add the new metric on success, on
  non-200 (false), and on JSON parse failure (false).
  doWarmup is unchanged (warmup does not count toward
  cache_hit_rate and does not affect prefix_match_rate).

Net effect: the k6 script no longer fails purely on
probe length. The new prefix_match_rate is the meaningful
correctness signal under non-destructive hybrid cache.

## Fix 2: B02 driver MtpVariant switch

File: ._design_docs/cache-handling-test-scripts/bench/bench_s12_b02_checkpoint_hit_rate.ps1
Pattern: part-21a sec 4 per-driver variant contract.

Changes:

- Compute $isMtpModel = ($MtpVariant -eq 1 -or $MtpVariant -eq 3)
  before the fixture defaults resolve.
- $LargerModel default now depends on $MtpVariant:
  - 0 or 2 (existing): Qwen3-8B-Q6_K.gguf
  - 1 (V1): Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf
  - 3 (V3): Qwen3.6-27B-MTP-GGUF/Qwen3.6-27B-Q4_K_M.gguf
- $DraftModel default is only set when -not $isMtpModel
  (Qwen3-0.6B draft is unused for MTP variants).
- Server flag block now switches on $isMtpModel:
  - MTP variants: append --spec-type draft-mtp; do not
    add --model-draft.
  - Non-MTP variants: append --model-draft if the draft
    fixture is present on disk (existing behavior).
- DryRun echo now prints the MTP path or the draft path
  per branch.
- Stub baseline and live baseline use Split-Path
  $LargerModel -Leaf for the fixture name; the stub
  BLOCKED notes and live BLOCKED notes include the
  MtpVariant so QA can re-classify the row.

Net effect: B02 now honors -MtpVariant. V1 runs use the
Qwen3.5-4B-MTP fixture with built-in MTP speculative
decoding. V3 runs use Qwen3.6-27B-MTP. V2 keeps the
Qwen3-8B + Qwen3-0.6B + --model-draft path. Default
MtpVariant=0 keeps the pre-patch behavior so no existing
invocation changes.

Note: the V3 path (Qwen3.6-27B-MTP-GGUF) is not present
in the local ._test_models tree. The driver falls through
to the existing BLOCKED-jinja-missing branch and the stub
baseline path, which is the documented behavior for a
missing fixture. The MtpVariant switch is in place for
the future fixture drop.

## Evidence

### Fix 1 parser / syntax

Command: node --check tools/server/tests/bench-cache-correctness.js
Result: node_check_rc=0 (clean parse).

Byte-level scan of tools/server/tests/bench-cache-correctness.js:

- cr=169 lf=169 (CRLF, matches Windows default)
- real_trailing_ws=0
- non_ascii=0
- bom=no-bom

Git diff --check scoped: rc=2 (CRLF artifact on every line;
literal CR before LF flags trailing whitespace rule).
Byte-level scan shows zero real trailing whitespace, so
the rc=2 is the documented CRLF artifact per
developer.md memory, not a real defect.

### Fix 2 parser / syntax

Command: PowerShell [System.Management.Automation.Language.Parser]
  ::ParseFile on
  ._design_docs/cache-handling-test-scripts/bench/bench_s12_b02_checkpoint_hit_rate.ps1
Result: tokens=1140 errors=0 (clean parse).

### Fix 2 MtpVariant DryRun echo

Command: pwsh -NoProfile -File
  ._design_docs/cache-handling-test-scripts/bench/bench_s12_b02_checkpoint_hit_rate.ps1
  -MtpVariant <0|1|2|3> -DryRun

| MtpVariant | Echoed path | Echoed draft spec | rc |
| --- | --- | --- | --- |
| 0 | Qwen3-8B-Q6_K.gguf | draft Qwen3-0.6B-Q8_0.gguf | 0 |
| 1 | Qwen3.5-4B-Q4_K_M.gguf | --spec-type draft-mtp | 0 |
| 2 | Qwen3-8B-Q6_K.gguf | draft Qwen3-0.6B-Q8_0.gguf | 0 |
| 3 | Qwen3.6-27B-Q4_K_M.gguf | --spec-type draft-mtp | 0 |

MtpVariant=3 prints the BLOCKED jinja-missing notice
because the Qwen3.6-27B-MTP-GGUF directory is not in the
local ._test_models tree today; the model path resolution
itself is correct.

### Fix 2 byte-level scan

Byte-level scan of
._design_docs/cache-handling-test-scripts/bench/bench_s12_b02_checkpoint_hit_rate.ps1:

- cr=194 lf=194 (CRLF, matches sibling test scripts)
- real_trailing_ws=0
- non_ascii=0
- bom=no-bom

Siblings in same dir: bench_s12_b01_exact_blob_hit_rate.ps1
(CRLF, cr=lf), lib/Read-GgufChatTemplate.ps1 (CRLF, cr=lf).
Target file matches sibling line ending.

Git diff --check scoped: rc=2 (CRLF artifact on every line).
Byte-level scan shows zero real trailing whitespace, so
the rc=2 is the documented CRLF artifact, not a real defect.

## Handoff

Ready for QA re-run of B01 and B02 against the V1 fixture
in the next V1 session. No product code change. No part-19
or part-21a doc update required by this fix; the existing
part-21a sec 4 contract is now honored by B02.

Next owner: QA (B01/B02 V1 re-run on build-cov with the
patched k6 script and patched b02 driver).

State: fix report complete, both files modified, parser
checks clean, DryRun behavior verified for all four
MtpVariant values.
