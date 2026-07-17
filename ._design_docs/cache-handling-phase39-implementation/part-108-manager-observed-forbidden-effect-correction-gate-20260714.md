# Part 108: Manager observed forbidden-effect correction gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-27

Architect Part 107 accepts the D39-EXEC-26 terminal structure but finds seven
claimed forbidden-effect deltas are literal zeros. Design Part 53 owns the
bounded observational correction.

Developer may add seam-only observations at the existing production
boundaries for checkpoint classification, publish, committed cold completion,
cold inventory, full descriptor and entry-link mutation, and explicit guarded
generation advance. Every reported delta must derive from an event counter or
pre-apply/terminal comparison. Changed-then-restored effects require an event
count. Product control flow, routes, metrics, fixture, and budgets must not
change.

Add controller-only negative probes that make every observed delta nonzero and
prove the common matrix rejects it. Preserve all D39-EXEC-26 pure shape,
midpoint, step-2, HMAC retrieval, and tamper checks.

Developer may reuse the seam build directory for one incremental
controller/server build, then run pure negatives and both controller faults.
Stop at the first failed layer and record exact evidence in one implementation
part.

Model route nodes, default build, fixture or budget changes, canonical
TP-39-03, coverage, full QA, commit, push, PR, and reviewer responses remain
blocked. Fresh Architect review must pass before route execution.
