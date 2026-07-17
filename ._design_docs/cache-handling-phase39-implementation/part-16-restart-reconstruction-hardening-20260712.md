# Part 16: restart reconstruction hardening

Date: 2026-07-12
Status: PARTIAL

## Changes

Committed recovery now validates payload kind, owner link, nonzero owner ID,
owner-link uniqueness, descriptor conflicts, and incoming final-file presence
before changing controller state. An invalid record preserves transaction files,
disables cold mutation, and skips ordinary orphan reconciliation.

Fresh reconstruction now installs incoming owner claims and victim tombstones,
uses the durable post-transaction byte total, and derives cold count from the
per-ID map. Cleanup has separate test seams for each victim unlink and manifest
unlink.

## Verification

- Release `test-cache-controller` build and executable: PASS.
- Release `llama-server` build: PASS.
- Cache ctest: PASS, 1/1.
- Stage 39 PowerShell parser check: PASS.

## Open production gap

TP-39-14 is not complete. A committed manifest is removed after first successful
recovery. A second fresh controller then has no durable ownership record, so
ordinary reconciliation can delete incoming cold file as an orphan. Implementation
needs a persistent ownership journal, or equivalent claim record whose lifecycle
follows payload eviction, before destroy/reconstruct idempotence can pass safely.

Descriptor-apply injection and full pre/post-commit, multi-victim-position,
conflict, missing-owner, and claimed-path matrix remain open. Implementation is
not ready for Architect review or QA execution.
