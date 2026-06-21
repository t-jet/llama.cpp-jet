# Stage 22 manager gates after QA rerun 06

## Manager D22-RERUN-06-F1/F2/F3 bug-fix gate

VERDICT: PASS
Date: 2026-06-20
Owner: Manager

Source report:

- [stage22-heavy-20260619-06-fixes.md](../.test_reports/stage22-heavy-20260619-06-fixes.md)

Decision D22-RERUN-FIX-14: accept the D22-RERUN-06-F1/F2/F3 fix for QA rerun.
Architect bug-fix review passed with no findings. The accepted fix preserves
`promoting` descriptors while promotion completion owns the queued lifetime and
adds bounded idempotent handling in `handle_promotion_completion`.

Decision D22-RERUN-FIX-15: QA rerun scope is the Stage 21 HV-chat-feasible
profile with the D22-RERUN-06-F1/F2/F3 binary. Required checks are req-008,
req-009, and req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in
demoting state`; zero `payload_unavailable`; zero `cannot restore yet`;
redacted prompt evidence; stable public metric names; and no runner, fixture,
endpoint schema, CMake, or public metric-name changes.

Decision D22-RERUN-FIX-16: QA must preserve the previous valid evidence chain:
clean build, `test-cache-controller` PASS with 111/111 tests, stable Stage 21
invariants, Stage 22 demotion coverage, and the new cold checkpoint promotion
completion regression.

Handoff: QA owns the D22-RERUN-06-F1/F2/F3 heavy rerun. Developer
test-results review follows the QA report.
