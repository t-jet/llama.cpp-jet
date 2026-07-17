# Part 158: Architect TP-39-03 startup-marker fix review

Date: 2026-07-17
Verdict: PASS
Scope: QA report 20260717-03 startup-marker correction

## Review

The driver and server use the same exact, case-sensitive initialization record:
`speculative decoding context initialized`. The driver checks it with
`StringComparison.Ordinal`. It does not accept the separate
`speculative decoding will use checkpoints` sequence-removal warning.

The shared startup helper still requires the exact checkpoint configuration
`context checkpoints enabled, max = 32, min spacing = 0` and operational
`created context checkpoint` record. The live gate calls this helper after the
workload and before discovery or apply. Existing prepared-binding validation
still requires exactly two ordered same-owner records, each with nonzero target
and draft bytes and matching resident totals.

The pure negative matrix meaningfully rejects old-warning-only,
broad-regex-shaped, wrong-case old/new fallback, timing-only, missing-config,
and missing-creation inputs. Removing any required literal would make its
corresponding negative pass and fail the self-test.

Fresh PowerShell 7 and Windows PowerShell 5 parser APIs returned zero errors.
Both pure self-tests returned PASS and exit 0. No fallback or scope drift was
found. No model, build, coverage, product, fixture, seam, test-plan, threshold,
commit, push, or PR action ran.

## Handoff

PASS. Manager may authorize one bounded canonical TP-39-03 rerun. Coverage
remains closed until that node completes `Assert-Tp3903` with all required
artifacts.
