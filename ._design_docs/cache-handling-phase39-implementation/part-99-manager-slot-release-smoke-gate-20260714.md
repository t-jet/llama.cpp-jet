# Part 99: Manager slot-release smoke gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-24

Design Part 50 and Architect Part 98 classify the empty inventory as expected
active-slot state. D39-EXEC-24 authorizes the helper-only two-request lifecycle
correction, its pure tests, and one no-apply midpoint smoke.

Developer may add the exact Part 62 incoming request after the source request.
The helper must preserve both pre-validation captures and add the source and
post-incoming captures named in Part 50. The chat cap becomes two. No filler or
third request is allowed.

Run the Part 50 pure mocked lifecycle tests first. Only after they pass, run one
fresh midpoint smoke. The smoke must prove source pinned after request one,
source eligible after request two, one exact/checkpoint source pair, distinct
active incoming owner, clean cold state, and zero pre-apply decisions or
transactions. Stop before apply. A repeated empty inventory or owner mismatch
is structural and ends calibration.

Step 2, fault apply, product changes, build, canonical TP-39-03, coverage, full
QA, commit, push, PR, and reviewer responses remain blocked. Fresh Architect
review must accept the captured lifecycle before any fault rerun.
