# Part 139: Manager full QA gate

Date: 2026-07-17
Verdict: PASS
Decision: D39-QA-01

Architect Part 138 passes the corrected two-node route evidence with no open
finding. D39-QA-01 authorizes fresh clean-build QA for the complete approved
Stage 39 plan in test-plan Part 43.

QA must create `._design_docs/.test_reports/test-report-20260717-01.md` and a
fresh artifact root. Record pre-session dirty state, commit identity, toolchain
and coverage-tool versions, fixture paths, backend, build commands, binary
timestamps, exclusions, and exact commands. Remove `build`, configure Release,
then build `llama-server` and every required focused cache target.

Run cheap focused checks before model-backed rows. Execute every TP-39-01
through TP-39-15 requirement, guarded route suite, canonical TP-39-02 through
TP-39-04, legacy and negative scenarios, restart/fault evidence, and the four
PowerShell 5/7 coverage command blocks required by Part 43. Coverage must
produce real merged artifacts and meet 80 percent. Reuse prior evidence only
where Part 43 allows durable focused or route evidence; cite its exact source
and confirm it is current relative to tested source.

Classify every row `PASS`, `FAIL`, `SKIP`, or `BLOCKED`. Missing evidence is not
PASS. Stop expensive execution after a product failure or closure-blocking
infrastructure failure when later rows cannot change the gate verdict; preserve
all collected evidence. Report final counts and assign each non-PASS row.

QA may update test automation only for an execution-only defect proved during
this session. Any such edit must be explicit and forces a fresh clean build
before affected evidence is accepted. Product changes, fixture or contract
changes, commit, push, PR, and reviewer response remain blocked. Developer
test-results review follows every complete or stopped report.
