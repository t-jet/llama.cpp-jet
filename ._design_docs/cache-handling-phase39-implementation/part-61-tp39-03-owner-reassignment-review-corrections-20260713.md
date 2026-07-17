# Part 61: TP-39-03 owner-reassignment review corrections

Date: 2026-07-13
Status: READY FOR FRESH INDEPENDENT ARCHITECT REVIEW
Scope: documentation correction for F39-ORR-01 and F39-ORR-02

## Corrections

F39-ORR-01 is addressed in design Part 19, implementation Part 60, and test-plan
Part 43. Checkpoint reassignment now requires a locked, non-mutating destination
compatibility check before one-shot consumption. It covers namespace, runtime
pair mode, descriptor and cold-object integrity, token and position spans,
target/draft checksums, metadata compatibility and preparation identity,
boundary metadata, and the predicates used by restore. Any mismatch returns
`invalid_tp39_03_owner_reassignment` without changing generation or cache state.

F39-ORR-02 is superseded by implementation Part 62. It names the verified local
Qwen3.5-4B MTP fixture, GGUF architecture/context/NextN metadata, and existing
startup capability evidence. Part 65 corrects context to 8192 after Part 64
measured 3,631 plus 3,632 tokens and proved context 4096 cannot retain both
owners. It keeps 2048 MiB positive startup
budgets, checkpoint flags, literal ten-message bodies, exact roles,
repetitions, lengths, JSON order, generation parameters, and repeat fillers.
No new runtime proof is claimed.

Each of the two passes is capped at 20 minutes, 16 GiB RSS, 4 GiB cold-root
bytes, and six chat requests. Before apply, one snapshot must prove a compatible
cold checkpoint and a hot incoming exact owner with an empty checkpoint link.
Missing facts or cap breaches yield `SKIP-preflight-<fixed-reason>`; apply is
not sent.

## Test updates

Controller and route plans add pre-consumption negatives for every compatibility
field family and require exact unchanged-state proof. Live assertions require
checkpoint admission, saved discovery and owner links, all four budget
inequalities, exactly one compatible checkpoint before apply, zero eligible
victims after reassignment, one normal `evicted/both_filled`, and zero cold
transaction delta.

## Handoff

Fresh independent Architect review of Parts 19, 60-62, and 43 is next.
Code, tests, driver execution, build, coverage, and QA remain blocked until
Architect PASS and later Manager authorization.
