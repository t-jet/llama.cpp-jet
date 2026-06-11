VERDICT: PASS

# Stage 14 pre-merge report 01: Architect review (gate-01)

Source: [pre-merge-report-20260611-01.md](pre-merge-report-20260611-01.md)
Date: 2026-06-11
Reviewer session: Architect (Stage 14 pre-merge report review,
fresh session). Reviewer did not author the report or the
upstream-merge-guide corrections.

## Status

- Verdict: PASS
- Step 1 (pre-merge analysis) readiness: ready for Manager
  review of pre-merge analysis and then Developer Step 2
  (per-commit triage).
- BLOCKING findings: 0
- Non-blocking findings: 3 (N1, N2, N3)
- INFO notes: 4 (INFO1..INFO4)

## Scope and gate status

The review covers the Step 1 pre-merge report authored by the
Developer on 2026-06-11. The review checks procedure
conformance against the corrected upstream-merge-guide Part 1
(12 verification commands, commit-set selection, fork-point
rule, Path C direct remote-tracking ref), prerequisite
evidence (D5 dirty-worktree commit, D6 jet-fork-vs-actual-
upstream gap, D7 fork-point recovery), and decision recording
(D5, D6, D7 resolutions, D12 new open decision).

The Manager decisions log in the implementation entry doc
(`cache-handling-phase14-implementation.md` lines 53-99)
records D4 RESOLVED 2026-06-11, D5 RESOLVED 2026-06-11 with
commit `25d6a2a46`, D6 still marked "(open)", and D7 still
marked "(open)" at the entry doc. The pre-merge report
records D6 and D7 as RESOLVED 2026-06-11 with Developer
evidence and explicitly defers Manager confirmation to this
review. The Manager confirms D6 and D7 in the entry doc
decisions log after this review PASSES.

## Findings

| ID | Section | Description | Evidence |
| --- | --- | --- | --- |
| N1 | Pre-merge report file size | Report is 436 lines (verified via `(Get-Content).Count` and raw LF byte count = 436, CR = 0). The mandatory document size rule (document-index.md top section) says any doc over 300 lines must be split into part files or have a documented exception. The pre-merge report is a cycle-scoped test report under `.test_reports/`, not a durable design doc. The Stage 11 test-report precedent (referenced in upstream-merge-guide Part 1 procedure-at-a-glance and Stage 11 plan) treats cycle reports as one-shot artifacts that may exceed 300 lines, but the index rule does not explicitly exempt `.test_reports/`. | Lines 1-436 of `pre-merge-report-20260611-01.md`. LF-only, no UTF-8 BOM, no CR (byte scan). |
| N2 | "Range composition (informational)" section, lines 226-258 | The Developer pre-judges triage for several commits (e.g., `db94854ff` server checkpoint guard, `e95dae18d` MTP D2D cleanup, `7d2b45b4f` gemma-4 MTP, `6f3a9f3de` checkpoint restore guard, build/CI/vendor commits, documentation/webui commits). The section heading says "Range composition (informational)" and the lead-in text says "Step 2 triage will filter per plan part-03 rules" and "The Developer's informational pre-step-2 read of the 20-commit set". The Step 2 triage is the authoritative source per plan part-03, so this is a pre-step-2 read, not a triage decision. Could be misread as triage input by a reader who does not read the lead-in. | Lines 218-258 of the report. |
| N3 | D5 commit body, "part-05 architecture whitespace noise" line | The D5 commit body and Open Question 6 mention CRLF / trailing whitespace noise on the design part-05 file (the architecture part-05, `cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`, 581 lines changed in D5 stat). Per the developer improvement memory, CRLF artifact on a Windows worktree is reportable but non-actionable; byte-level trailing-whitespace scan on the file would distinguish real trailing whitespace from CRLF artifact. The D5 record already defers the per-line whitespace scan to the Step 1 plan documentary trail. The Open Question 6 surfaces it for review. | D5 commit stat line 1 shows 581 insertions/deletions in `cache-handling-architecture/part-05-...md`. Open Question 6 lines 391-398. |
| INFO1 | Cover and metadata, lines 25-40 | All required fields present: cycle number (Stage 14), design baseline link, date opened (2026-06-11), owner (Developer), integration branch tip SHA (D5 commit `25d6a2a46`), fork point SHA (`6ddc9430b145f61a0c1733b9d79c99c0ebdedf50`), upstream ref tip SHA (`18ef86ecec723361362a332a79b4d913fd724d40`), actual upstream tip SHA (same), plan baseline link, procedure baseline link, local default branch (`master`), current branch (`cache-optimization-caveman`). | Lines 25-40. |
| INFO2 | Upstream reference verification table, lines 47-65 | All 12 rows populated with the corrected upstream-merge-guide Part 1 procedure commands. Row 4 captures the `git ls-remote` output verbatim (`18ef86ecec723361362a332a79b4d913fd724d40        refs/heads/master`). Row 8 uses `git log --oneline origin/upstream_master -20` with the output deferred to the "Commit range" code block (acceptable per upstream-merge-guide Part 1 section 2, which records outputs in the pre-merge report sections). D6 gap = 0 verified. | Lines 47-65; Commit range code block lines 200-220. |
| INFO3 | D5 / D6 / D7 / D12 records, lines 109-300 | D5 references commit `25d6a2a46` (verified via `git show --stat`; 24 files changed, 3181 insertions, 289 deletions; subject matches; parent `31d60a944`). D6 records gap = 0 with `git ls-remote` evidence. D7 records fork point `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50` via `git merge-base master origin/upstream_master` (verified). D12 surfaces the D1 SHA `db94854ff56549f62b84d2f31608259a9e5e0e9f` (fetched 2026-06-04) as a stale reference against the current ref tip `18ef86ece` (refreshed 2026-06-11), with the recommended default to annotate rather than rewrite. | Lines 109-300; `git show --stat 25d6a2a46` output (24 files, 3181/289). |
| INFO4 | Path C conformance, all upstream ref references | Every upstream ref reference in the report uses `origin/upstream_master` directly. No "local tracking branch" wording. The bare `upstream_master` form is absent in the report (the only `upstream_master` literal is in the D6 record's quoted fetch-refspec example from upstream-merge-guide Part 4 section 7b, which uses a backquoted refspec form like `git fetch origin master:origin/master`). | Grep of the file for `upstream_master` shows 3 hits, all in `origin/upstream_master` form. |

## Checklist verification

| # | Item | Verdict | Note |
| --- | --- | --- | --- |
| 1 | Cover and metadata has all required fields | PASS with INFO1 | Lines 25-40. |
| 2 | Upstream reference verification table complete (12 rows) | PASS with INFO2 | Lines 47-65. |
| 3 | D5 record references `25d6a2a46`, dated 2026-06-11, clean tree | PASS with INFO3 | Lines 109-145. |
| 4 | D6 record RESOLVED with gap = 0 | PASS with INFO3 | Lines 152-175. |
| 5 | D7 record with fork point `6ddc9430b...` | PASS with INFO3 | Lines 184-200. |
| 6 | D12 record OPEN with recommended default | PASS with INFO3 | Lines 297-322. |
| 7 | Manager decisions requested lists D6, D7, D12 | PASS | Lines 264-295. |
| 8 | Commit range shows 94 commits with top 20 subjects and SHAs | PASS | Lines 200-220 + 223 lines (count of 94 in row 8 of verification table). |
| 9 | Path C conformance: all refs use `origin/upstream_master` | PASS with INFO4 | Grep result. |
| 10 | No invented decisions (only D1, D5, D6, D7, D12) | PASS | Decision mentions: D1 (line 49), D4 (line 28, 264), D5 (line 109), D6 (line 152), D7 (line 184), D12 (line 297). D4 cited only as historical Path C basis. No D8..D11 invented. |
| 11 | Evidence format: verbatim command outputs, `git ls-remote` captured | PASS | Row 4 of verification table captures `git ls-remote` output verbatim. Rows 1, 2, 3, 5, 6, 7, 8, 9, 12 capture SHA and shortstat verbatim. |
| 12 | Open questions listed | PASS | 6 open questions listed in lines 359-398. |
| 13 | Step 2 readiness for per-commit triage | PASS | Triage table placeholder present at lines 333-339; commit range on disk in `tmp/upstream-commit-list-20260611-01.txt` (verified via `Test-Path`). |
| 14 | File size rule (300-line cap) | PASS with N1 | 436 lines. See N1 for split-vs-exception recommendation. |
| 15 | D12 (D1 SHA staleness) recommended path | PASS with INFO3 | Recommended default in report (line 314-322): leave D1 SHA as historical anchor, add "refreshed on 2026-06-11, current tip 18ef86ece" annotation in plan part-04. |

## Required corrections

None. The pre-merge report passes the Architect review. The
non-blocking observations N1, N2, N3 are advisory and do not
block the Manager review of the pre-merge analysis or the
Developer Step 2 (per-commit triage).

## D12 recommendation

Adopt the Developer's recommended default: leave the D1
reference SHA `db94854ff56549f62b84d2f31608259a9e5e0e9f` in
plan part-01 and plan part-04 as the historical anchor, and
add a "refreshed on 2026-06-11, current tip 18ef86ece" note
in plan part-04's verification table row 2 and in plan
part-01's commit range rule. D6 gap = 0 means the D1 SHA is
informational only and rewriting it would erase the audit
trail of when the D1 reference was first set. The annotation
preserves the audit trail while flagging the refresh for
future readers.

## Doc-size-rule recommendation for the 436-line pre-merge report

Two options, both acceptable:

(a) Document an exception in the implementation entry doc
"Contents" section or in the test plan: cycle-scoped reports
under `._design_docs/.test_reports/` (pre-merge report, merge
log, test report) may exceed the 300-line cap because they
are one-shot artifacts tied to a specific cycle date, not
durable design docs. The exception applies only to files in
`.test_reports/` and only when the file is anchored to a
specific cycle (e.g., `pre-merge-report-YYYYMMDD-NN.md`).

(b) Split the pre-merge report into a main file
(`pre-merge-report-20260611-01.md`, <= 300 lines containing
cover, verification, D5/D6/D7/D12 records, manager decisions,
handoff) plus a part file
(`pre-merge-report-20260611-01-part-02-commit-range.md`)
containing the 94-commit range, the top 20 subjects/SHAs,
the informational range composition, the triage table
placeholder, and the open questions.

Recommended default: option (a), document the exception in
the implementation entry doc. The Stage 11 test-report
precedent (referenced in upstream-merge-guide Part 1) and
the cycle-scoped nature of the pre-merge report both support
the exception. A split (option b) is acceptable if the
Manager prefers strict adherence to the size rule.

## Handoff state

- Architect pre-merge report review: PASS (this file).
- Next gate: Manager review of the pre-merge analysis.
- Manager confirms D6 and D7 in the implementation entry doc
  decisions log (currently still marked "(open)" at lines
  81-99) and decides on the D12 open decision.
- After Manager review PASS, Developer opens Step 2
  (per-commit triage) in a new part file
  `part-06-triage-NN-<slug>.md` per plan part-03.
- Implementation gate, rework Stage N gates, test-plan gate,
  and QA execution gate remain closed.
- The 5 Stage 14 implementation-plan files and the pre-merge
  report are unchanged in this review. Only this review file
  is created.
