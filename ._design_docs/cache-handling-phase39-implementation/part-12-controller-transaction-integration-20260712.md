# Part 12: controller transaction integration

Date: 2026-07-12
Status: PARTIAL

## Scope

This tranche integrates Stage 39 cold transaction primitives into production
hot-pressure demotion. It also adds startup ownership reconstruction and cleanup
debt accounting. Stage 39 remains open.

## Production flow

`tx_demote_payload()` now prepares and validates the complete serialized object
before cold capacity planning. Planning uses its exact file size, current cold
bytes, quarantine debt, deterministic descriptor recency, and payload ID as the
tie-breaker.

When room is needed, the controller writes a manifest containing incoming and
victim descriptor images before it quarantines any victim. It then quarantines
selected files, publishes the incoming file, persists the published state, and
writes the commit marker. Descriptor tombstones, cold accounting, incoming
descriptor residency, and hot release happen only after the durable commit
marker. Cleanup runs after the state apply. Failed cleanup remains charged as
quarantine debt.

Failures before the commit marker invoke store recovery. Recovery removes the
incoming staging or final file and restores quarantined victims. A corrupt or
unrecoverable manifest disables further cold mutation.

## Startup

Controller construction runs transaction recovery before ordinary orphan
reconciliation. Committed incoming descriptor ownership, exact/checkpoint kind,
pair state, boundary fields, and per-ID bytes are reconstructed without relying
on the prior controller. Victim rows become evicted tombstones when already
present. Committed quarantine cleanup is retried before cold mutation proceeds.

## Evidence

- Release `test-cache-controller` and `llama-server` builds: PASS.
- Release controller executable: PASS.
- `ctest --test-dir build -C Release -R cache --output-on-failure`: 1/1 PASS.

## Remaining work

- Add fault hooks at every TP-39-14 boundary and fresh-controller restart tests.
- Reject reconstruction conflicts and missing-owner cases with claimed-path
  protection instead of accepting all valid committed records.
- Add Stage 39 typed decision and transaction metrics and fixed log rows.
- Add live production-save, exact-size boundary, cardinality, and coverage
  evidence.
