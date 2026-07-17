# Part 9: independent Architect design re-review

Date: 2026-07-12
Status: PASS

## Scope

This fresh review checks F39-AR3-01 and the corrected Stage 39 design in Parts
3 and 8. It also checks Parts 5-7 for regression, current hybrid metrics
conventions, and the production pressure path for implementability.

## Finding closure

| Finding | Result | Basis |
| --- | --- | --- |
| F39-AR3-01 | CLOSED | Both new families accept only `mode="hybrid"`. The controller supplies a typed enum, the exporter owns the string mapping, and invalid values produce no public series. TP-39-15 verifies valid mappings, invalid rejection, scrape values, and family cardinality. |

## Taxonomy and cardinality

Part 3 fixes every public label domain. Decision rows have one mode, four
results, and eight reasons, so their closed Cartesian bound is `1 * 4 * 8 =
32`. Transaction rows have one mode, three results, and nine reasons, so their
bound is `1 * 3 * 9 = 27`. Pairing rules may reduce observed series but cannot
increase either bound. Payload IDs and transaction IDs remain log-only.

The controller/exporter boundary is implementable with scoped enums and total
mapping functions. Rejecting invalid enum values before increment prevents an
accidental `unknown`, empty, or caller-controlled label from expanding the
public taxonomy. This matches existing hybrid metrics practice, where public
series use `mode="hybrid"`, while tightening ownership for the new families.

## Regression check

The Part 8 correction does not alter the two-layer retention protocol, cold
transaction ordering, startup semantics, payload-versus-topology boundary, or
legacy behavior. Parts 1-3 still require demotion before capacity eviction,
retain descriptor tombstones and branch ownership, preserve hot bytes on
non-capacity failures, and exercise the real production save-pressure path.
No earlier closed finding reopened.

## Verdict

PASS. F39-AR3-01 is closed and the Stage 39 design is implementable without an
open runtime or observability choice. Stage 39 is ready for Manager design gate
review. Developer planning remains blocked until that gate passes.
