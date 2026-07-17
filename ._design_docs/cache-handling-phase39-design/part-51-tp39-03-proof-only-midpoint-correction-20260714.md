# Part 51: TP-39-03 proof-only midpoint correction

Date: 2026-07-14
Status: ARCHITECT PASS; MANAGER GATE NEXT
Scope: one proof-only midpoint smoke after D39-EXEC-24

## Schema correction

`cold_sets[]` is indexed by a discovered hot candidate. For each hot row,
snapshot construction copies that row's `payload_id` and `owner_entry_id` into
`incoming_payload_id` and `incoming_owner_entry_id`. Equality between the hot
row owner and cold-set key is required.

Only rows inside `cold_sets[].candidates[]` use the different-owner predicate:

```text
descriptor.residency == cold &&
descriptor.owner_entry_id != cold_set.incoming_owner_entry_id
```

The names describe the candidate that would enter pressure handling. They do
not identify the second chat request or its active owner. The second request
exists only to transfer the slot reference and expose the saved source as the
sole hot candidate.

No other cross-array owner rule exists. One owner may link one exact blob and
one checkpoint. `incoming_payload_id` selects the hot exact descriptor; proof
expands that descriptor through its owner links and must return the owner's
exact blob followed by checkpoint.

## Proof-only smoke

The corrected pure lifecycle set must first report exactly 12 passed and 29
deselected. Manager may then authorize one fresh `slot-release-midpoint` smoke
with the same model, command, two request bodies, budgets, caps, and stop rules
used by D39-EXEC-24.

The smoke may call only discovery, metrics, the read-only `proof` operation,
repeat discovery, and repeat proof after the two chat admissions. It must not
construct or send an apply request. No fault value, prepared session, cold
transaction, or pressure update is allowed.

Before proof, require:

- source and incoming HTTP status 200, in that order;
- node counts exactly 1 then 2;
- source discovery has no hot row or cold set;
- post-incoming discovery has one eligible hot exact row with positive
  resident bytes and zero slot references;
- exactly one cold set, keyed by that hot row's payload and owner, with no
  candidate;
- no cold file, decision event, or transaction event.

Proof requests only the hot exact payload ID. The captured response must have
exactly two rows in `exact_blob`, `checkpoint` order. Require distinct nonzero
payload and store IDs, one nonzero owner equal to the hot row owner, hot
residency, `target_and_draft`, runtime draft present and matching, positive
target and draft sizes, and `resident_component_bytes == resident_bytes ==
target_size_bytes + draft_size_bytes`. The endpoint's successful integrity
check binds owner links, store records, sizes, and target/draft checksums.

Repeat discovery and proof must be byte-equivalent after token redaction.
Parsed metrics must remain equal to the pre-proof capture. Preserve:

- command, model metadata, both request bodies and hashes, both responses;
- both lifecycle discoveries and metrics captures;
- `discovery.json`, `proof.json`, `metrics-before-apply.json`,
  `cold-inventory-before-apply.json`, both preflight files, server log,
  resource capture, and pytest output.

`preflight-result.json` must say `PASS`. Both preflight files must record two
requests, the 1-to-2 node transition, the source payload/owner, the two proof
payload IDs, zero pre-apply events, and no cold files. Tokens and HMAC material
stay redacted.

## Fixed stop and outcome

Success is the completed proof capture plus absence of `apply-request.json`,
`apply-response.json`, prepared-proof, terminal, and fault artifacts. Stop the
process there. Do not reuse it for a fault.

Any lifecycle, schema, pair, repeat-read, metric, capture, cap, or artifact
mismatch ends the gate. Do not tune prompts, budgets, waits, request count, or
assertions after the run.

This part supersedes Part 50 only for the post-D39-EXEC-24 proof-only
continuation. Part 50's lifecycle contract remains binding. Next owner:
Manager for one proof-only smoke gate. Fault execution, step 2, canonical
TP-39-03, coverage, full QA, product changes, build, commit, and push remain
blocked.
