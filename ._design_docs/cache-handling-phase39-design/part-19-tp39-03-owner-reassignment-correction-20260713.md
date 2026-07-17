# Part 19: TP-39-03 owner-reassignment correction

Date: 2026-07-13
Status: FOCUSED CONTRACT RETAINED; LIVE SETUP SUPERSEDED BY DESIGN PART 29
Scope: guarded TP-39-03 apply setup only; production policy is unchanged

## Manager decision

D39-EXEC-04 is the authority for this correction:

> TP39-03-only guarded apply may reassign complete discovered cold set to selected incoming owner, with integrity checks, generation ownership, atomic rollback, before/after evidence; normal selector must see zero eligible victims and produce both_filled; no public semantics.

Part 59 proved the prior empty-set precondition unreachable. Its measured cold
descriptor remained eligible because production excludes only descriptors whose
`owner_entry_id` equals the incoming descriptor owner. This correction creates
that state through guarded setup, then calls the unchanged `tx_update()` path.

## Strict request extension

Only `apply` with `scenario: "tp39-03"` accepts this field:

```json
{
  "tp39_03_cold_owner_setup": "selected_incoming_owner"
}
```

The field is required for TP-39-03 and forbidden for `discover`, TP-39-02, and
TP-39-04. No other value is valid. The selected `cold_sets` row remains the
authority for payload identity; the request cannot supply a partial owner map.
The selected set must be nonempty. `desired_cold_ranks` must be empty for this
scenario because rank cannot create the required no-victim state.

Schema, snapshot, inventory, budget, incoming-row, and hot-order validation from
Part 15 runs first. A schema or validation failure is retryable, does not consume
the seam, and does not change generation or cache state.

## Complete-set and integrity validation

While holding the completion-admission latch and `cache_state_mutex_`, apply
rebuilds the pure snapshot and performs these checks before consumption:

1. The requested hot inventory and every per-incoming cold set exactly equal the
   current token-bound snapshot. The selected set matches incoming payload and
   owner IDs and contains every descriptor returned by
   `enumerate_cold_policy_candidates_core(incoming_owner_entry_id)`.
2. Candidate payload IDs are nonzero and unique. Each map key equals descriptor
   payload ID. Every candidate is cold, has a recognized kind and pair state,
   has a matching store ID and byte-map entry, and contributes to exact cold
   accounting.
3. Incoming and source owners exist and differ. Each source kind-specific link
   equals the candidate ID: `payload_id` for `exact_blob`,
   `checkpoint_payload_id` for `checkpoint`.
4. The incoming owner's link for each candidate kind is zero. At most one
   candidate of each kind may move. Any occupied destination link, duplicate
   kind, missing source link, source/destination alias, or forest-link mismatch
   returns `invalid_tp39_03_owner_reassignment` before consumption.
5. Source and destination entries have no active slot references. Their branch
   nodes exist, and their entry and forest kind-specific links agree. Protection,
   topology, payload IDs, residency, ranks, byte maps, files, and budgets remain
   unchanged by reassignment.

Before consumption, a locked, non-mutating checkpoint compatibility helper
must validate the candidate as if the destination already owned it. Source and
destination `namespace_id` values must match. The descriptor must have the
runtime pair mode, supported format and workload profile, valid target/draft
sizes and checksums, and a matching immutable cold-object header and store ID.
Its token span must be positive, within both entries, and byte-for-byte equal in
the source and destination token vectors. Its position span must be ordered.
The destination metadata must have the same nonempty `compatibility_key` and
`preparation_id` as the source metadata. Required boundary native mode, kind,
ID, token end, and checksum must resolve in the destination metadata, and the
checksum recomputed over the destination token span must equal the descriptor
checksum. The helper then runs the same checkpoint metadata and pair-shape
predicates used by restore, without promotion, counter, rank, or sequence
mutation. Any mismatch returns `invalid_tp39_03_owner_reassignment` before
one-shot consumption.

The destination-link rule is deliberate. An incoming exact blob already owns
the incoming owner's exact link, so a cold exact blob collides and is rejected.
A compatible discovered set therefore uses only an unoccupied kind slot, such
as one checkpoint descriptor when the incoming owner has no checkpoint. The
driver must select a compatible measured workload; the seam must not overwrite
or orphan a payload to force reachability.

## Atomic setup and rollback

After all validation succeeds, apply records `before_generation` and an exact
rollback journal for every field it may change:

- descriptor owner IDs;
- source and destination entry links for each payload kind;
- affected entry cached payload bytes and target/draft flags;
- affected branch-node exact/checkpoint links, resident-byte fields, payload
  flags, residency, and order fields.

The seam changes `ready` to `consumed` and advances generation before the first
owner write. Under the same cache lock it clears each source link, assigns the
destination link, changes the descriptor owner to the selected incoming owner,
then refreshes affected entry accounting and branch-node mirrors. Every changed
field advances the process generation through the Part 15 owner. Payload IDs,
cold files, cold byte accounting, ranks, budgets, topology edges, metrics, and
production decision counters do not change during setup.

Any failure before `tx_update()` restores journal entries in strict reverse
write order. Every restored field advances generation again. After rollback,
the full integrity validator and pure snapshot must equal the pre-setup state
except for generation and terminal one-shot state. Rollback failure returns
`terminal_owner_reassignment_rollback_failure`; it never starts pressure. All
failures after consumption are terminal.

After successful setup, apply invokes one normal `tx_update()`. The incoming
descriptor still names the selected incoming owner. Because every descriptor in
the complete pre-setup cold set now names that same owner, the unchanged
production cold selector returns zero candidates. When occupied cold bytes plus
the prepared incoming size exceed the lowered positive cold budget, normal
demotion fails with `both_filled`; ordinary hot-pressure handling emits exactly
one `evicted/both_filled` final decision. No cold transaction starts.

## Evidence and redaction

The terminal response keeps Part 15 `before_generation`, `after_generation`,
and recomputed `before` and `after` inventories. It adds a bounded
`tp39_03_owner_reassignment` object with `mode`, `candidate_count`, `applied`,
`rolled_back`, and before/after rows limited to payload ID, kind, source owner,
current owner, and kind-specific link ID. This object is response evidence only.

The response never echoes `snapshot_token` or the process nonce. Errors contain
only fixed reason strings. No path, store reference, prompt, token sequence,
payload bytes, rollback journal, admin token, or HMAC input enters responses,
logs, or metrics. Setup emits no new production metric or decision row. Existing
guarded-route authentication, compile/runtime OFF behavior, loopback restriction,
single-model hybrid restriction, idle admission, positive startup budgets,
constant-time token checks, and terminal one-shot rules remain binding.

## Required verification

Controller and route coverage must include:

- strict field acceptance only for TP-39-03 apply;
- complete nonempty set acceptance and omitted/extra row rejection;
- exact-link collision, duplicate-kind, wrong source link, forest-link drift,
  active-reference, and integrity failures before consumption;
- successful checkpoint owner reassignment with entry/forest link parity;
- pre-consumption rejection for namespace, runtime pair mode, target/draft
  checksum or size, token/span, position span, metadata compatibility key,
  preparation ID, boundary kind/ID/end/checksum, workload profile, and cold
  header/store incompatibility; every rejection preserves generation,
  ownership, links, files, bytes, ranks, counters, and one-shot state;
- injected failure after each owner/link/accounting write, exact reverse rollback,
  generation advance, terminal consumption, and zero pressure start;
- response and error redaction, including absence of snapshot/admin tokens,
  nonce, paths, payload content, and rollback journal;
- normal selector result of zero after setup, exactly one
  `evicted/both_filled`, zero cold-transaction-family delta, retained entry and
  branch counts, zero pruning, and reconciled bytes/files.

Implementation Parts 62, 68, and 69 define the literal canonical workload. It
uses the local Qwen3.5-4B MTP fixture, one slot, context 8192, a 166 MiB hot and
2048 MiB cold measurement bootstrap, 32 checkpoints, and minimum spacing 0.
Metadata and existing startup logs prove capability, not a new runtime result.

Part 64 measured 3,631 source tokens and 3,632 incoming tokens. Their required
coexistence consumes 7,263 of the 8,192-token controller limit and leaves a
929-token margin. Preflight must recompute both counts and their checked sum
from saved bodies. It fails before apply if either count changes, the sum
exceeds 8,192, or the margin is below 929. Startup must still prove bounded
partial sequence removal mapped to RS and real checkpoint creation.

Before apply, one discovery snapshot must prove a real compatible cold
checkpoint and a hot incoming exact owner with an empty checkpoint link. The
checkpoint span ends before the fixed suffix difference and passes every
compatibility predicate above. Exact inventory, four budget inequalities,
generation, and HMAC token must match. Missing facts or cap breaches yield
`SKIP-preflight-<fixed-reason>` before apply. Preserve evidence; do not change
the literal workload, synthesize inventory, or weaken selection. Part 62 fixes
an exact measurement pass followed by a fresh-process, fresh-cold-root canonical
pass. Measurement cannot send apply. Under D39-EXEC-08 and design Part 27 it
must prove target-only runtime completeness and use normal production pressure
to create real cold objects. Canonical execution cannot reuse its generation,
token, identities, inventories, files, or budgets. Each pass is capped at 20
minutes, 16 GiB RSS, 4 GiB cold-root bytes, and six chat completions. Parts 25
and 27 derive canonical startup budgets only from reconciled resident and
immutable serialized complete-pair sizes. Missing runtime, demotion, file,
header, descriptor-size, or reconciliation proof fails before apply. Source
then incoming admission must create the cold candidate before discovery.
Driver exit alone cannot pass TP-39-03.

## Boundaries and handoff

Design Part 29 keeps this owner-reassignment contract for focused evidence but
replaces its unreachable model-backed precursor with natural same-owner,
exact-before-checkpoint production pressure.

This correction does not change discovery, the production selector predicate,
room-making order, reason taxonomy, metrics, cold format, restore behavior,
legacy mode, or any public request/response schema. It adds no general ownership
API. Part 60 is the implementation plan. Independent Architect review must PASS,
then Manager must authorize implementation. No code or test work is authorized
by this document.
