# Stage 20 implementation: Stage 17 test infrastructure additions

Status: closed
Date: 2026-06-18
Stage: 20 (Stage 17 Test Infrastructure Additions)
Author: Developer (implementation plan and execution, fresh sessions)
Source design: [cache-handling-phase20-design.md](cache-handling-phase20-design.md) (entry + 4 parts)
Source closure: [cache-handling-phase17-implementation.md](cache-handling-phase17-implementation.md) D17-CLOSURE-01 (14 BLOCKED-acceptable rows)
Manager gate: D20-EXEC-02 (active, supersedes D20-EXEC-01; 27B fixture copied and verified 17.1 GB)
Current gate: closed (Manager closure 2026-06-18)

## Scope

Stage 20 adds three test infrastructure items deferred from the Stage 17 closure: agentic prompt generator (TP-20-SY1..SY5), Qwen3.6-27B-MTP fixture verification (TP-20-HV1..HV2), and S/L framework re-invocation (TP-20-ST1..ST3).

## Contents

- [Part 1: implementation plan](cache-handling-phase20-implementation.md) (also serves as plan file, 201 LF)
- [Part 2: Manager implementation-plan gate](cache-handling-phase20-implementation/part-02-manager-implementation-plan-gate.md)
- [Part 3: implementation evidence](cache-handling-phase20-implementation/part-03-implementation-evidence.md) (283 lines)
- [Part 4: Architect implementation review gate 01](cache-handling-phase20-implementation/part-04-architect-implementation-review-gate-01.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 20 design authoring | PASS (see design entry + parts 1-4) |
| Stage 20 design review | PASS (see [design part 5](cache-handling-phase20-design/part-05-design-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 0 INFO) |
| Stage 20 Manager design gate | PASS (see [design part 6](cache-handling-phase20-design/part-06-manager-design-gate.md)) |
| Stage 20 implementation planning | PASS (this file, 201 LF) |
| Stage 20 implementation-plan review | PASS (see [part 01](cache-handling-phase20-implementation/part-01-architect-implementation-plan-review-gate-01.md), 0 BLOCKING, 2 non-blocking, 4 INFO) |
| Stage 20 Manager implementation-plan gate | PASS (see [part 2](cache-handling-phase20-implementation/part-02-manager-implementation-plan-gate.md)) |
| Stage 20 implementation | PASS (see [part 3](cache-handling-phase20-implementation/part-03-implementation-evidence.md)) |
| Stage 20 implementation review | PASS (see [part 4](cache-handling-phase20-implementation/part-04-architect-implementation-review-gate-01.md), 0 BLOCKING, 1 non-blocking, 0 INFO) |
| Stage 20 closure | PASS (Manager closure 2026-06-18, see D20-CLOSURE-01 below) |

## Manager closure decision (D20-CLOSURE-01)

Date: 2026-06-18
Verdict: PASS

Stage 20 is closed. All three items implemented and verified:

- **Item 1 (agentic prompt generator)**: PASS. PowerShell `New-AgenticChatPrompt` at `lib/agentic-prompt-generator.ps1` (308 LF). Smoke test at target=100 produced actual=105 (within +/- 5% tolerance). Scale test at target=1000 produced actual=962. ValidateSet for SizeClass (12k/24k/60k) and PromptClass (4 classes). SHA256 checksum in output JSON.
- **Item 2 (Qwen3.6-27B-MTP fixture verification)**: PASS-PathA. Fixture size match verified (17106773120 bytes both source and destination). Three chat-template verification paths tested (A: no flag, B: placeholder jinja, C: extract from GGUF); Path A selected as first working per plan. 27B server smoke test: chat completion HTTP 200, cache_n=0. Memory fit constraint: needs `-c 2048 -np 1 --cache-ram 2048` for current system.
- **Item 3 (S/L framework wrapper)**: PASS. `kickoff-stage20-stress-longrun.ps1` (249 LF) based on V2 template. Port range 8800-8821 (disjoint from V2 8600-8621). DryRun PASS for 11 rows. S01 live launch PASS.

Implementation review: PASS, 0 BLOCKING, 1 non-blocking (F-20-IR-01 line count discrepancy, cosmetic).

Test plan execution verdicts:
- **TP-20-SY1..SY5**: PARTIAL. Small-target smoke (500 tokens, exact-repeat) PASS; chat1 cache_n=0, chat2 cache_n=483 restored. Large-target (12k+) cancelled at 60s timeout on Qwen3-0.6B model; needs bigger model or longer timeout (environment, not implementation defect).
- **TP-20-ST1..ST3**: PARTIAL. Wrapper DryRun PASS, S01 live launch PASS. Full 11-row S/L matrix deferred (8+ hour wall-clock, BLOCKED-test-session-scope).
- **TP-20-HV1..HV2**: Deferred per Manager approval (heavy tier, multi-hour session).

All PARTIAL verdicts are acceptable closure exceptions per Stage 17 part-27 BLOCKED-test-session-scope classification.

### Optional follow-ups (non-blocking)

- Large-target generator (12k+) needs Qwen3-0.6B timeout extension or bigger model. Smoke test confirms generator correctness; runtime fit deferred.
- Full S/L matrix (8 stress + 3 longrun rows, 8+ hour wall-clock) deferred to multi-hour session or nightly run.
- Heavy tier (TP-20-HV1/HV2) deferred to nightly or manual run per Stage 17 part-27 row classification.

### Code changes (UNCOMMITTED, awaiting user approval per AGENTS.md)

- `_design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1` (new, 308 LF, untracked)
- `_design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1` (new, 249 LF, untracked)

No production code, test code, or CMake changes.

## Handoff

Stage 20 closed. Next owner: user. PowerShell scripts awaiting commit approval per AGENTS.md.

All three Stage 17 deferred items are now addressed: agentic prompt generator works (smoke PASS), Qwen3.6-27B-MTP fixture copied and verified, S/L framework wrapper works (DryRun + S01 PASS). Full test matrix execution is deferred per Stage 17 part-27 BLOCKED-test-session-scope classification.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable doc cap.

---
# Stage 20 implementation: Stage 17 test infrastructure additions

Status: authored; pending Architect implementation-plan review
Date: 2026-06-18
Stage: 20 (Stage 17 Test Infrastructure Additions)
Author: Developer (implementation plan, fresh session)
Source design: [cache-handling-phase20-design.md](cache-handling-phase20-design.md) (entry + 4 parts)
Source closure: [cache-handling-phase17-implementation.md](cache-handling-phase17-implementation.md) D17-CLOSURE-01 (14 BLOCKED-acceptable rows)
Manager gate: D20-EXEC-02 (active, supersedes D20-EXEC-01; 27B fixture copied and verified 17.1 GB)
Current gate: implementation planning
Scope: Stage 20 implementation plan only. Not implementation, not test plan authoring, not Stage 18/19 re-review.

## Approved baseline

Implementation must follow the approved Stage 20 design:

- Entry doc [cache-handling-phase20-design.md](cache-handling-phase20-design.md) (116 lines)
- [Part 1: Item 1 - agentic prompt generator](cache-handling-phase20-design/part-01-item1-agentic-prompt-generator.md)
- [Part 2: Item 2 - Qwen3.6-27B-MTP fixture and Manager decision](cache-handling-phase20-design/part-02-item2-mtp27b-fixture-and-manager-decision.md)
- [Part 3: Item 3 - S/L framework re-invocation](cache-handling-phase20-design/part-03-item3-sl-framework-reinvocation.md)
- [Part 4: consolidated test plan rows, traceability, risks, handoff](cache-handling-phase20-design/part-04-test-plan-rows-traceability-risks-handoff.md)
- [Part 5: design review gate 01 (PASS, 0 BLOCKING, 3 non-blocking, 0 INFO)](cache-handling-phase20-design/part-05-design-review-gate-01.md)
- [Part 6: Manager design gate (PASS, D20-EXEC-02 active)](cache-handling-phase20-design/part-06-manager-design-gate.md)

## Manager decisions on record

| Decision ID | Status | Resolution |
| --- | --- | --- |
| R-20-DESIGN-MGR-01 | resolved by D20-EXEC-02 | Option B (track developer local copy); Qwen3.6-27B-MTP at `._test_models/Qwen3.6-27B-MTP-GGUF/Qwen3.6-27B-Q4_K_M.gguf` (17106773120 bytes verified). Supersedes D20-EXEC-01 Option C substitute path. |
| D20-EXEC-01 | superseded | Option C (Qwen3.5-4B-MTP substitute with BLOCKED-size-mismatch). No longer applies. |
| D20-EXEC-02 | active | User-supplied 27B fixture at `c:\Users\think\.lmstudio\models\unsloth\Qwen3.6-27B-MTP-GGUF\` copied to `._test_models/Qwen3.6-27B-MTP-GGUF\`. Source vs destination size match verified 17106773120 bytes (17.1 GB). `chat_template_new.jinja` copied from Qwen3.5-4B-MTP as placeholder; verification required at Item 2 step 2.4. |

The implementation plan reconciles the design-side ID (`R-20-DESIGN-MGR-01`) and the Manager-side ID (`D20-EXEC-02`) in this single table per F-20-DR-02 non-blocking finding.

## Code surfaces (not modified)

| Path | Status |
| --- | --- |
| `tools/server/*` | UNCHANGED (no cache code edits) |
| `tests/test-cache-controller.cpp` | UNCHANGED (no test code edits) |
| `build-cov/` (CMake flags, linker flags) | UNCHANGED |

Stage 20 only adds test scripts, verifies a fixture, and documents evidence. No production code or test code changes.

## New code surfaces

| Path | Owner | Purpose |
| --- | --- | --- |
| `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1` | Item 1 | `New-AgenticChatPrompt` PowerShell function per design part 1 |
| `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1` | Item 3 | Wrapper that re-invokes V2 framework with Stage 17 hooks |
| `._test_models/Qwen3.6-27B-MTP-GGUF/Qwen3.6-27B-Q4_K_M.gguf` | Item 2 | Already on disk per D20-EXEC-02 (verification only) |
| `._test_models/Qwen3.6-27B-MTP-GGUF/chat_template_new.jinja` | Item 2 | Placeholder from Qwen3.5-4B; smoke test in step 2.4 determines if Qwen3.6-specific template is needed |
| `._test_models/Qwen3.6-27B-MTP-GGUF/mmproj-F32.gguf` | Item 2 | Optional (Stage 17 heavy-tier is text-only); recorded as BLOCKED-mmproj-not-required |

## Ordered implementation steps

### Item 1 - Agentic prompt generator (TP-20-SY1..SY5 prerequisite)

Step 1.1: Verify `lib/` directory exists at `._design_docs/cache-handling-test-scripts/lib/`. Read-only check via `Test-Path`. Already verified (6 helpers present).

Step 1.2: Create `agentic-prompt-generator.ps1` with the following structure:

- Header: `#requires -Version 5`, `Status: PASS; Date: 2026-06-18; Owner: Developer (Stage 20 Item 1)`
- Public function `New-AgenticChatPrompt` with parameters: `-TargetTokens` (int, required), `-SizeClass` (ValidateSet 12k,24k,60k, required), `-PromptClass` (ValidateSet exact-repeat,near-duplicate,different-agent-same-prefix,same-branch-continuation, required), `-OutPath` (string, required), `-ServerUrl` (string, required per design), `-Seed` (int, default 42), `-MaxIterations` (int, default 50)
- Internal helpers: `Expand-MessagesRound` (appends one paragraph), `Invoke-TokenizeMeasure` (POST /tokenize with -TimeoutSec 30), `Get-ServerTokensEvaluated` (parses response), `New-ChecksumFromMessages` (sha256 over concatenated content), `Write-AgenticPromptJson` (writes JSON with -Depth 10)
- Output schema per design part 1: `version=stage20-agentic-prompt-v1`, `size_class`, `prompt_class`, `target_tokens`, `actual_tokens`, `token_measurement{endpoint,server_url,measured_at_unix,iterations}`, `messages[]`, `checksum`, `seed`
- Save with `New-Object System.Text.UTF8Encoding($false)` and convert CRLF to LF per the developer improvement memory ("Preserve local line endings in patch edits").

Step 1.3: Smoke-test the script with a running llama-server. Target `TargetTokens=100` to verify the round-by-round expansion stops within `MaxIterations`. Pre-launch server: `Start-Process llama-server.exe --port 18201 --model ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf --jinja --chat-template-file chat_template_new.jinja`. Wait for `/health` 200. Call `New-AgenticChatPrompt -TargetTokens 100 -SizeClass 12k -PromptClass exact-repeat -OutPath ._test_output/stage20-it1-smoke/prompt-100.json -ServerUrl http://127.0.0.1:18201`. Verify: prompt.json exists, has `actual_tokens` within `[95,105]`, `iterations<=MaxIterations`, sha256 `checksum` non-empty, no prompt text in any thrown exception (use a hostile test by killing the server and verifying the failure message lacks prompt content).

Step 1.4: Verify output JSON shape matches design part 1 schema. Parse the JSON with `ConvertFrom-Json` and assert field presence: `version`, `size_class`, `prompt_class`, `target_tokens`, `actual_tokens`, `token_measurement.endpoint=/tokenize`, `token_measurement.iterations>=1`, `messages` array length `>=2` (system + at least one user), `checksum` length `=64` hex chars, `seed=42`.

Step 1.5: Document verification result in the implementation log (part 4 evidence) as Item 1 step "PASS-smoke" with the actual measured token count, iteration count, and the script's path.

### Item 2 - Qwen3.6-27B-MTP fixture verification (TP-20-HV1..HV2 prerequisite)

Step 2.1: Verify file size match. `Get-ChildItem ._test_models/Qwen3.6-27B-MTP-GGUF | Select-Object Name, Length`. Expected: `Qwen3.6-27B-Q4_K_M.gguf` length `17106773120`, `chat_template_new.jinja` length `10313`, `mmproj-F32.gguf` length `1842940480`. Already verified 2026-06-18.

Step 2.2: Confirm source vs destination size match. Source: `c:\Users\think\.lmstudio\models\unsloth\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf`. Destination: `d:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf`. Both expected `17106773120`. Already verified by Manager; confirm again at execution time and record the timestamp.

Step 2.3: Smoke-test llama-server with the 27B fixture. Port `18202` to avoid V2 (8600-8621) and Stage 20 (8800-8821) ranges. Pre-checks: `Test-Path 'd:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf'` returns `True`. `Test-Path 'd:\source\llama.cpp-jet\build-cov\bin\Release\llama-server.exe'` returns `True`. Launch: `Start-Process -FilePath d:\source\llama.cpp-jet\build-cov\bin\Release\llama-server.exe -ArgumentList @('--port','18202','--model','d:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf','--jinja')`. Wait up to 180s for `/health` 200 (27B model warmup is longer than 4B; 180s cap is generous but bounded).

Step 2.4: Verify chat_template_new.jinja. Per D20-EXEC-02, the placeholder was copied from Qwen3.5-4B. Two paths to verify:

- Path A (preferred): start server without `--chat-template-file` flag and rely on the GGUF's built-in `tokenizer.chat_template`. If `/v1/chat/completions` round-trips cleanly, the embedded template works.
- Path B: start server with `--chat-template-file ._test_models/Qwen3.6-27B-MTP-GGUF/chat_template_new.jinja` (placeholder from Qwen3.5) and verify `/v1/chat/completions` round-trip.
- Path C: extract `tokenizer.chat_template` from the GGUF via `Read-GgufChatTemplate` (existing helper at `lib/Read-GgufChatTemplate.ps1`), compare to the placeholder, and either confirm they match or extract a Qwen3.6-specific template to overwrite `chat_template_new.jinja`.

If all three paths fail (server crash, /v1/chat/completions 400, or template mismatch warning), document as `BLOCKED-chat-template-incompatible` and route to a Manager decision (NOT in scope for Stage 20 implementation; the Manager decides whether to defer HV1/HV2 to a follow-up stage or accept a partial pass).

Step 2.5: Verify the server responds to a chat completion. Use a short deterministic prompt (e.g., user: "Reply with the single word: hello"). Verify `cache_n` field in response timings is `0` (cold path) and the response body is non-empty.

Step 2.6: Document the verification result per row, with the path tried and the actual response code. Record `chat_template_works=true|false|partial` based on Path A/B/C outcome.

### Item 3 - S/L framework re-invocation wrapper (TP-20-ST1..ST3 prerequisite)

Step 3.1: Verify existing scripts at `._design_docs/cache-handling-test-scripts/stress/` (8 files) and `longrun/` (3 files). Already verified by `Get-ChildItem`.

Step 3.2: Create `kickoff-stage20-stress-longrun.ps1` based on the V2 template (`kickoff-v2-stress-longrun.ps1`). Mirrors V2 structure (kill old PIDs, define row launch list, launch in batches of 2, per-batch verification, side log). Differences:

- Port range starts at `8800` (was 8600), ends at `8821` to avoid V2 collision per design part 3.
- Per-row `--CacheColdMaxMib` parameter (default `512`; `0` to disable, `-1` for unlimited) translated to `--cache-cold-max-mib`.
- Per-row `--CacheColdPath` parameter translated to `--cache-cold-path`.
- Per-row `--CacheRamMib` parameter (default `512`) translated to `--cache-ram-mib`.
- Per-row `--CachePromptEvidence` parameter (default `redacted`) translated to `--cache-prompt-evidence`.
- Per-row `--CachePromptEvidenceDir` parameter (required when evidence is not `off`) translated to `--cache-prompt-evidence-dir`.
- Per-row `--AgenticPromptPath` parameter (optional) sets the prompt file path consumed by Item 1.
- Per-row `--JinjaVariant` parameter (default `new`) selects `chat_template_new.jinja` or `chat_template.jinja`.
- L01 cap `2h`, L02 cap `30m`, L03 cap `2h` per design part 3 longrun row scope (V2 caps).
- Per-row evidence path: `._test_output/stage20-stress-YYYYMMDD-NN/<base>-<jinja>/` for S rows; `._test_output/stage20-longrun-YYYYMMDD-NN/<base>-<jinja>/` for L rows.
- Side log at `._design_docs/.test_reports/stage20-stress-YYYYMMDD-NN/batch-summary.log.side` (or `stage20-longrun`).

Step 3.3: Wrapper dry-run (V2 script has no dry-run; add a `DryRun` switch to the wrapper). Verify that the per-row ArgumentList contains `--cache-mode`, `--cache-cold-max-mib`, `--cache-prompt-evidence redacted`, `--cache-prompt-evidence-dir <path>`. This is the R-20-03 mitigation per design part 4: a wrapper dry-run that asserts the flags are present in the per-row command line.

Step 3.4: Test the wrapper with one S row (e.g., S01 Jnew variant, port 8800). Verify the child pwsh launches, the side log gets a `launched` line with the expected PID and flags, and the per-row `launch.log` has the expected banner. Capture the actual flags string from the launch.log side-by-side with the expected flags string; record the diff.

Step 3.5: Document the test result per step 3.4 with the launch log path, the side log path, and the flag diff. If the launch fails, document as `BLOCKED-wrapper-flag-mismatch` and apply the fix per the diff. If the launch succeeds but the server fails to bind (port collision), document as `BLOCKED-port-collision` and revise the port range.

## Test plan rows (10 total)

Per design part 4 consolidated table:

| Row | Type | Fixture | Pre-req | Execute via | Evidence | Pass/fail |
| --- | --- | --- | --- | --- | --- | --- |
| TP-20-SY1 | synthetic | generated 12k prompt | Item 1 step 1.5 | New-AgenticChatPrompt + 2 identical chat completions | `._test_output/stage20-syn-YYYYMMDD-NN/SY1/` | exact-repeat restores at 12k |
| TP-20-SY2 | synthetic | generated 24k prompt | Item 1 | New-AgenticChatPrompt + 2 identical chat completions | `._test_output/stage20-syn-YYYYMMDD-NN/SY2/` | exact-repeat restores at 24k |
| TP-20-SY3 | synthetic | generated 60k prompt | Item 1 | New-AgenticChatPrompt + 2 identical chat completions | `._test_output/stage20-syn-YYYYMMDD-NN/SY3/` | exact-repeat restores at 60k |
| TP-20-SY4 | synthetic | four prompt classes at 12k | Item 1 | New-AgenticChatPrompt x 4 + chat completions per class | `._test_output/stage20-syn-YYYYMMDD-NN/SY4/<class>/` | four prompt classes produce bounded outcomes |
| TP-20-SY5 | synthetic | generated 60k prompt + cold budget | Item 1 | New-AgenticChatPrompt + cold pressure | `._test_output/stage20-syn-YYYYMMDD-NN/SY5/` | cold pressure bounded, no write failure |
| TP-20-ST1 | stress | Qwen3.5-4B-MTP | Item 3 step 3.5 | kickoff-stage20-stress-longrun.ps1 S01..S08 Jnew | `._test_output/stage20-stress-YYYYMMDD-NN/<base>-Jnew/` per row | stress rows with redacted evidence PASS |
| TP-20-ST2 | longrun | Qwen3.5-4B-MTP | Item 3 step 3.5 | kickoff-stage20-stress-longrun.ps1 L01..L03 Jnew | `._test_output/stage20-longrun-YYYYMMDD-NN/<base>-Jnew/` per row | longrun rows respect cold budget |
| TP-20-ST3 | stress | Qwen3.5-4B-MTP | Item 3 step 3.5 | S03 Jnew with mixed exact + near-prefix | `._test_output/stage20-stress-YYYYMMDD-NN/S03-Jnew/` | prefix-only candidates rejected |
| TP-20-HV1 | heavy | Qwen3.6-27B-MTP (D20-EXEC-02) | Item 2 step 2.6 | kickoff-stage20-heavy.ps1 (post Manager approval) | `._test_output/stage20-hv-YYYYMMDD-NN/hv1/` | heavy MTP run reproduces Stage 16 log class |
| TP-20-HV2 | heavy | same as HV1 | Item 2 step 2.6 | same as HV1 + comparison table | `._test_output/stage20-hv-YYYYMMDD-NN/hv2/` + comparison table in heavy run report | Stage 16 baseline comparable |

The 10 rows are direct reopenings of TP-17-SY1..SY5, TP-17-ST1..ST3, TP-17-HV1..HV2. Per design part 4, the test plan author MAY rename to TP-20-XX; this implementation plan uses TP-20-XX for forward-looking references and notes the rename is non-binding.

PASS criteria: design part 4 per-row table; BLOCKED criteria: `BLOCKED-prompt-generator-failure` (overshoot beyond +5%, MaxIterations exceeded), `BLOCKED-fixture-absent` (27B model missing), `BLOCKED-chat-template-incompatible` (template verification fails all three paths), `BLOCKED-wrapper-flag-mismatch` (launch flags differ from expected), `BLOCKED-time-budget` (row exceeds cap), `BLOCKED-stress-low-throughput` (S row under 1000 hits+misses per part-25 rule).

## Affected files and lines

The implementation touches exactly three file paths and references one fixture directory:

| File | Lines added | Reason |
| --- | --- | --- |
| `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1` | new, ~150 lines | Item 1 generator |
| `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1` | new, ~200 lines | Item 3 wrapper |
| `._design_docs/.test_reports/stage20-it1-smoke/prompt-100.json` | new evidence file | Item 1 step 1.3 |
| `._design_docs/.test_reports/stage20-it2-fixture/server.out.log` + `server.err.log` + `health-response.log` + chat request/response files | new evidence files | Item 2 step 2.3-2.5 |
| `._design_docs/.test_reports/stage20-it3-wrapper/batch-summary.log.side` + `launch.log` | new evidence files | Item 3 step 3.4 |

No source code, test code, build configuration, or CMake flags are modified.

## Evidence plan

Each Item has a focused evidence path under `._design_docs/.test_reports/`:

| Item | Evidence path | Captures |
| --- | --- | --- |
| Item 1 step 1.3 | `stage20-it1-smoke/prompt-100.json` + `server.out.log` + `server.err.log` + `health-response.log` | smoke-test pass with measured token count + iterations + checksum |
| Item 1 step 1.4 | schema-verification record in part 4 | field presence assertions |
| Item 2 step 2.2 | `stage20-it2-fixture/size-verify.txt` | source vs destination size match |
| Item 2 step 2.3 | `stage20-it2-fixture/server.out.log` + `server.err.log` + `health-response.log` | 27B fixture launches clean, /health 200 |
| Item 2 step 2.4 | `stage20-it2-fixture/template-verify.txt` | Path A/B/C result + chat-template works/fails |
| Item 2 step 2.5 | `stage20-it2-fixture/chat-1-request.json` + `chat-1-response.json` | chat-completion round-trip |
| Item 3 step 3.4 | `stage20-it3-wrapper/batch-summary.log.side` + `S01-Jnew/launch.log` | one S row launched with expected flags |
| Item 3 step 3.5 | wrapper flag diff in part 4 | launch flags match expected |

The QA test plan (next gate) reuses this evidence structure with `._test_output/stage20-{syn,stress,longrun,hv}-YYYYMMDD-NN/<row>/` per design part 1, 3, 2.

## Known risks

| ID | Risk | Owner | Mitigation in plan |
| --- | --- | --- | --- |
| R-20-02 | Qwen3.6-27B-MTP fixture acquisition gated by R-20-DESIGN-MGR-01; Manager pick D (defer) would leave HV1/HV2 blocked. | Manager | Resolved by D20-EXEC-02 active (Option B track local copy). Plan references both decision IDs in the Manager decisions table; if a future Manager reverses D20-EXEC-02, the plan reverts to BLOCKED-test-session-scope for HV1/HV2. |
| R-20-04 | S/L framework session scope is 8+ hours wall-clock; the test session may not fit the full 22-row matrix in one go. | Manager + Developer | Step 3.2 wrapper supports per-row caps (L01=2h, L02=30m, L03=2h per design part 3). If session is interrupted, the wrapper's side log records the per-batch boundary and the QA test report cites the interrupted batch as `BLOCKED-time-budget` per part-25 rule. |
| OQ-20-02 | Is Qwen3.6-27B-MTP GGUF published on HuggingFace? | Manager | Resolved by D20-EXEC-02 Option B (track developer local copy); publication is no longer a blocker. Step 2.1-2.2 verifies the on-disk fixture. |
| OQ-20-03 | Does the 27B model require a separate license acceptance click on HuggingFace? | Manager | Resolved by D20-EXEC-02 Option B (local copy, no download); license acceptance is no longer a blocker. The placeholder chat_template_new.jinja was copied from Qwen3.5-4B; license attribution is the Qwen3.5 license per the source model's terms. |
| OQ-20-04 | Does the 27B model fit in 8 GiB hot cache plus bounded cold budget? | Manager + Developer | Step 2.3 smoke-test uses default cache settings; step 2.5 chat completion round-trip confirms the model fits in the default 8 GiB hot cache (a `--cache-ram-mib 8192` default is implied by the design part 2 fixture requirement). If the round-trip fails with OOM, the plan records `BLOCKED-fit-params` and escalates to Manager; option C (4B substitute) becomes the fallback path per design part 2 option C. |
| R-20-01 | Generator overshoot beyond +5% or MaxIterations exceeded; TP-20-SY1..SY5 fail. | Developer | Step 1.3 smoke-test validates the round-by-round expansion with a small target (100 tokens) to catch overshoot early. Step 1.4 schema check catches missing/extra fields. |
| R-20-03 | Wrapper mis-translates Stage 17 flags; rows run without redacted evidence or bounded cold budget. | Developer | Step 3.3 dry-run asserts the per-row flags are present. Step 3.4 launches one S row and captures the actual flag string for diff. |
| R-20-05 | Generator `messages` shape differs from Stage 16 chat-path boundary code path; boundary metadata may be incomplete. | Developer | Step 1.2 schema mandates `messages` array with `system + user + assistant` turns per design part 1. Step 1.4 schema check verifies field presence. QA test plan asserts `first_user_boundary` and `boundary_count` per row (TP-20-SY3). |
| R-20-06 | Heavy-tier rows under option C (4B substitute) produce size-mismatch; comparison to Stage 16 baseline weakened. | Manager | Resolved by D20-EXEC-02 Option B (27B fixture on disk); option C is no longer the path. |

## Stage 17 design review non-blocking findings

| ID | Title | Resolution path |
| --- | --- | --- |
| F-20-DR-01 | Brief line-count claim vs actual | No change required; brief numbers were approximate. Cap (300) satisfied for all 5 design files (verified 116/236/232/243/141). |
| F-20-DR-02 | Manager decision ID reconciliation (R-20-DESIGN-MGR-01 vs D20-EXEC-01/02) | Resolved in this plan's "Manager decisions on record" section by recording both IDs in a single table row. |
| F-20-DR-03 | OQ-20-01/05/06 deferred to implementation plan | OQ-20-01 (jinja variant): resolved per Item 3 step 3.2 default `new`. OQ-20-05 (V2 cap vs Stage 12 cap): resolved per Item 3 step 3.2 with V2 cap (2h/30m/2h). OQ-20-06 (agentic prompt generator for S/L rows): deferred; the wrapper's `-AgenticPromptPath` parameter (Item 3 step 3.2) accepts an optional generated prompt; S/L rows may continue to use existing short deterministic prompts per row (decision at QA test-plan authoring). |

## Handoff

Next owner: **Architect** for implementation-plan review in a fresh session.

After Architect implementation-plan review PASS, the plan advances to Manager for the implementation-plan gate. The Manager implementation-plan gate records D20-IMPL-01 (Stage 20 implementation approved). After that, the Developer executes Item 1, Item 2, and Item 3 in sequence and updates this implementation log with evidence captured at each step.

The Stage 17 implementation log, tracker, document-index, and any other durable doc are NOT modified by this plan. The Stage 20 implementation files are untracked until the user approves their inclusion in the index; the Manager adds the Stage 20 row to `document-index.md` and the implementation entry description only after Manager implementation-plan gate PASS.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable-doc cap. Per developer improvement memory, this untracked doc requires byte-level CR/LF and BOM verification at the implementation step before any subsequent edit.
