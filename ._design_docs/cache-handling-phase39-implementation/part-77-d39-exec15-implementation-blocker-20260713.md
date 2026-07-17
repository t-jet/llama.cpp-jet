# Part 77: D39-EXEC-15 implementation blocker

Date: 2026-07-13
Status: BLOCKED BEFORE CODE CHANGE
Authority: D39-EXEC-15 and design Parts 39-40

## Finding

D39-EXEC-15 cannot be implemented against the current production order without
violating its read-only post-exact boundary.

`tx_demote_payload()` commits the exact descriptor, removes its hot record,
updates cold accounting, and calls `refresh_entry_payload_accounting()` for
each entry at `server-cache-hybrid.cpp:5345`. It does not call
`sync_branch_node_from_entry()`.

`mark_payload_kind_evicted()` calls `tx_demote_payload()` at line 3918. On
success it refreshes the entry again and returns at lines 3919-3920. The next
call in `mark_payload_evicted()` is the checkpoint kind at line 3952. Branch
sync occurs only after both kind calls at lines 3953-3956.

After exact demotion returns, entry accounting therefore projects only the hot
checkpoint bytes while the branch still projects the earlier hot exact plus
checkpoint aggregate. Design Part 39 requires those values to match before
step 2, and forbids the boundary hook from refreshing or syncing them. Its
validator must abort every otherwise valid natural same-owner run.

Design Part 40 states that successful demotion already syncs the branch before
the hook. Current code does not provide that ordering. Adding a sync to the
guarded hook, kind wrapper, or demotion path would add the mutation that
D39-EXEC-14 and D39-EXEC-15 explicitly prohibit or would change seam-OFF
production behavior.

## Work stopped

No product, route, driver, or test source was changed. No build or test ran.
The prepared-size proof, session and abort plumbing, generation advance, and
named tests remain unimplemented.

Architect must correct the approved boundary against the current production
order and obtain fresh independent review before Developer resumes. The
correction must state where branch synchronization is owned and whether that
owner may mutate state without weakening seam-OFF equivalence.
