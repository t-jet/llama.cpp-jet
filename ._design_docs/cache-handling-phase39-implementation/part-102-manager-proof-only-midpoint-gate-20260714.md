# Part 102: Manager proof-only midpoint gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-25

Design Part 51 and Architect Part 101 accept the two-request lifecycle and
correct the cold-set key semantics. D39-EXEC-25 authorizes one proof-only
midpoint smoke.

Developer may use the corrected cold-set assertion and run one fresh midpoint
process/root. It must capture the one-to-two node lifecycle, selected source
row, matching cold-set key, exact/checkpoint proof rows, repeated discovery and
proof, parsed metrics, cold inventory, and artifact manifest. The fixed stop
must occur before apply.

Acceptance requires one released hot source exact row, a same-owner hot
exact/checkpoint pair with positive checked sizes, stable repeat state, zero
pre-apply events, empty cold storage, redacted secrets, and no apply, prepared,
terminal, or fault artifacts.

Fault execution, step 2, product changes, build, canonical TP-39-03, coverage,
full QA, commit, push, PR, and reviewer responses remain blocked. Fresh
Architect review must accept proof evidence before any fault rerun.
