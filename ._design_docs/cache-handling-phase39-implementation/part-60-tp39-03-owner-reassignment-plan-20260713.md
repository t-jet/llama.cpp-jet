# Part 60: TP-39-03 owner-reassignment implementation plan

Date: 2026-07-13
Status: FOCUSED CONTRACT RETAINED; LIVE SETUP SUPERSEDED BY PART 70
Authority: D39-EXEC-04 and design Part 19

## Scope

Implement only the guarded TP-39-03 setup needed to make a complete discovered
cold set ineligible by normal incoming-owner exclusion. Do not change production
selection, eviction, metrics, logs, cold format, or public HTTP behavior.

## Planned changes

1. Extend the guarded request struct and strict route parser with
   `tp39_03_cold_owner_setup`. Accept only
   `selected_incoming_owner` on TP-39-03 apply. Reject absence, other values, or
   presence on discover, TP-39-02, or TP-39-04.
2. Replace TP-39-03's empty-selected-set check with design Part 19 validation.
   Rebuild and compare the complete snapshot first. Require a nonempty selected
   set and empty `desired_cold_ranks`.
3. Add a locked validation helper. Verify descriptor/map/store/byte integrity,
   live distinct owners, exact or checkpoint source links, entry/forest parity,
   zero active refs, one candidate per kind, and empty destination kind links.
   Return fixed `invalid_tp39_03_owner_reassignment` before consumption.
   For a checkpoint, validate against the destination without mutation: equal
   namespace, runtime target/draft mode, descriptor format/workload profile,
   cold header/store identity, target/draft size and checksums, ordered position
   span, equal source/destination tokens through the bounded checkpoint span,
   equal metadata compatibility and preparation IDs, and destination-resolved
   boundary native mode, kind, ID, end, and recomputed checksum. Reuse the
   restore pair and checkpoint-metadata predicates rather than a weaker copy.
4. Add a private rollback-record type under the compile guard. Capture exact
   descriptor owner, entry link/cache fields, and branch-node mirror fields for
   all affected owners before any mutation. Keep journal data local to apply.
5. Add one locked setup helper. After one-shot consumption, clear source links,
   set destination links, update descriptor owners, refresh entry accounting,
   and synchronize exact/checkpoint branch links. Route each write through the
   existing generation owner or a narrow setter that advances generation.
6. On injected or natural pre-pressure failure, replay the journal in reverse.
   Advance generation for every restored field, rerun integrity validation, and
   compare the pure state with the saved pre-setup snapshot. Do not call
   `tx_update()` when rollback or comparison fails.
7. On success, call one unchanged `tx_update()`. Assert internally in guarded
   builds that the normal cold core returns zero for the incoming owner before
   dispatch; do not bypass or replace that core.
8. Extend terminal response construction with bounded owner-link before/after
   evidence. Keep snapshot token, nonce, journal, paths, prompt/token content,
   payload bytes, and admin token out of all responses and logs.
9. Add controller tests for strict scope, complete-set checks, exact-link and
   duplicate-kind collisions, link/integrity/reference drift, successful
   checkpoint reassignment, every rollback position, generation behavior,
   normal zero-candidate selection, `both_filled`, zero cold transactions,
   topology retention, and byte/file reconciliation. Add one pre-consumption
   negative per compatibility field family: namespace, pair mode, sizes and
   checksums, token/span, position span, compatibility/preparation identity,
   boundary metadata, workload profile, and cold header/store identity. Each
   must preserve generation, ownership, links, files, bytes, and one-shot state.
10. Extend the guarded Python route suite with schema isolation, retryable
    pre-consumption rejection, terminal rollback, success evidence, and leak
    scans. Preserve all existing 13 route tests.
11. Update `stage39-two-layer-pressure.ps1` with Parts 62, 68, and 69's literal
    scenario: Qwen3.5-4B MTP, one slot, context 8192, 166 MiB hot and 2048 MiB
    cold measurement bootstrap, checkpoint max 32 and spacing 0, exact
    ten-message bodies, and two fixed repeat fillers.
    Assert content lengths, compact JSON order, SHA-256 values, token counts
    3,631 and 3,632, coexistence sum 7,263, minimum margin 929, and fixed caps.
    Preserve startup proof that bounded partial removal maps to RS. Measurement
    need not contain a compatible cold set, but Part 27 requires normal
    production demotion, target-only runtime proof, real final cold files, and
    header/descriptor/file reconciliation. Canonical uses Parts 25 and 27's
    checked startup-budget formula and discovers after source then incoming,
    before fillers.
12. Before apply, require discovery to contain exactly one compatible cold
    checkpoint, no exact sibling or second checkpoint, and a hot incoming exact
    owner with an empty checkpoint link. Require all four budget inequalities.
    A mismatch is `SKIP-preflight-<fixed-reason>` before apply; never consume
    the seam, change literal text, synthesize inventory, or relax selection.
13. Run seam-OFF and seam-ON Release builds, the full controller suite, route
    suite, PowerShell 5 and 7 self-tests, and exact measurement then fresh
    canonical TP-39-03 passes. Measurement sends no apply or guarded owner
    reassignment. Restart with a fresh cold root and measured integer MiB
    startup budgets for canonical execution.
    Preserve requests, responses, metrics, logs, inventories, files, generations,
    and owner-link evidence. Enforce 20 minutes, 16 GiB RSS, 4 GiB cold-root,
    and six chat requests per pass. Keep the 166/2048 MiB measurement bootstrap.
    Fail before canonical launch or apply if runtime pair, production demotion,
    immutable file/header, descriptor-size, or reconciliation proof is missing.
    Coverage remains a separate QA closure gate.

## Required mutation order

All steps run under admission then cache lock:

1. pure snapshot, token, exact-set, integrity, collision, and budget validation;
2. journal capture and `before_generation`;
3. terminal one-shot consumption and generation advance;
4. source-link clears, destination-link writes, descriptor-owner writes, then
   entry-accounting and forest-mirror writes, each generation-owned;
5. post-setup integrity check and normal-selector zero-candidate assertion;
6. one normal `tx_update()`;
7. recomputed after snapshot, owner-link audit, and `after_generation`.

Pre-pressure failure restores writes in reverse order and verifies the exact
pre-setup state. Post-consumption failure stays terminal. The wrapper performs
no payload, cold-file, metric, decision, or transaction compensation.

## Acceptance

- TP-39-03 apply cannot name a subset or arbitrary owner mapping.
- No collision overwrites an incoming exact/checkpoint link or orphans a source.
- Entry, descriptor, and forest ownership agree before pressure and after any
  rollback.
- Generation invalidates the original snapshot on consumption, every owner/link
  write, and every rollback write.
- Normal production selection sees zero eligible cold victims and normal
  pressure emits exactly one `evicted/both_filled` with no cold transaction.
- Responses provide bounded before/after proof without leaking security material
  or cache content.
- TP-39-02, TP-39-04, discovery purity, public semantics, and normal production
  behavior remain unchanged.
- Normal selector and restore behavior remain unchanged; compatibility failure
  is retryable and pre-consumption.

## Gate

Independent Architect review is next. Manager implementation authorization is
required after PASS. No code, tests, driver, build, or QA run is authorized by
this plan.
