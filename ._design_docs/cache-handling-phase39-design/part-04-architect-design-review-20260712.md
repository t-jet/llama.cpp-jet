# Part 4: Architect design review 2026-07-12

Verdict: PASS

## Review

The design resolves the directive without merging payload eviction with branch
pruning. It defines both layer-capacity predicates, admits and demotes before
discarding bytes, preserves target/draft atomicity, and separates capacity from
I/O and integrity failures.

Requirements R21, R37, R38, R38a-c, R55a, R57a-c, and R61/R65/R66/R66a/R67 are
covered. R57d-e remain explicitly deferred because Stage 39 does not add budget
interfaces or revise startup resource validation.

No blocking design findings remain.

## Implementation review focus

- Remove hot-over-budget demotion bypass without allowing unbounded hot growth.
- Require scratch planning and rollback for cold room-making.
- Prove production `tx_save` integration, not debug-helper equivalence.
- Verify actual cold bytes, ownership checks, and bounded metric labels.

Next gate: Manager design decision. Code remains blocked until Manager PASS.
