Status: PASS
Date: 2026-06-18
Reviewer: Architect (implementation-plan review, fresh session)
Scope: Stage 20 implementation-plan review only. Not implementation, not test plan authoring, not Stage 18/19 re-review.
Branch: work-branch

# Stage 20 implementation-plan review gate 01

## Inputs reviewed

| File | Purpose | Status |
| --- | --- | --- |
| `_design_docs/cache-handling-phase20-implementation.md` | plan under review (201 lines, LF-only, no BOM, ASCII) | under review |
| `_design_docs/cache-handling-phase20-design.md` | design entry doc (115 lines, LF-only) | design PASS |
| `_design_docs/cache-handling-phase20-design/part-01-item1-agentic-prompt-generator.md` | Item 1 design (235 lines, LF-only) | design PASS |
| `_design_docs/cache-handling-phase20-design/part-02-item2-mtp27b-fixture-and-manager-decision.md` | Item 2 design (231 lines, LF-only) | design PASS |
| `_design_docs/cache-handling-phase20-design/part-03-item3-sl-framework-reinvocation.md` | Item 3 design (242 lines, LF-only) | design PASS |
| `_design_docs/cache-handling-phase20-design/part-04-test-plan-rows-traceability-risks-handoff.md` | consolidated (140 lines, LF-only) | design PASS |
| `_design_docs/cache-handling-phase20-design/part-05-design-review-gate-01.md` | Architect design review gate 01 (PASS, 0 BLOCKING, 3 non-blocking, 0 INFO; 156 lines) | design review PASS |
| `_design_docs/cache-handling-phase20-design/part-06-manager-design-gate.md` | Manager design gate (PASS, D20-EXEC-02 active, D20-EXEC-01 superseded; 69 lines) | manager design gate PASS |
| `_design_docs/cache-handling-test-plan/part-25-stage15-full-test-suite-validation.md` | S/L framework rules (1000 hits+misses threshold, cap-exit rule, bug-fix reclassification) | reference |
| `_design_docs/cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md` | Stage 17 test plan with 10 BLOCKED-acceptable rows | reference |
| `_design_docs/cache-handling-stage-tracker.md` row 20 | Stage 20 tracker row (design gate PASS, D20-EXEC-02 active) | reference |

Worktree verifications (read-only):

- `Get-ChildItem ._test_models/Qwen3.6-27B-MTP-GGUF`: `chat_template_new.jinja` (10313 bytes), `mmproj-F32.gguf` (1842940480 bytes), `Qwen3.6-27B-Q4_K_M.gguf` (17106773120 bytes). Size match verified.
- `Get-ChildItem ._design_docs/cache-handling-test-scripts`: stress/ (8 scripts), longrun/ (3 scripts), lib/ (6 helpers), kickoff-v2-stress-longrun.ps1 (8308 bytes), kickoff-v3-sequential-stress-longrun.ps1 present.
- `kickoff-v2-stress-longrun.ps1` line 67 starts V2 port range at 8600.
- Plan byte-level check: CR=0, BOM=False, LF=201, trailing-whitespace=0, non-ASCII=0, em-dash=0.
- All design files LF-only (CR=0), no BOM, ASCII only.

## Verification checklist

### Item 1 plan: agentic prompt generator

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | `New-AgenticChatPrompt` parameters complete | PASS | Plan step 1.2 lists 5 required (`-TargetTokens`, `-SizeClass`, `-PromptClass`, `-OutPath`, `-ServerUrl`) and 2 optional (`-Seed` default 42, `-MaxIterations` default 50). Matches design part 1 parameter list exactly. (Task-brief claim of 3 optional is off by 1; design says 2.) |
| 2 | Token measurement via `/tokenize` with +/- 5% tolerance | PASS | Plan step 1.2 names `Invoke-TokenizeMeasure` with `POST /tokenize` and `-TimeoutSec 30`. Step 1.3 smoke-test asserts `actual_tokens` within `[95,105]` for `TargetTokens=100` (the +5% tolerance). |
| 3 | Output JSON schema matches design part 1 | PASS | Plan step 1.4 asserts field presence: `version=stage20-agentic-prompt-v1`, `size_class`, `prompt_class`, `target_tokens`, `actual_tokens`, `token_measurement.endpoint=/tokenize`, `iterations>=1`, `messages` array length `>=2`, `checksum` length `=64` hex chars, `seed=42`. Matches design part 1 schema. |
| 4 | Deterministic via Seed | PASS | Default `Seed=42`, plan step 1.4 asserts `seed=42`. Design part 1 selects paragraph template by seed and uses class-specific seed offset. |
| 5 | Five helpers specified | PASS | Plan step 1.2 names `Expand-MessagesRound`, `Invoke-TokenizeMeasure`, `Get-ServerTokensEvaluated`, `New-ChecksumFromMessages`, `Write-AgenticPromptJson` (5 helpers, matches design). |
| 6 | Smoke test plan adequate (target=100 against running llama-server) | PASS | Plan step 1.3 uses `TargetTokens=100`, pre-launches llama-server on port 18201, waits for `/health` 200, calls `New-AgenticChatPrompt`, then verifies `prompt.json` exists with `actual_tokens in [95,105]`, `iterations<=MaxIterations`, sha256 checksum non-empty, no prompt text in thrown exception (hostile test by killing server). |

### Item 2 plan: Qwen3.6-27B-MTP fixture verification

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 7 | File size match verification (17106773120 bytes) | PASS | Plan step 2.1 names exact length `17106773120`. Verified on disk: `Qwen3.6-27B-Q4_K_M.gguf` = 17106773120 bytes (4 occurrences in plan text). |
| 8 | Smoke test: llama-server with 27B fixture, /health returns 200 | PASS | Plan step 2.3: pre-checks via `Test-Path`, launch on port `18202` (avoids V2 8600-8621 and Stage 20 8800-8821), wait up to 180s for `/health` 200. |
| 9 | Three chat-template verification paths (A: no flag, B: Qwen3.5 template, C: extract from GGUF) | PASS | Plan step 2.4 names Path A (server without `--chat-template-file`, rely on embedded `tokenizer.chat_template`), Path B (start with placeholder `chat_template_new.jinja` from Qwen3.5), Path C (extract via existing `Read-GgufChatTemplate` helper at `lib/Read-GgufChatTemplate.ps1` - verified present). |
| 10 | BLOCKED-chat-template-incompatible escalation | PASS | Plan step 2.4 names exact label `BLOCKED-chat-template-incompatible` and routes to Manager decision. Listed in PASS/FAIL/BLOCKED criteria. |
| 11 | Chat completion round-trip verification with short deterministic prompt | PASS | Plan step 2.5 uses user prompt "Reply with the single word: hello", verifies `cache_n=0` and non-empty response body. |

### Item 3 plan: S/L framework wrapper

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 12 | `kickoff-stage20-stress-longrun.ps1` based on V2 template | PASS | Plan step 3.2 mirrors V2 structure (kill old PIDs, define row launch list, launch in batches of 2, per-batch verification, side log). |
| 13 | Port range 8800-8821 avoids V2 collision | PASS | Plan step 3.2: "Port range starts at `8800` (was 8600), ends at `8821`". V2 starts at 8600 (verified at `kickoff-v2-stress-longrun.ps1:67`). |
| 14 | 6 new per-row parameters with defaults | PASS | Plan step 3.2 names 7 wrapper params (one above the brief's 6): `-CacheColdMaxMib` (default 512), `-CacheColdPath`, `-CacheRamMib` (default 512), `-CachePromptEvidence` (default redacted), `-CachePromptEvidenceDir` (required when evidence not off), `-AgenticPromptPath` (optional), `-JinjaVariant` (default new). Plan extends design part 3 by adding `-CacheColdPath` and `-CacheRamMib`; reasonable since the new flags map directly to existing `--cache-*` options. (Task-brief "6" is off by 1.) |
| 15 | Per-row caps L01=2h, L02=30m, L03=2h | PASS | Plan step 3.2: "L01 cap `2h`, L02 cap `30m`, L03 cap `2h` per design part 3 longrun row scope (V2 caps)". |
| 16 | DryRun flag assertion (R-20-03 mitigation) | PASS | Plan step 3.3: "add a `DryRun` switch to the wrapper" and assert per-row ArgumentList contains `--cache-mode`, `--cache-cold-max-mib`, `--cache-prompt-evidence redacted`, `--cache-prompt-evidence-dir <path>`. |
| 17 | Per-row evidence paths under `_design_docs/.test_reports/stage20-{stress,longrun}-YYYYMMDD-NN/` | PASS | Plan step 3.2: per-row evidence path `._test_output/stage20-stress-YYYYMMDD-NN/<base>-<jinja>/` for S rows; `._test_output/stage20-longrun-YYYYMMDD-NN/<base>-<jinja>/` for L rows. Side log at `._design_docs/.test_reports/stage20-stress-YYYYMMDD-NN/batch-summary.log.side`. |

### Test plan execution (10 rows)

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 18 | TP-20-SY1..SY5: agentic prompt generator + 2 chat completions each | PASS | Test plan rows table maps each SY row to `New-AgenticChatPrompt + 2 identical chat completions`. Evidence paths `._test_output/stage20-syn-YYYYMMDD-NN/SYx/`. |
| 19 | TP-20-ST1..ST3: wrapper with redacted evidence + bounded cold budget | PASS | Rows ST1/ST3 use `kickoff-stage20-stress-longrun.ps1 S01..S08 Jnew` with redacted evidence. Row ST2 uses L01..L03 with bounded cold budget 512 MiB. |
| 20 | TP-20-HV1..HV2: heavy kickoff deferred to Manager approval per design | PASS | Rows HV1/HV2 execute via `kickoff-stage20-heavy.ps1 (post Manager approval)`. Per design part 2 the heavy-tier framework is a stub pending the Manager pick; D20-EXEC-02 resolves the fixture question but the kickoff script remains gated. |
| 21 | Per-row evidence paths and PASS/FAIL/BLOCKED criteria | PASS | Test plan rows table column 6 names per-row evidence paths. PASS/FAIL/BLOCKED criteria list names six BLOCKED labels: `BLOCKED-prompt-generator-failure`, `BLOCKED-fixture-absent`, `BLOCKED-chat-template-incompatible`, `BLOCKED-wrapper-flag-mismatch`, `BLOCKED-time-budget`, `BLOCKED-stress-low-throughput`. |

### Decisions and risks

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 22 | D20-EXEC-02 (active) and D20-EXEC-01 (superseded) correctly referenced | PASS | Plan "Manager decisions on record" table: D20-EXEC-01 listed as `superseded`, D20-EXEC-02 listed as `active` with size match `17106773120` and `chat_template_new.jinja` placeholder. Reconciles design-side `R-20-DESIGN-MGR-01` and Manager-side `D20-EXEC-02` in a single table row per F-20-DR-02. |
| 23 | R-20-02 resolved by D20-EXEC-02 | PASS | Known risks table R-20-02: "Resolved by D20-EXEC-02 active (Option B track local copy)". |
| 24 | R-20-04 wrapped with per-row caps + BLOCKED-time-budget | PASS | Known risks table R-20-04: per-row caps L01=2h, L02=30m, L03=2h; `BLOCKED-time-budget` per part-25 rule referenced in step 3.2 and PASS/FAIL/BLOCKED criteria. |
| 25 | OQ-20-02/03/04 resolved by Option B | PASS | Known risks table OQ-20-02 (HuggingFace publication), OQ-20-03 (license), OQ-20-04 (fit in 8 GiB) all marked "Resolved by D20-EXEC-02 Option B". |
| 26 | Plus R-20-01, R-20-03, R-20-05, R-20-06 mitigated | PASS | Known risks table includes all four: R-20-01 (generator smoke-test with target=100), R-20-03 (wrapper dry-run asserts flags), R-20-05 (schema mandates `system + user + assistant`), R-20-06 (D20-EXEC-02 Option B resolves 27B fixture on disk). |

### Document quality

| # | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| 27 | Under 300 lines | PASS | Plan byte-level: LF=201, well under 300. (Task-brief "143 lines" appears to be an outdated or misread count; the file on disk is 201 lines per `(Get-Content).Count`.) |
| 28 | LF line endings (no CRLF) | PASS | Plan byte-level: CR=0, LF=201, BOM=False. Consistent with design files and doc-index rule. |
| 29 | No unicode icons | PASS | Plan byte-level: non-ASCII chars = 0. Em-dash count = 0. |
| 30 | Plain ASCII status labels | PASS | Status labels in plan: `PASS`, `FAIL`, `BLOCKED`, `superseded`, `active`, `NOT STARTED`, `pending`. All ASCII; no emoji. |

## Findings

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-20-IPR-01 | INFO | Task-brief line count claim (143) vs actual (201) | Brief states "143 lines"; byte-level LF count is 201. Both under 300-line cap. | No change required; brief was approximate. Plan is correct as authored. |
| F-20-IPR-02 | INFO | Generator parameter count: brief says 5+3, plan and design say 5+2 | Plan step 1.2 and design part 1 list 5 required + 2 optional (`-Seed`, `-MaxIterations`). Brief checklist item 1 says "3 optional". | No change required; plan matches approved design. Brief mismatch only. |
| F-20-IPR-03 | INFO | Wrapper parameter count: brief says 6, plan lists 7 | Plan step 3.2 names 7 wrapper params (extends design part 3 by adding `-CacheColdPath` and `-CacheRamMib`). Reasonable extension since both map to existing `--cache-*` options. | No change required; plan exceeds approved design by adding two parameters with clear mapping. Manager implementation-plan gate may revisit. |
| F-20-IPR-04 | non-blocking | Manager design gate doc (part-06) has CRLF line endings | `cache-handling-phase20-design/part-06-manager-design-gate.md` byte-level: CR=69, LF=69 (CRLF). Plan under review itself is LF-only (CR=0). | Note in handoff for next doc sweep. Out of scope for this implementation-plan review. Convert when next durable-doc sweep touches that file. |
| F-20-IPR-05 | non-blocking | Step 2.5 cache_n=0 assumption for first chat completion | Plan step 2.5 asserts `cache_n` field is `0` (cold path) on the first request. If a prior /tokenize or completion warmup populated the cache, this may not hold. | Acceptable as smoke-test scope is narrow. If QA finds non-zero cache_n on first request, route to `BLOCKED-cache-nonzero-cold` and verify the prior request was not generated by the smoke-test itself. |
| F-20-IPR-06 | INFO | Stage 20 design files untracked, document-index not yet updated | `Select-String 'phase20' document-index.md` returns no matches; tracker row 20 references the design and Manager gate but the document-index row is not yet present. Plan correctly states "Manager adds the Stage 20 row to `document-index.md`... only after Manager implementation-plan gate PASS". | No change required; sequencing is by design. Manager implementation-plan gate will add the document-index row. |

## Counts

- BLOCKING: 0
- non-blocking: 2 (F-20-IPR-04, F-20-IPR-05)
- INFO: 4 (F-20-IPR-01, F-20-IPR-02, F-20-IPR-03, F-20-IPR-06)

## Verdict

PASS. The Stage 20 implementation plan is internally consistent with the approved Stage 20 design, the Manager design gate, and the Stage 17 closure decisions.

- Item 1 plan correctly specifies the `New-AgenticChatPrompt` function with the design-approved 5 required + 2 optional parameters, the five named helpers, the `/tokenize` token measurement protocol with +/- 5% tolerance, the output JSON schema, deterministic seeding, and a smoke-test plan that catches overshoot and prompt-text leakage early.
- Item 2 plan correctly maps the D20-EXEC-02 Manager decision (Option B, 27B fixture on disk, size match 17106773120) into a verification sequence that checks file size, launches the server, verifies the chat template via three independent paths, escalates to `BLOCKED-chat-template-incompatible` on failure, and round-trips a short chat completion.
- Item 3 plan correctly wraps the V2 S/L framework with seven per-row parameters, port range 8800-8821 to avoid V2 collision, V2 caps (L01=2h, L02=30m, L03=2h), a `DryRun` switch for the R-20-03 mitigation, and per-row evidence paths under `_design_docs/.test_reports/stage20-{stress,longrun}-YYYYMMDD-NN/`.
- The 10 test plan rows (TP-20-SY1..SY5, TP-20-ST1..ST3, TP-20-HV1..HV2) carry per-row evidence paths and PASS/FAIL/BLOCKED criteria with six named BLOCKED labels.
- D20-EXEC-02 (active) and D20-EXEC-01 (superseded) are correctly recorded in the Manager decisions table. R-20-02, R-20-04, OQ-20-02/03/04 are resolved by D20-EXEC-02 Option B. R-20-01, R-20-03, R-20-05, R-20-06 carry concrete mitigations.
- Format claims verified by byte-level inspection: CR=0, BOM=False, LF=201, no unicode, no em-dash, no trailing whitespace, plain ASCII status labels.

The two non-blocking findings are out of scope (CRLF on the Manager design gate doc, which is not the plan under review) or narrow smoke-test assumption (cache_n=0 on first request). The four INFO findings are task-brief mismatches or sequencing notes that do not affect plan correctness.

## Handoff

Next owner: **Manager** for the Stage 20 implementation-plan gate in a fresh session.

The Manager implementation-plan gate records D20-IMPL-01 (Stage 20 implementation approved). After Manager implementation-plan gate PASS:

1. The Developer executes Item 1 (agentic prompt generator), Item 2 (27B fixture verification), and Item 3 (S/L wrapper) in sequence and updates the implementation log with evidence captured at each step.
2. The Manager adds the Stage 20 row to `document-index.md` per the deferred-from-design-gate plan note.
3. The QA test plan author reopens TP-17-SY1..SY5, TP-17-ST1..ST3, and TP-17-HV1/HV2 as TP-20-XX and reclassifies from `BLOCKED-*` to PASS or BLOCKED with a documented harness/setup reason.

Advisory for the Manager:

- The Manager design gate doc (`cache-handling-phase20-design/part-06-manager-design-gate.md`) has CRLF line endings. This is out of scope for the implementation-plan review but worth converting to LF-only UTF-8 (no BOM) at the next durable-doc sweep, following the same procedure used for this plan.

This review file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable-doc cap.
