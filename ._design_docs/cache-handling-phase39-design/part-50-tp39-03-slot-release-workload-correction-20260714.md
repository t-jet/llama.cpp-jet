# Part 50: TP-39-03 slot-release workload correction

Date: 2026-07-14
Status: ARCHITECT PASS; MANAGER GATE NEXT
Scope: D39-EXEC-23 inventory classification and route workload only

## Classification

The exec23 empty inventory is expected active-slot state. It exposes a fixture
timing error, not a protected-root exclusion, selector seam bug, or product
bug.

The source response completed successfully and saved one 243.620 MiB entry
with real checkpoints and positive target and draft components. Save created
the entry, exact and checkpoint descriptors, one branch node, LRU membership,
and a slot reference to that node. `server_slot::release()` calls `reset()` but
does not clear the prompt or release that reference. Only `prompt_clear()`
releases it.

Discovery uses `payload_eviction_candidates()`. It excludes a node when any of
these predicates holds:

1. `slot_ref_count > 0`;
2. both payload links are zero;
3. resident payload bytes are zero;
4. both target and draft state flags are false.

The saved node has payload links, positive resident bytes, and target/draft
state. It is excluded by predicate 1. Protected roots are not excluded; they
are ordered after unprotected candidates. Later entry, LRU, exact-link, and hot
residency filters never receive this node. The captured one-node forest and
empty decision, transaction, cold, and candidate families match that trace.

## Reachable public transition

The natural same-owner exact and checkpoint state is reachable without debug
setup, synthetic descriptors, owner reassignment, or a product change. Use the
two already approved Part 62 public requests in this order:

1. Send the existing source request and wait for HTTP 200 and idle save.
2. Send the Part 62 incoming request through `/v1/chat/completions`.
3. Wait for HTTP 200, completion save, and idle state.
4. Discover before any third completion.

The incoming request keeps the same ordered messages and changes only the
final suffix. Slot assignment restores or clears the old prompt through the
normal hybrid path. Completion save admits a distinct incoming owner and
moves the sole slot reference to it. The source node then has zero references
and becomes the one hot discovery candidate. Its exact and checkpoint links
remain on the same source owner. The incoming node remains active and is
correctly absent from discovery.

Use Part 62's incoming body exactly:

```text
suffix: "suffix-incoming|"
max_tokens: 1
compact JSON bytes: 5688
SHA-256: a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b
message lengths: 250,707,355,835,355,643,419,643,355,723
```

All other body fields and serialization rules stay equal to Part 45. The chat
cap becomes two requests per node. No filler or third completion is allowed.
Context 8192 and the 2048 MiB hot and cold budgets remain unchanged.

## Cheap gate before model execution

Add pure helper tests that use mocked HTTP and control responses. They must run
without a server, model, build, network, route seam, or cold root and prove:

1. source and incoming bytes, lengths, hashes, property order, suffixes, and
   `max_tokens` values match the constants above and Part 45;
2. `admit_pair()` sends exactly source then incoming and waits for HTTP 200 and
   idle discovery after each;
3. post-source capture accepts `total_nodes=1`, empty hot/cold inventory, and
   no decision or transaction rows as the expected pinned-source state;
4. post-incoming capture requires `total_nodes=2`, exactly one hot source exact
   row, one cold set with no candidates, and no decision or transaction rows;
5. any wrong order, extra completion, nonempty cold state, owner drift, missing
   row, or premature apply fails before proof.

Keep the existing pre-validation capture. Add
`discovery-after-source.json` and `metrics-after-source.json` immediately after
the source idle discovery. Keep `discovery-before-validation.json` and
`metrics-before-validation.json` for the post-incoming state. Write a
`slot-release-preflight.json` containing request count, both response codes,
both node counts, source candidate ID and owner, and zero pre-apply event
totals. Capture failures remain fail closed.

## Model rerun gate

After pure tests pass and Manager authorizes the correction, run midpoint only
from a fresh process and root. Stop before apply after the post-incoming proof
and capture. Acceptance requires:

- two HTTP 200 admissions and exactly two branch nodes;
- post-source zero candidates;
- post-incoming exactly one eligible hot source exact row;
- proof rows exactly `exact_blob`, then `checkpoint`, with one source owner,
  hot residency, positive target/draft and resident component sizes, and
  distinct IDs;
- server log reports two entries while discovery exposes only the released
  source, consistent with the incoming entry owning the active slot reference;
- no cold files, decisions, transactions, apply request, or one-shot use.

Only that smoke may reopen the exact midpoint and step-2 rerun. A repeated
empty post-incoming inventory or owner mismatch is `BLOCKED-structural` under
Part 83. Do not tune prompt lengths, budgets, waits, or request count after that
result.

## Supersession and handoff

This part supersedes Part 45's one-admission claim and its one-chat cap. Parts
46-49 remain binding for startup, trace, parsing, capture, caps, and stop
behavior. Part 97 remains valid evidence of the pinned-source state.

Architect verdict: PASS for this narrow workload and evidence correction.
Next owner: Manager for a helper-only correction, pure-test, and midpoint smoke
gate. Product code, route schema, full route rerun, canonical TP-39-03,
coverage, full QA, build, commit, and push remain blocked.
