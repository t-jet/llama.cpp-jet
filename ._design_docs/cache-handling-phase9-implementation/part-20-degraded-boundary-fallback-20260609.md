# Stage 9 degraded boundary fallback follow-up - 2026-06-09

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Related report: [../.test_reports/test-report-20260609-01-fixes.md](../.test_reports/test-report-20260609-01-fixes.md)
Owner: Developer
Status: Implemented

## Scope

Stage 12 B02 exposed a Stage 9 fallback gap. Public chat rendering can create
non-native prepared metadata whose inferred message spans do not match the live
checkpoint span. That metadata is useful for namespace and protection decisions,
but it is not strong enough to require boundary-attached checkpoint admission.

## Change

Checkpoint admission now keeps native boundary validation strict. If native
metadata exists and no matching checkpoint boundary span is found, admission
rejects the checkpoint.

For non-native or degraded metadata, admission may create a checksum fallback
descriptor when no exact boundary span matches. Restore validation accepts that
descriptor only after token-span checksum validation. This matches the Stage 9
design allowance for token or position fallback when prepared boundaries are
missing or degraded.

## Evidence

- `cmake --build build --config Release --target llama-server test-cache-controller`
- `build\bin\Release\test-cache-controller.exe`: PASS, 87 tests.
- B02 final live evidence:
  `._design_docs/.test_reports/mtp-jinja-b02-final-20260609`

Final B02 rows:

| Row | Checkpoint admissions | Checkpoint hits | Checkpoint restores | Admission failures |
| --- | ---: | ---: | ---: | ---: |
| S12-MTP-B02-V1-Joriginal | 1 | 54 | 54 | 0 |
| S12-MTP-B02-V1-Jmarked | 1 | 25 | 25 | 0 |
