# Part 40: live pressure seam documentation corrections

Date: 2026-07-13
Status: READY FOR FRESH INDEPENDENT ARCHITECT RE-REVIEW
Scope: documentation only; no code, scripts, or tests changed

## Corrections

- F39-LPCR-01: Part 11 now requires one completion-admission latch from idle
  verification through cleanup. Seam state becomes irreversibly `consumed`
  before first mutation. Validation remains retryable; later failures remain
  terminal. Race and pre/post-pressure failure tests are named.
- F39-LPCR-02: requests require unique payload IDs, owner IDs, and hot ranks.
  Their payload set must exactly equal the production-eligible hot candidate set,
  with no omission or extra. Each owner is reindexed once; equal cold ranks keep
  `(last_validated_sequence, payload_id)` ordering.
- F39-LPCR-03: TP-39-04 now admits and measures under larger positive startup
  budgets, then lowers both below the pair. This replaces only old setup wording.
- F39-LPCR-04: Part 39 and test-plan Part 43 name the Python route target,
  controller race/failure tests, per-row controller and live assertions, normal
  coverage success, and a disposable forced merge-exit-23 fixture.

## Preserved boundaries

D39-EXEC-01 remains unchanged. Seam is compile/runtime guarded, loopback only,
one-shot, and unable to inject outcomes. Production pressure, transaction,
decision, metrics, logs, accounting, topology, thresholds, coverage phases,
denominator, server probe, 80 percent gate, and absolute no-argument
`whoami.exe` tail remain binding.

## Handoff

Fresh Architect re-review covers design Part 11, implementation Parts 39-40,
and test-plan Part 43 against design review Part 12. Code and script work remain
blocked until PASS.

Part 13 supersedes this handoff with REWORK. Implementation Part 41 records the
next documentation-only correction for F39-LPCR-RR-01 and F39-LPCR-RR-02.
