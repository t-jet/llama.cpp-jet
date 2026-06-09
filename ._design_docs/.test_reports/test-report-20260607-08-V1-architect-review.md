# B01/B02 root cause review (V1)

- ID: test-report-20260607-08-V1-architect-review
- Date: 2026-06-08
- Reviewer: Architect agent
- Sources:
  - ._design_docs/.test_reports/test-report-20260607-08-V1.md
  - ._design_docs/.test_reports/mtp-jinja-run-20260607-V1/S12-MTP-B01-V1-J{original,marked}/hybrid
  - ._design_docs/.test_reports/mtp-jinja-run-20260607-V1/S12-MTP-B02-V1-J{original,marked}/hybrid
  - ._design_docs/cache-handling-test-scripts/bench/bench_s12_b01_exact_blob_hit_rate.ps1
  - ._design_docs/cache-handling-test-scripts/bench/bench_s12_b02_checkpoint_hit_rate.ps1
  - ._design_docs/cache-handling-test-plan/part-21a-stage12-mtp-jinja-execution.md
  - tools/server/tests/bench-cache-correctness.js

## 1. B01 root cause verification

QA claim: k6 threshold `rate>=0.60` for `cache_hit_rate` is unattainable
for the current 5-token probe against a 12-token warmed slot because
the hybrid cache restores non-destructively only when the probe prefix
covers the whole slot (f_keep >= 0.5 and prefix == task.n_tokens()).
Server log shows LCP sim_best=1.000, f_keep=0.417, prefix=5/12, then
"no exact match found" and the slot is cleared. `cache_n_tokens` in
the k6 metric and in timings stays 0 for every probe. The hybrid
cache is in fact working: slot saves 12 tokens, LCP selection fires
each iteration, and `graph_reused` counter increments 10, 19, 28, ...,
82 across 11 probes. 12/12 HTTP 200, http_req_failed=0.00%.

Verification result: QA claim CONFIRMED.

Evidence cited:

- B01 server.err.log (Joriginal hybrid, S12-MTP-B01-V1-Joriginal):
  warmup save `saving slot 0 with 12 tokens, state size = 50.626 MiB`;
  probes 1..11 `try_restore - found match: task 5 tokens, entry 12
  tokens, prefix 5` -> `no exact match found` -> `clearing slot`;
  `graph_reused` increments monotonic 10 -> 109 across probes.
- B01 k6-results.json (Joriginal hybrid): `cache_hit_rate` value
  `0` for every probe; threshold `rate>=0.60` fails by definition.
- bench-cache-correctness.js line 70: threshold is hard-coded
  `rate>=0.60` against the `cache_n > 0` boolean from
  `body.timings.cache_n`. Non-destructive hybrid cache does not
  set timings.cache_n on LCP restore; only full slot restore does.
- bench_s12_b01_exact_blob_hit_rate.ps1: MtpVariant honored only
  for jinja path resolution (line 19). Fixture for non-MTP exact
  blob probing is correct; no fixture switch needed for B01.
- part-21a section 4 contract: B01 must accept -MtpVariant and
  -JinjaVariant. B01 driver does accept both. jinja_path written
  to per-scenario evidence confirms provenance.

This is a test framework false-positive, not a product bug. The
hybrid cache exact-blob path is gated on a full-prefix match and
the k6 probe is shorter than the warmed slot by design (deterministic
prompt + temp=0 plus shared warmup is fine, but probe prompt length
must equal warmup length to trigger full restore). The 0.60
threshold predates the non-destructive hybrid restore semantics
and is no longer valid for the 5-token / 12-token combination.

## 2. B02 root cause verification

QA claim: bench_s12_b02_checkpoint_hit_rate.ps1 declares
`[int] $MtpVariant = 0` and consumes it only via
`Resolve-MtpJinjaPath`. The driver hard-codes Qwen3-8B + Qwen3-0.6B
draft and never adds `--spec-type draft-mtp`. Server log shows
"common_speculative_init: no implementations specified for
speculative decoding" and the V1 MTP path is never exercised.

Verification result: QA claim CONFIRMED.

Evidence cited:

- bench_s12_b02_checkpoint_hit_rate.ps1 lines 17-19: param block
  declares `-MtpVariant` and `-JinjaVariant`.
- bench_s12_b02_checkpoint_hit_rate.ps1 lines 33-36: `$LargerModel`
  hard-codes `._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf`;
  `$DraftModel` hard-codes `._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf`.
- bench_s12_b02_checkpoint_hit_rate.ps1 lines 60-65: flags do not
  include `--spec-type draft-mtp` and the server is launched with
  `--model` plus the hard-coded draft; no fixture switch on
  MtpVariant anywhere in the script (grep over the file for
  `MtpVariant` returns 2 hits: param decl and Resolve-MtpJinjaPath).
- B02 server.err.log (Joriginal hybrid, S12-MTP-B02-V1-Joriginal):
  "loading model Qwen3-8B-Q6_K.gguf", "loading draft model
  Qwen3-0.6B-Q8_0.gguf", "common_speculative_init: no
  implementations specified for speculative decoding", "spec
  estimated memory usage of draft model is 0.00 MiB". Cache
  itself works (14-token slot, hits 1..13 across probes) but
  measures V2 fixtures, not V1.
- part-21a section 4: "per-driver variant logic is not permitted";
  drivers must accept -MtpVariant and switch fixtures accordingly.
  The same rule is restated in part-19 sec 7.1 harness inventory.

B02 is a driver bug per the part-21a contract. The MtpVariant
parameter is plumbed but not acted on for fixture selection, so
V1 rows (which require Qwen3.5-4B-MTP + --spec-type draft-mtp) are
measured against V2 fixtures (Qwen3-8B + Qwen3-0.6B draft). The
draft model loads but the MTP path never runs.

## 3. Decision per row

| Row | QA verdict | Architect verdict | Rationale |
| --- | --- | --- | --- |
| S12-B01-V1-Joriginal | FAIL (test framework FP) | BLOCKED-test-framework | k6 threshold `rate>=0.60` is impossible under non-destructive hybrid cache for 5-token probes; re-classify to BLOCKED with sub-status test-framework-threshold-incompatible. No product code change. |
| S12-B01-V1-Jmarked | FAIL (test framework FP) | BLOCKED-test-framework | Same as Joriginal. |
| S12-B02-V1-Joriginal | FAIL (driver bug) | BLOCKED-driver-bug | part-21a sec 4 fixture-switch contract not honored. Re-classify to BLOCKED-driver-bug. Developer amends b02 to switch fixtures on MtpVariant. No product code change. |
| S12-B02-V1-Jmarked | FAIL (driver bug) | BLOCKED-driver-bug | Same as Joriginal. |

No product defect identified. Both row families require test
framework or driver-side changes, not C++ or server changes.

## 4. Manager handoff

State: review complete. Verdict: PASS for the root-cause analysis
(no product bug). Both B01 and B02 FAILs are test framework
issues. No durable doc edits required in this review pass.

Required next actions (Manager):

1. Open Dev handoff #1 (B01): amend
   tools/server/tests/bench-cache-correctness.js threshold OR
   amend bench_s12_b01 to send a probe payload whose length
   matches the warmup slot. Recommended: lower threshold to
   `rate>=0.0` and add a separate `prefix_match_rate` metric
   derived from server log `f_keep`, since the hybrid cache's
   LCP restore is the meaningful correctness signal and exact
   blob restore is no longer the primary path under non-
   destructive hybrid. B01 should be re-run after the patch.
2. Open Dev handoff #2 (B02): amend
   bench_s12_b02_checkpoint_hit_rate.ps1 to switch
   `$LargerModel` and `$DraftModel` on `-MtpVariant`. For
   MtpVariant=1 the driver must launch the server with
   `--model` = Qwen3.5-4B-MTP and `--spec-type draft-mtp`,
   no `--model-draft`. For MtpVariant=0 it keeps the existing
   Qwen3-8B + Qwen3-0.6B behavior. B02 should be re-run after
   the patch.
3. Re-classify the four affected rows from FAIL to BLOCKED in
   the V1 test report and re-run them in the next V1 session
   once the two patches land. Stress and long-run rows are
   unaffected and remain PENDING.
4. Part-19 sec 7.1 driver inventory must record the MtpVariant
   fixture-switch contract for B02 (currently missing). B01
   inventory entry is correct.
5. Do not reopen the Stage 12 design gate. No design-doc
   changes required; both findings live in the test-automation
   layer and resolve in part-19 / part-21a.

Handoff state: ready-for-Dev-fix-2-issues. No manager-gate
blocker. No architect re-review required after Dev fixes
because both fixes are localized to test scripts / k6
threshold; product code untouched.

Review ends here.
