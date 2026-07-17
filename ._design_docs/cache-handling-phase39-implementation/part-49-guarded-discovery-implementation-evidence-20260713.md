# Part 49: guarded discovery implementation evidence

Date: 2026-07-13
Status: PARTIAL - ARCHITECT REVIEW REQUIRED
Authority: D39-EXEC-03

## Implemented

- Replaced the guarded route's apply-only body with strict `discover` and
  snapshot-bound `apply` operations.
- Split hot selection into a pure enumerator and the production-only blocked-ref
  metric wrapper.
- Moved production cold room-making to the shared predicate: cold residency and
  incoming-owner exclusion. Checkpoints are no longer omitted.
- Added separate integrity validation, per-incoming cold sets, process-local
  HMAC-SHA-256 tokens, constant-time comparison, and generation-bound snapshots.
- Apply revalidates generation, token, exact arrays, incoming identity, and
  budgets before one-shot consumption. Responses contain separate recomputed
  before/after inventories and explicit generation values.
- The live driver now preserves discover/apply requests and responses for
  TP-39-02 through TP-39-04 and calls `Assert-Tp3902`, `Assert-Tp3903`, or
  `Assert-Tp3904`.

## Focused evidence

- ON Release `test-cache-controller` and `llama-server` builds: PASS.
- OFF Release `server-context` build: PASS.
- Release controller suite: PASS. New cases cover pure enumeration, stable
  discovery, mixed exact/checkpoint cold sets, changed-then-restored budget and
  slot-ref staleness, wrong HMAC, exact revalidation, and before/after generation.
- Driver parse and metric self-test: PASS under PowerShell 7 and Windows
  PowerShell 5.
- Scoped whitespace check: PASS.

One intermediate controller run exited with a Windows access violation later
in the pre-existing Stage 38 completion section. The guarded cases had already
run. An immediate rerun and the final clean-build run both passed the full
suite. No Stage 39 failure signature appeared.

Logs are under `._test_output/` with the `stage39-rework-` prefix.

## Open evidence

This session did not run model-backed pressure, named Python route tests, or the
four canonical coverage commands. The generation owner now tracks guarded
budget and slot-ref writes directly and detects other inventory changes before
control operations, but the full mutation-family matrix from design Part 15 is
not yet present as a named test. Coverage remains unmeasured.

These gaps keep QA and Stage 39 closure blocked. Fresh Architect review should
first assess production predicate parity, token construction, atomic apply, and
generation ownership. Any review PASS still needs route, live, and coverage
evidence before QA execution.
