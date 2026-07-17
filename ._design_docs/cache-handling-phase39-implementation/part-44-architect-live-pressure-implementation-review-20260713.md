VERDICT: REWORK

# Part 44: Architect live-pressure implementation review

Date: 2026-07-13
Scope: D39-EXEC-01/02, design Part 11, implementation Parts 39-43,
design review Part 14, and report 20260713-01 fixes

## Reviewed state

Default-OFF CMake guarding, runtime opt-in checks, loopback and token guards,
completion admission locking, strict request parsing, terminal consumption,
normal `tx_update()` handoff, and the coverage merge correction are present.
The on-disk ON Release controller and server builds passed. The OFF
`server-context` build passed. The Release controller executable also passed
during this review. Startup rejection and the literal exit-23 fixture are on
disk. These checks support the implemented subset, not the full gate.

## Blocking findings

### F39-LPIR-01: no usable pre-mutation identity source

The first valid POST requires exact live payload and owner IDs. Current public
metrics expose neither. Cold filenames can expose some payload IDs but not live
owners or the complete hot set. Existing logs expose selected payload IDs but
are not a stable, complete owner inventory. No existing artifact can construct
and prove the required request without guessing.

This needs a design correction. Keep the one guarded route, but make its strict
schema a tagged operation:

- `discover`: token-protected, idle-only, non-mutating, retryable, and
  non-consuming. Under admission then cache-state lock, return separate complete
  hot and cold sets with payload ID, owner ID, kind, residency, eligibility,
  resident bytes, serialized bytes when known, and current rank/order.
- `apply`: carry the current scenario, budget, hot-order, and cold-rank fields.
  Recompute both sets under the same locks and reject any stale, missing, or
  extra identity before consumption.

Discovery must return no path, token, prompt, or payload bytes. Existing
compile/runtime guards, loopback restriction, one-shot mutation rule, and
redaction stay unchanged. This is a schema and response contract change, so
Developer cannot add it under D39-EXEC-02 without corrected design and Manager
approval.

### F39-LPIR-02: cold exact-set validation differs from production

`stage39_apply_live_pressure()` builds `eligible_cold` only from
`exact_blob` descriptors with a currently attached owner. Production cold
room-making at `server-cache-hybrid.cpp:4974` considers every cold descriptor
except the incoming owner, including checkpoint descriptors. An unlisted cold
checkpoint can therefore pass seam validation and still become a production
victim. This violates Part 11's complete production-selector set rule.

Use one shared production predicate or candidate builder for discovery,
validation, and cold room-making. Add mixed exact/checkpoint and omitted-victim
tests.

### F39-LPIR-03: response evidence does not match Part 11

The controller returns one combined `before` array and one combined `after`
array. It does not return separately recomputed hot and cold sets. Its
`eligible` field uses sets computed before pressure, so an evicted after-row can
still report eligible. Part 11 requires separate complete sets and current
before/after eligibility.

Return separate hot and cold snapshots and recompute the after snapshot from
live production predicates.

### F39-LPIR-04: required implementation and evidence are missing

Only `test_stage39_live_pressure_control_validation` exists. Parts 11 and 39
also require TP-39-02/03/04 controller tests, idle-dispatch race coverage,
pre/post-pressure failure and restoration coverage, and route OFF/runtime-OFF,
startup, token/schema, retry, redaction, terminal, and success tests. The named
Python route file does not exist. The canonical live driver has no control-route
flow or control artifacts. Full PowerShell 5/7 success and forced-failure
coverage trees, the 80 percent result, and model-backed smoke remain absent.

Implement every named test and driver assertion after F39-LPIR-01 design
approval. Do not send this gate to QA until route success, live smoke, and
coverage evidence exist.

## Non-blocking note

The approved `whoami.exe` tail and immediate nonzero merge throw match Part 11.
Full canonical coverage remains QA-bound evidence, but implementation must first
produce the executable success and failure probes required by Part 39.

## Handoff

REWORK. Next owner: Architect for the narrow discovery design correction, then
Manager for a new correction-plan decision. Developer follows only after that
gate. QA remains blocked.
