# Cache handling test plan - Part 21: Stage 12 MTP and jinja variant test plan

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Matrix: [part-18](part-18-stage12-stress-benchmarks.md)
Operational: [part-18a](part-18a-stage12-operational.md)
Automation: [part-19](part-19-stage12-test-automation.md)
Stage 12 closure: [../../cache-handling-phase12-implementation/part-07-stage12-closure-decision.md](../../cache-handling-phase12-implementation/part-07-stage12-closure-decision.md)
Scope expansion design: [../../cache-handling-phase12-design/part-10-stage12-scope-expansion-design.md](../../cache-handling-phase12-design/part-10-stage12-scope-expansion-design.md)
Execution details: [part-21a](part-21a-stage12-mtp-jinja-execution.md)
Architecture (Jinja boundary interface): [../cache-handling-architecture/part-02](../cache-handling-architecture/part-02-restore-and-residency-flow.md)

## 1. Scope

Post-closure follow-up scope for Stage 12. Adds MTP variants and
jinja variants to the existing 19-scenario matrix. Closes
part-10 scope-expansion item A (MTP-capable rows) and records the
jinja marking surface from the 2026-06-07 closure handoff. No new
cache algorithms, public endpoints, CLI flags, or metric schema.
The 2026-06-07 closure PASS is preserved; this part only adds
new scope and execution rules.

## 2. New scope totals

The base 19-scenario matrix (S12-S01..S08 stress, S12-B01..B08
bench, S12-L01..L03 longrun) gets a jinja variant parameter.
Three MTP variants (V1, V2, V3) are added on top of each base
scenario. Row count: 3 MTP variants x 19 base x 2 jinja + 19
non-MTP x 2 jinja = 152 scenarios (19 x 2 = 38 per MTP row,
plus 38 non-MTP rows).

Execution is split across 4 sessions, 1 test report file per
session. Stress rows keep the full 30-minute wall-clock budget
from part-18 in every session; bench rows use the 1-min reduced
budget per simple-fix #4; long-run rows use the full duration in
V1/V3 and the reduced budget elsewhere. Per-session breakdown:

- Session V1: 19 base x 2 jinja (V1 MTP, built-in MTP path) = 38 rows
- Session V2: 19 base x 2 jinja (V2 separate-draft path) = 38 rows
- Session V3: 19 base x 2 jinja (V3 MTP, built-in MTP path) = 38 rows
- Session non-MTP re-run: 19 base x 2 jinja (no MTP) = 38 rows

Total: 152 rows across 4 session reports. Wall-clock total
stays bounded by the per-session budget; per-row time-budget
infeasibility from the original mega-session is resolved.

## 3. MTP variant matrix

Three MTP variants are added:

- V1 = Qwen3.5-4B-MTP. Single model with built-in MTP path.
  Source: `._test_models\Qwen3.5-4B-MTP-GGUF\` (canonical
  local copy; the user-side lmstudio tree is no longer read
  at runtime).
- V2 = Qwen3-8B target plus Qwen3-0.6B separate-draft. Two
  fixtures run as a target-draft pair through `--model-draft`.
  Sources: `._test_models\Qwen3-8B-GGUF\` and
  `._test_models\Qwen3-0.6B-GGUF\`.
- V3 = Qwen3.6-27B-MTP. Single model with built-in MTP path.
  Source: `._test_models\Qwen3.6-27B-MTP-GGUF\` (canonical
  local copy; if missing, the driver copies the gguf and
  pre-existing jinja files from the user-side lmstudio tree
  at
  `C:\Users\think\.lmstudio\models\unsloth\Qwen3.6-27B-MTP-GGUF`
  before the first V3 sub-run).

Server flag rules:

- V1 and V3 use `--spec-type draft-mtp`.
- V2 uses `--model-draft` pointing at Qwen3-0.6B plus
  `--spec-type draft-simple`. Without the spec type, the server
  loads the draft model but leaves speculative decoding disabled.

Each base scenario (S12-S01..S08, S12-B01..B08, S12-L01..L03)
runs under all three MTP variants, yielding 57 MTP sub-rows.
Row IDs follow the pattern `S12-MTP-{base}-V{V}`. Full row
list in part-18a section 8.

## 4. Jinja variant matrix

Each scenario (with or without an MTP variant) runs both jinja
variants:

- `-JinjaVariant=original`: `chat_template.jinja` (no input
  marking). Behavior matches the existing public llama.cpp path.
- `-JinjaVariant=marked`: `chat_template_new.jinja` (with input
  marking per the Adopted Jinja Boundary Interface in the
  architecture doc part-02). The marked variant renders the
  markup header and `<|cache_boundary:kind[:label]|>` markers
  around each message/system/tool/media/generation span
  (part-21a section 3).

Jinja file path rule: the driver joins `JinjaDir`, the variant
name, and `.jinja` with path separators. So the resolved
file is `JinjaDir/chat_template.jinja` for `original` and
`JinjaDir/chat_template_new.jinja` for `marked`.

- V1: `JinjaDir` is
  `._test_models\Qwen3.5-4B-MTP-GGUF\`. Both
  `chat_template.jinja` and `chat_template_new.jinja` are
  present locally. The canonical local copy is used; the
  lmstudio user-side copy is not read at runtime.
- V3: `JinjaDir` is `._test_models\Qwen3.6-27B-MTP-GGUF\`. If
  the model directory is missing the driver copies the gguf
  and any pre-existing jinja files from the user-side lmstudio
  tree at
  `C:\Users\think\.lmstudio\models\unsloth\Qwen3.6-27B-MTP-GGUF`
  before the first V3 sub-run. The canonical local copy is the
  only runtime source.
- V2: `JinjaDir` is the target model gguf directory
  (`._test_models\Qwen3-8B-GGUF\` and
  `._test_models\Qwen3-0.6B-GGUF\`). V2-only jinja extraction
  is per part-21a section 2.

## 5. Pointer to execution details

V2 jinja extraction contract, input marking transformation
rules, driver parameter contract, and the multi-session
execution plan live in
[part-21a](part-21a-stage12-mtp-jinja-execution.md). This split
keeps part-21 under the 300-line repo rule from
`document-index.md`.

## 6. Pass/fail criteria

Each sub-run is a fresh scenario row. PASS criteria match the
base scenario criteria in part-18 plus:

- `jinja-variant.txt` and `mtp-variant.txt` present and
  matching the plan row.
- `jinja-path.txt` exists and points to a real file on disk
  before the scenario starts.
- V2: the jinja extraction step (if any) completes and
  produces `chat_template.jinja` and `chat_template_new.jinja`
  in the target model directory. Extraction event is recorded
  in the per-scenario evidence summary.
- V1 and V3: the jinja path under the canonical
  `._test_models\Qwen3.5-4B-MTP-GGUF\` or
  `._test_models\Qwen3.6-27B-MTP-GGUF\` directory exists
  before the scenario starts.
- Blocked rule: empty `jinja-path.txt` or missing jinja file
  at scenario start is BLOCKED, not FAIL.

## 7. Handoff

Opens the next gate: Architect review of the MTP and jinja
follow-up scope. Architect confirms:

- Scope matches part-10 scope-expansion item A (now
  CAN-DESIGN-OUT per Manager D12).
- Jinja extraction contract is consistent with the gguf
  metadata format and the Adopted Jinja Boundary Interface.
- Multi-session report paths are unique; per-scenario
  evidence dirs name the parent report.
- part-21 line count stays under 300 (the repo-wide
  split-when-over-300 rule from document-index.md).
- part-21a carries the execution details that exceeded the
  300-line budget.

Next gate: Manager approval, then QA execution.

Cross-references:

- Matrix: [part-18](part-18-stage12-stress-benchmarks.md)
- Operational: [part-18a](part-18a-stage12-operational.md)
- Automation: [part-19](part-19-stage12-test-automation.md)
- Closure: [part-07](../../cache-handling-phase12-implementation/part-07-stage12-closure-decision.md)
- Design: [part-10](../../cache-handling-phase12-design/part-10-stage12-scope-expansion-design.md)
- Execution details: [part-21a](part-21a-stage12-mtp-jinja-execution.md)
- Architecture (Jinja boundary interface): [../cache-handling-architecture/part-02](../cache-handling-architecture/part-02-restore-and-residency-flow.md)
