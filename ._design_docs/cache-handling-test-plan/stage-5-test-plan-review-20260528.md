# Stage 5 test-plan review: 2026-05-28

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope

Gate: Test-plan review.

Reviewed:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-test-plan.md`
- all files under `._design_docs/cache-handling-test-plan/`
- `._design_docs/cache-handling-test-scripts/README.md`
- relevant script and focused-test references in `execute_tests.ps1`, `run_cache_integration.ps1`, `run_stage4_h30_h37.ps1`, `tests/test-cache-controller.cpp`, and `tools/server/tests/unit/test_cache_modes.py`
- Stage 5 design and implementation docs, with emphasis on implementation evidence Part 6, review-fix evidence Part 8, and implementation re-review Part 9

Full integration tests were not run. This review used document inspection, script inspection, focused-test mapping, line-count checks, and ASCII/status-label checks.

## Verdict

PASS.

The Stage 5 test plan is current, generic, executable, and sufficient for QA execution after the wording fix below. The plan covers H40-H52, descriptor validation, pair-state/runtime mismatch, checksum, size, store reference, owner, residency validation, paired eviction and byte accounting, transactional restore failures, no-hit and no-recency behavior, empty-preimage rollback, unsupported clear preflight, Stage 5 metrics, legacy compatibility, Stage 4 regression coverage, clean-build rules, report evidence rules, automation limits, ASCII status labels, and public-surface stability.

The plan correctly separates public HTTP evidence from focused controller or fault-injection evidence. Public HTTP can prove normal target-only restore, metrics shape, legacy compatibility, public surface behavior, and measured eviction pressure. Descriptor corruption, pair-state mismatch, target/draft apply failures, empty-preimage rollback, and unsupported clear preflight require focused or fault-injection evidence before a row may pass.

## Findings

### F1: Current negative-runner coverage was overstated

Status: fixed during review.

`part-06-stress-tests-and-acceptance.md` said the implemented runner covered N01-N23. That was too broad for Stage 5 because N16-N23 include descriptor corruption, store reference mismatch, runtime pair mismatch, transactional apply failures, empty-preimage rollback, and unsupported clear preflight. The public PowerShell runner cannot create those preconditions by itself.

Correction made:

- `part-06-stress-tests-and-acceptance.md` now splits N01-N15 public-harness coverage from N16-N23 Stage 5 acceptance rows that need focused controller or fault-injection evidence.

### F2: One stress note still used Phase 3-only wording

Status: fixed during review.

`part-06-stress-tests-and-acceptance.md` still described non-blocking stress failures as acceptable for "Phase 3 sign-off". Stage 5 is the current QA gate.

Correction made:

- The note now refers to implemented-scope readiness instead of Phase 3 sign-off.

## Coverage check

PASS:

- H40-H52 are present in Part 3 and cover descriptor-backed target-only restore, malformed descriptor rejection, pair-state/runtime mismatch, target-plus-draft restore, transactional failure, empty-preimage rollback, unsupported clear preflight, paired eviction and byte accounting, evicted or cold descriptor rejection, Stage 5 metrics, legacy compatibility, Stage 4 regression, and stable public surface.
- Descriptor validation coverage names unsupported version or kind, target size zero, checksum mismatch, size mismatch, bad store reference, owner mismatch, non-hot residency, missing hot payload record, missing target bytes, invalid draft presence, evicted residency, and unsupported cold residency.
- Transactional restore rules require fallback without hit accounting, usage refresh, or recency refresh when validation, target apply, draft apply, commit, or rollback fails.
- Empty-preimage rollback and unsupported clear preflight are explicit in H45, H46, N22, N23, Part 5 evidence rules, and the Stage 5 README notes.
- Stage 5 metrics are listed in the plan, README, metrics evidence format, focused C++ stats checks, and Python metrics-shape test.
- Stage 4 regression coverage remains linked through H51 and the H30-H39 evidence rules.
- Clean build and fresh report requirements are explicit. The runner also rejects stale `llama-server.exe` binaries older than 10 minutes.
- Automation limits are documented: the main runner does not implement the full Stage 5 matrix, and reports must not mark a row `PASS` from scripts that only prove startup or completed requests.
- The entry file and all part files remain under 300 lines.
- Reviewed plan and README text use ASCII status labels: `PASS`, `FAIL`, `SKIP`, and `BLOCKED`.

Residual notes:

- H43 target-plus-draft public restore still needs a draft-model fixture before a model-backed `PASS`.
- H44-H46 and N16-N23 need focused controller or fault-injection evidence. That is a plan limitation, not a blocker, because the plan requires those evidence sources instead of weakening the expected behavior.
- `document-index.md` does not need a new entry for this review file because the parent test-plan entry links review reports.

## Handoff

Status: ready.

Next QA execution should start with a clean build, create a fresh `test-report-YYYYMMDD-NN.md`, and treat Stage 5 rows as passing only when the report maps each claim to public HTTP, focused controller, draft-model, or fault-injection evidence as required by the plan.
