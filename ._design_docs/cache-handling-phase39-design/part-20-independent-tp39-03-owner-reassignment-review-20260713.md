# Part 20: independent TP-39-03 owner-reassignment review

Date: 2026-07-13
Status: REWORK REQUIRED
Review scope: design Part 19, implementation Part 60, and test-plan Part 43
under D39-EXEC-04

## Verdict

REWORK REQUIRED. The proposed tag and complete-set checks keep the seam narrow,
and the normal selector would return zero after a valid reassignment. Two
blocking gaps remain: the moved checkpoint is not proved compatible with its
new owner, and the driver plan does not define a workload that can create the
only collision-free cold inventory.

## Findings

### F39-ORR-01: checkpoint ownership can cross an incompatible entry boundary

Blocking.

The incoming hot candidate is an exact blob and therefore occupies the
destination exact link. Part 19 correctly rejects a cold exact-blob collision.
The only usable kind is a checkpoint whose destination checkpoint link is zero.
Parts 19, 60, and 43 check link shape, owner existence, kind, pair state, and
forest parity, but do not prove that the checkpoint belongs to the destination
entry's namespace, tokens, boundary metadata, or checkpoint span.

Changing `owner_entry_id` and the entry/forest checkpoint link can therefore
make a source checkpoint discoverable through an unrelated destination branch.
Later restore validation may reject it, but the guarded setup must not create
an invalid persistent owner-link state in the first place.

Required correction:

- Define a locked, non-mutating compatibility check for checkpoint reassignment.
- Require source and destination namespace compatibility.
- Validate the checkpoint descriptor, span, checksum, boundary metadata, pair
  state, and runtime draft shape against the destination entry before consuming
  the seam.
- Reject incompatibility with the fixed pre-consumption reason
  `invalid_tp39_03_owner_reassignment`.
- Add controller coverage for namespace, token-span, boundary, checksum, and
  target/draft incompatibility. Each rejection must leave generation, links,
  ownership, files, bytes, and one-shot state unchanged.

### F39-ORR-02: executable workload is not specified or shown reachable

Blocking.

Parts 60 and 43 tell the driver to select a compatible measured set, then stop
after one attempt if none exists. That is discovery, not a reachable workload.
The current script starts with `--ctx-size 2048`; the preserved Part 59 run says
checkpoint minimum spacing is 8192. Its discovery contains only exact blobs.
Every such cold candidate collides with the incoming owner's occupied exact
link and must be rejected.

A valid set is narrower than "nonempty": it must contain exactly one compatible
checkpoint, no cold exact blob, no second checkpoint, and the incoming owner
must have no checkpoint link. The plan does not explain how normal saves and
pressure produce that state while retaining the required hot and cold budget
inequalities.

Required correction:

- Specify one concrete model-backed request sequence, context size, checkpoint
  settings, and startup budgets that production paths can use to create the
  required owner-link shape.
- Explain how production pressure removes any cold exact sibling while leaving
  exactly one compatible cold checkpoint.
- Explain how the selected incoming owner remains hot with an empty checkpoint
  link and is compatible with that checkpoint.
- Add a pre-apply driver gate for the exact shape. Preserve discovery and stop
  after one measured attempt if the measured fixture differs, but do not call
  the row reachable until the planned workload produces the shape.
- Require saved discovery, owner-link evidence, checkpoint admission evidence,
  and the four budget inequalities before apply.

## Contract checks

| Check | Result |
| --- | --- |
| TP-39-03-only field and exact value | PASS |
| Complete selected cold set; no caller-supplied owner map | PASS |
| Destination collision and duplicate-kind rejection | PASS |
| No link overwrite or structural orphan | PASS, subject to F39-ORR-01 semantic ownership |
| Normal selector returns zero after complete reassignment | PASS by selector predicate |
| Normal `tx_update()` owns `evicted/both_filled` | PASS |
| Generation, rollback, terminal one-shot, and redaction contract | PASS at plan level |
| Executable model-backed reachability | REWORK per F39-ORR-02 |

The selector result follows directly from
`enumerate_cold_policy_candidates_core()`: it includes only cold descriptors
whose owner differs from the incoming owner. Reassigning the complete validated
set makes that set ineligible without changing production selection.

## Handoff

Verdict: REWORK REQUIRED.

Next owner: Developer, documentation correction only. Update Parts 19 and 60 to
close F39-ORR-01 and F39-ORR-02, then request fresh independent Architect
re-review. Code, tests, driver execution, build, and QA remain blocked pending
Architect PASS and a later Manager authorization.
