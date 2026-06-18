# Stage 20 Manager design gate

Status: PASS
Date: 2026-06-18
Stage: 20 (Stage 17 Test Infrastructure Additions)
Branch: work-branch
Reviewer: Manager
Source design: [cache-handling-phase20-design.md](../cache-handling-phase20-design.md) (entry + 4 parts)
Design review: [part-05-design-review-gate-01.md](../cache-handling-phase20-design/part-05-design-review-gate-01.md) (PASS, 0 BLOCKING, 3 non-blocking, 0 INFO)

## Manager decision

The Stage 20 design is approved. The three items (agentic prompt generator, Qwen3.6-27B-MTP fixture, S/L framework re-invocation) are correctly scoped with Manager decision point R-20-DESIGN-MGR-01.

The three non-blocking findings (F-20-DR-01 line counts, F-20-DR-02 decision ID reconciliation, F-20-DR-03 deferred open questions) are accepted as Developer verification items.

## Manager decisions on record

### D20-EXEC-01 (superseded by D20-EXEC-02)

Originally recorded as: substitute Qwen3.5-4B-MTP with BLOCKED-size-mismatch (autonomous, user not available).

### D20-EXEC-02 (active)

User provided the Qwen3.6-27B-MTP fixture at `c:\Users\think\.lmstudio\models\unsloth\Qwen3.6-27B-MTP-GGUF\`. Decision: Option B from design part 2 (track developer local copy). The fixture was copied to `d:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF\` for standard test path location. Verified: source size 17106773120 bytes matches destination size 17106773120 bytes (17.1 GB).

Additional files copied:
- `mmproj-F32.gguf` (1.8 GB, optional for Stage 17 heavy-tier which is text-only)
- `chat_template_new.jinja` (10 KB, copied from Qwen3.5-4B as placeholder; may need replacement if Qwen3.6 requires different template)

This supersedes D20-EXEC-01. The substitute Qwen3.5-4B-MTP option is no longer needed.

### Implications

- TP-17-HV1 / TP-17-HV2 reopen with the actual 27B fixture at `._test_models/Qwen3.6-27B-MTP-GGUF/Qwen3.6-27B-Q4_K_M.gguf`
- The `BLOCKED-size-mismatch` annotation no longer applies
- TP-20-HV1 / TP-20-HV2 (reopened rows) use the 27B fixture as originally specified
- Heavy-tier rows are no longer blocked by fixture absence

## Manager gate checks

| Check | Result | Notes |
| --- | --- | --- |
| Design docs are reviewable and indexed | PASS | Entry + 4 parts, all under 300-line cap, LF-only |
| Scope, prerequisites, assumptions, interfaces, constraints, observability, testability documented | PASS | 3 items correctly mapped to Stage 17 deferred items |
| Architecture and requirements traceability is explicit | PASS | Maps to Stage 17 closure deferred items; R-20-DESIGN-MGR-01 resolved via D20-EXEC-02 |
| Prerequisite gaps, contradictions, risks are explicit | PASS | Fixture acquisition resolved; S/L framework integration documented |
| Review is recorded with a pass verdict | PASS | part-05 0 BLOCKING, 3 non-blocking, 0 INFO |
| Non-blocking findings are actionable and assigned | PASS | F-20-DR-01..03 accepted |

## Advisory carry-forward

The Developer session must:

1. Implement Item 1 (agentic prompt generator): PowerShell `New-AgenticChatPrompt` at `_design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`. Verified against running llama-server `/tokenize` endpoint.
2. Verify Item 2 (Qwen3.6-27B-MTP fixture): already on disk at `._test_models/Qwen3.6-27B-MTP-GGUF/`. Developer must smoke-test the fixture starts cleanly (run llama-server with `--model` and verify `/health` returns 200).
3. Implement Item 3 (S/L framework re-invocation): `kickoff-stage20-stress-longrun.ps1` wrapper with Stage 17 cache flags. Per-row caps L01=2h, L02=30m, L03=2h.
4. Verify chat_template_new.jinja works for Qwen3.6-27B; if not, replace with Qwen3.6-specific template or generate one.
5. Document the implementation in evidence files per stage 20 part 4 plan.

## Decision

The Stage 20 design is approved. Advance to implementation planning.

## Handoff

Next owner: Developer for implementation planning in a fresh session. Plan must reference D20-EXEC-02 (active) and the copied fixture path.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable doc cap.
