Status: PASS
Date: 2026-06-18
Reviewer: Architect (design review, fresh session)
Scope: Stage 20 design review only. Not re-review of Stage 17 or any other stage.
Branch: work-branch

# Stage 20 design review gate 01


## Inputs reviewed

| File | Purpose | Lines (LF) | Status |
| --- | --- | --- | --- |
| `cache-handling-phase20-design.md` | entry doc | 116 | LF-only, no BOM, ASCII |
| `part-01-item1-agentic-prompt-generator.md` | Item 1 design | 236 | LF-only, no BOM, ASCII |
| `part-02-item2-mtp27b-fixture-and-manager-decision.md` | Item 2 design | 232 | LF-only, no BOM, ASCII |
| `part-03-item3-sl-framework-reinvocation.md` | Item 3 design | 243 | LF-only, no BOM, ASCII |
| `part-04-test-plan-rows-traceability-risks-handoff.md` | consolidated | 141 | LF-only, no BOM, ASCII |

All five files satisfy the 300-line durable-doc cap. Format claims in
each file's footer ("LF line endings, plain ASCII status labels, under
300 lines") verified by byte-level inspection.

Reference docs consulted:

- `cache-handling-test-plan/part-25-stage15-full-test-suite-validation.md` (S/L framework)
- `cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md` (Stage 17 test plan with the 10 BLOCKED-acceptable rows)
- `cache-handling-stage-tracker.md` Stage 20 row + D20-EXEC-01

Worktree verifications:

- `Get-ChildItem ._test_models/` shows no `Qwen3.6-27B-MTP-GGUF` directory
- `Test-Path '._test_models/Qwen3.6-27B-MTP-GGUF'` returns `False`
- `Get-ChildItem ._design_docs/cache-handling-test-scripts/stress/` lists 8 stress scripts
- `Get-ChildItem ._design_docs/cache-handling-test-scripts/longrun/` lists 3 longrun scripts
- `kickoff-v2-stress-longrun.ps1` present at the test-scripts root
- `git status --short` shows the five Stage 20 design files are untracked on `work-branch`
- `git diff --check` returns clean on all five files

## Verification checklist

### Item 1: agentic prompt generator

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | `New-AgenticChatPrompt` parameters correct | PASS | Required: `-TargetTokens`, `-SizeClass`, `-PromptClass`, `-OutPath`, `-ServerUrl`. Optional: `-Seed` (default 42), `-MaxIterations` (default 50). |
| 2 | Token measurement via `/tokenize` sound | PASS | Round-by-round expansion, POST `/tokenize`, reads `tokens_evaluated`, stops at target or cap. Server must run hybrid mode with same model. |
| 3 | Output JSON with `messages`, `actual_tokens`, `checksum` | PASS | Schema includes `version`, `size_class`, `prompt_class`, `target_tokens`, `actual_tokens`, `token_measurement`, `messages`, `checksum`, `seed`. |
| 4 | Deterministic via seed | PASS | Default `Seed=42`, paragraph template selected by seed, class-specific seed offset. |
| 5 | Reuse by Item 3 noted | PASS | "Generator reuse beyond synthetic tier" section plus wrapper `-AgenticPromptPath` parameter. |

### Item 2: Qwen3.6-27B-MTP substitute (D20-EXEC-01 Option C)

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 6 | Manager decision D20-EXEC-01 documented | PASS | Tracker row 20 records D20-EXEC-01 Option C autonomous 2026-06-18; design part-02 surfaces the decision as `R-20-DESIGN-MGR-01` with four options. |
| 7 | `BLOCKED-size-mismatch` annotation proposed | PASS | Part-02 Option C consequence: TP-17-HV1/HV2 reopen with `BLOCKED-size-mismatch` annotation. |
| 8 | Original Qwen3.6-27B-MTP deferred to follow-up stage | PASS | Part-02 Option D describes defer; tracker confirms deferral. |

### Item 3: S/L framework re-invocation

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 9 | Existing 8 stress + 3 longrun scripts referenced | PASS | Part-03 lists all 11 scripts by name; `Get-ChildItem` confirms present. |
| 10 | `kickoff-v2-stress-longrun.ps1` noted | PASS | Part-03 references V2 kickoff; `Get-ChildItem` confirms present. |
| 11 | Wrapper `kickoff-stage20-stress-longrun.ps1` CLI flags correct | PASS | Wrapper params: `-CacheColdMaxMib`, `-CachePromptEvidence`, `-CachePromptEvidenceDir`, `-AgenticPromptPath`, `-JinjaVariant`. |
| 12 | Per-row caps: L01 2h, L02 30m, L03 2h | PASS | Part-03 longrun scope explicitly states V2 caps. |
| 13 | Port range 8800-8821 avoids V2 collision | PASS | Part-03 explicitly states V2=8600-8621, Stage 20=8800-8821. |

### Test plan rows (10 total)

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 14 | 5 synthetic TP-20-SY1..SY5 adequate | PASS | All 5 rows in part-01 table; consolidated in part-04. |
| 15 | 3 stress-longrun TP-20-ST1..ST3 adequate | PASS | All 3 rows in part-03 table; consolidated in part-04. |
| 16 | 2 heavy TP-20-HV1..HV2 adequate with BLOCKED-size-mismatch | PASS | Both rows in part-02 stub table; consolidated in part-04 with annotation. |

### Traceability

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 17 | Each item maps to Stage 17 closure deferred items | PASS | Part-04 traceability table maps 6 rows (3 deferred items + 3 design-part-04 tier rows). |
| 18 | Manager decision D20-EXEC-01 referenced correctly | PASS | Design uses `R-20-DESIGN-MGR-01` (pre-decision design-side ID); tracker uses `D20-EXEC-01` (post-decision Manager-side ID). Implementation plan must reconcile. |
| 19 | R-20-02, R-20-04, OQ-20-02/03/04 have owners and mitigations | PASS | All 5 rows in part-04 risks table carry owner and mitigation columns. |

### Document quality

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 20 | Each part file under 300 lines | PASS | 116/236/232/243/141 (all under 300). Brief's stated numbers (93/192/177/194/114) differ but cap is satisfied. |
| 21 | LF line endings, no CRLF, no BOM | PASS | Byte-level check: `cr=0` for all 5 files; `no-BOM` for all 5. |
| 22 | No unicode icons | PASS | All 5 files scan clean (no char > 127). |
| 23 | Plain ASCII status labels | PASS | `PASS`/`FAIL`/`BLOCKED`/`SKIP` only; no emoji. |

## Findings

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-20-DR-01 | non-blocking | Brief line-count claim vs actual | Brief lists 93/192/177/194/114; actual 116/236/232/243/141. Cap (300) satisfied. | No change required; brief numbers were approximate. |
| F-20-DR-02 | non-blocking | Manager decision ID reconciliation | Design uses `R-20-DESIGN-MGR-01` (design-side, pre-decision); tracker uses `D20-EXEC-01` (Manager-side, post-decision). | Implementation plan records both IDs in a single decision table row. |
| F-20-DR-03 | non-blocking | OQ-20-01/05/06 deferred to implementation plan | Part-01 OQ-20-01 and part-03 OQ-20-05/06 list Developer as decision owner at plan time. | Implementation plan records decisions per row; design deferral is acceptable. |

## Counts

- BLOCKING: 0
- non-blocking: 3
- INFO: 0

## Verdict

PASS. The Stage 20 design is reviewable, internally consistent, and
satisfies the durability contract:

- Item 1 (agentic prompt generator) is a complete PowerShell design
  with sound token measurement via `/tokenize`, deterministic seed,
  bounded output JSON, and explicit reuse by Item 3.
- Item 2 (Qwen3.6-27B-MTP fixture) correctly defers to Manager via
  four documented options with rationale. Manager recorded
  D20-EXEC-01 Option C in the tracker; the design's stub state is
  consistent with that decision and supports the BLOCKED-size-mismatch
  closure exception.
- Item 3 (S/L framework re-invocation) names every existing framework
  script, defines a wrapper with the correct Stage 17 flags, picks
  port range 8800-8821 to avoid V2 collision, and uses V2 caps for
  predictable session scope.
- The 10 test plan rows map cleanly to the Stage 17 BLOCKED-acceptable
  rows and carry per-row evidence paths and pass/fail criteria.
- Risks R-20-01..R-20-06 and open questions OQ-20-01..OQ-20-06 carry
  owners and mitigations.
- All five files are LF-only, no BOM, no unicode, no CRLF, and under
  the 300-line durable-doc cap. The cap rule is the binding rule; the
  brief's stated line counts (item 20) are approximate and not a
  defect.

No blocking findings. The three non-blocking findings are
documentation-reconciliation or implementation-plan-time decisions
that do not affect the design's reviewability.

## Handoff

Next owner: **Manager** for the Stage 20 design gate.

The Manager design gate MUST record `R-20-DESIGN-MGR-01` (the design-side
decision ID) with one of the four options in part-02, and reconcile
with `D20-EXEC-01` (the Manager-side decision ID recorded in the
tracker). After the Manager design gate PASS:

1. Implementation planning opens for Item 1 and Item 3 in parallel.
2. Implementation planning for Item 2 opens after the Manager decision
   is recorded.
3. The Developer references both decision IDs in the implementation
   log to avoid future drift.

This review file uses LF line endings, plain ASCII status labels, and
stays under the 300-line durable-doc cap. No other durable doc is
modified by this review.
