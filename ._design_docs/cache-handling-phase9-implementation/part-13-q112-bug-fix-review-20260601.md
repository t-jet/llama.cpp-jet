# Stage 9 Q112 bug-fix review - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
QA report: [../.test_reports/test-report-20260601-05.md](../.test_reports/test-report-20260601-05.md)
Fix report: [../.test_reports/test-report-20260601-05-fixes.md](../.test_reports/test-report-20260601-05-fixes.md)
Fix evidence: [part-12-q112-rematerialization-fix-20260601.md](part-12-q112-rematerialization-fix-20260601.md)
Owner: Architect
Status: PASS

## Scope

This review covers the Q112 bug fix only. It checks whether the fix is safe to
hand to QA for a rerun. It does not review the separate Q102/Q103 public
checkpoint probe limitation beyond preserving that rerun requirement.

## Verdict

PASS.

The root cause is plausible: after metadata-only eviction, the exact payload ID
on the entry is cleared while an evicted exact descriptor can remain in
`payload_descriptors`. Re-materializing the entry then adds a fresh exact
target/draft descriptor, leaving descriptor accounting and validation with both
the stale evicted descriptor and the new valid descriptor.

The code fix is minimal. `materialize_entry_payload()` now removes only
descriptors with all of these properties before exact-payload re-materialization:

- same `owner_entry_id` as the entry being materialized
- `kind == payload_kind::exact_blob`
- `residency == payload_residency_state::evicted`

That scope preserves checkpoint descriptors and preserves active, cold, demoting,
or promoting exact descriptors.

## Findings

No blocking findings.

## Evidence checked

- `tools/server/server-cache-hybrid.cpp`: `materialize_entry_payload()` prunes
  stale evicted exact descriptors before calling `attach_payload()` for the new
  exact payload.
- `tools/server/server-cache-hybrid.cpp`: `attach_payload()` still creates one
  descriptor-owned hot payload record, sets the exact payload ID through
  `set_entry_payload_id_for_kind()`, refreshes entry payload accounting, and
  leaves branch-node sync to the re-materialization commit path.
- `tools/server/server-cache-hybrid.cpp`: descriptor validation still enforces
  owner entry, payload kind, hot residency for restore, target/draft pair state,
  target and draft bytes, checksums, and resident-byte accounting.
- `tests/test-step13-stage8.cpp`: Q112 still asserts one target/draft descriptor
  and `352` rematerialized bytes after target/draft re-materialization.
- Developer evidence in Part 12 reports PASS for the focused Stage 8 binary,
  `test-cache-controller.exe`, `test-step10-metrics.exe`, and the focused CTest
  regression set.
- Architect spot check: `build\bin\Release\test-step13-stage8.exe` passed.

## Review decision

The fix preserves the Stage 5 descriptor separation contract and the Stage 9
exact/checkpoint separation contract. It does not delete checkpoint descriptors.
It does not delete non-evicted exact descriptors. The target/draft
re-materialized descriptor, hot record, branch node exact payload ID, pair state,
and resident-byte accounting remain coherent.

## Next action

Next owner: QA.

QA should rerun the Stage 9 focused regression set. The rerun should include
Q100/Q112 focused coverage and a corrected Q102/Q103 public checkpoint probe
that proves checkpoint admission before checking checkpoint restore or public
metric evidence.
