# Part 98: Architect D39-EXEC-23 inventory review

Date: 2026-07-14
Verdict: REWORK; DESIGN PART 50 PASS
Scope: Parts 45-49, 62, 69, 83-97, production discovery, and exec23 evidence

## Evidence verdict

D39-EXEC-23 passed its diagnostic gate. The capture files are valid and show
one branch node, 2048 MiB hot and cold budgets, empty hot and cold inventories,
and no decision or transaction rows. No proof or apply artifact exists.

The empty inventory is expected active-slot state caused by the one-request
fixture timing. It is not protected-root behavior, a seam selection defect, or
a product defect.

## Predicate and ownership trace

Source admission saves one entry with an exact descriptor and the latest real
checkpoint descriptor. Both descriptors keep that entry as owner; branch sync
copies both links and the resident target/draft state. Admission adds the entry
to LRU and prefix indexes, then acquires its branch reference for slot 0.

HTTP completion calls `server_slot::release()`. Its `reset()` retains prompt
tokens and `hybrid_cache_branch_node_id`. The branch reference is released only
by `prompt_clear()` or when another admitted entry replaces the slot link.

Discovery validates descriptor IDs, owners, kinds, pair states, links, cold
files, and cold accounting first. It then asks the forest for payload eviction
candidates. The forest rejects nodes with an active slot reference, no payload
links, zero resident bytes, or no target/draft state. Exec23's saved node has
the latter three requirements and fails only the active-reference predicate.
Protection changes ordering but does not exclude it. Owner lookup, LRU lookup,
exact-link, and hot-residency checks therefore receive no node. No hot row also
means no per-incoming cold set.

This explains every observed family without inventing unrecorded row values.

## Reachability and correction

Natural same-owner state is reachable with approved public requests. Design
Part 50 adds Part 62's incoming request after source. The second normal
completion transfers the one slot reference to its distinct owner, leaving
the source node eligible. Source proof then expands its exact ID to the source
checkpoint ID. No synthetic setup or owner reassignment is needed.

Current route implementation remains REWORK because it sends only source and
asserts eligibility while source is still active. Part 50 is the complete
correction. Manager must gate pure mocked lifecycle tests before one midpoint
smoke. That smoke captures both the pinned one-node state and the released
two-node state, then stops before apply. Only a passing smoke may reopen the
two fault nodes.

## Process review

Part 83's process finding is confirmed. Stage 39 needed extra work because
transaction, fault, generation, and two-kind ownership boundaries are real.
Most turns came from approving model and route assumptions before tracing slot
lifecycle, reviewing coupled predicates one at a time, and learning fixture
facts during expensive model runs.

Apply Part 83 now: keep one current executable contract capsule, require pure
helper lifecycle tests before model use, capture each ownership transition,
and review the whole admission-to-selection boundary in one gate. If the
corrected two-request smoke still cannot expose the source candidate, classify
it structural and stop. More prompt, wait, or budget calibration is forbidden.

## Supersession and next gate

This review supersedes Part 95's unclassified inventory finding and Part 97's
Architect-review-next handoff. It does not supersede exec23 evidence. Design
Part 50 supersedes only Part 45's one-request workload and cap.

Next owner: Manager. Next gate: authorize helper-only two-request correction,
its pure tests, and one no-apply midpoint smoke. Step 2, fault apply, canonical
TP-39-03, coverage, full QA, product changes, build, commit, and push remain
blocked.
