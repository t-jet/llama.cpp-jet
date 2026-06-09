# Cache handling test plan - Part 21a: Stage 12 MTP and jinja execution details

Source: [part-21](part-21-stage12-mtp-jinja-test-plan.md)
Architecture (Jinja boundary interface): [../cache-handling-architecture/part-02](../cache-handling-architecture/part-02-restore-and-residency-flow.md)

## 1. Scope

This part carries the MTP-follow-up execution details that did
not fit under the 300-line rule in part-21: V2 jinja extraction
contract, input marking transformation rules, driver parameter
contract, and the multi-session execution plan. part-21 is the
overview, criteria, and handoff. Read this part alongside
part-21.

## 2. V2 jinja extraction step

For V2 only, the driver first verifies `chat_template.jinja`
and `chat_template_new.jinja` are present in
`._test_models\Qwen3-8B-GGUF\` and
`._test_models\Qwen3-0.6B-GGUF\`. Both files are present in
the local tree today, so the extraction step is skipped in
the first live V2 session. The extraction contract stays in
this section as the fallback path for future fresh checkouts.

If a `chat_template.jinja` is missing, the driver invokes the
gguf-py metadata reader to write it. The concrete tool is the
shared PowerShell helper at
`._design_docs/cache-handling-test-scripts/lib/Read-GgufChatTemplate.ps1`
(dot-sourced by all 19 base drivers). The helper invokes
`python gguf-py/gguf/scripts/gguf_dump.py --json --no-tensors
<gguf-path>`, parses the JSON, and walks to the
`metadata.tokenizer.chat_template.value` string field per
`gguf-py/gguf/constants.py:270` (Tokenizer.CHAT_TEMPLATE). The
earlier `llama-server --print-chat-template` fallback is removed
from this section because no such CLI flag exists in this build
(verified 2026-06-08, part-22 R1).

Step-by-step for a missing-file case:

1. Call `Read-GgufChatTemplate -GgufPath <gguf>` to obtain the
   raw chat template string from the `tokenizer.chat_template`
   metadata field.
2. Write the string to
   `JinjaDir/chat_template.jinja` (UTF-8, no BOM, LF line
   endings to match the existing template files).
3. Apply the 10-step Adopted Jinja Boundary Interface
   adaptation (architecture doc part-02 "How to Adapt a Test
   Jinja Template") to produce the marked variant.
4. Write the adapted string to
   `JinjaDir/chat_template_new.jinja` alongside the original.
5. Record the extraction event in the per-scenario evidence
   summary under the `V2 jinja extraction` heading: tool
   used, gguf source path, written file paths, and a byte
   count for the original render to confirm completeness.

QA verifies the byte-for-byte round trip in step 10 of the
adaptation: render both the original and adopted template
with all markup flags unset and confirm the bytes match.
The original extraction event is recorded once per session,
not per sub-run, so the V2 session has one extraction record
covering all 38 sub-runs. The helper itself is the lib-level
entry point; the same helper exposes `Resolve-MtpJinjaPath`
(for the MtpVariant to absolute file path step) and
`Merge-MtpJinjaFlag` (for the `--chat-template-file` flag
augmentation), both used by all 19 base drivers.

## 3. Input marking interpretation

Input marking is a private test-harness feature defined by the
Adopted Jinja Boundary Interface in
[cache-handling-architecture/part-02](../cache-handling-architecture/part-02-restore-and-residency-flow.md#adopted-jinja-boundary-interface).
The marked template renders byte-for-byte identically to the
original when `emit_cache_boundaries` is unset or false, and
emits a markup header plus boundary markers when
`emit_cache_boundaries=true`. The marker is not a security
boundary and is not part of the public surface.

Concrete transformation rules the adopted test template
follows:

- Define `template_markup = namespace(features=[])` near the
  top of the file before any `{% macro %}` block.
- Define a `cache_mark(kind, label='')` macro that emits the
  boundary marker only when `emit_cache_boundaries` is true.
  Otherwise the macro renders empty string.
- When `emit_cache_boundaries=true`, append the feature spec
  `cache_boundary=1` to `template_markup.features`.
- Emit `<|template_markup:v1:cache_boundary=1|>` as the first
  rendered bytes when `template_markup.features` is non-empty.
  The protocol version `v1` is fixed; the feature list is
  comma-separated.
- Wrap each rendered span with
  `cache_mark(kind, label)`:
  - `system_start` and `system_end` around system or developer
    setup content (also wrapped by `message_*` per
    architecture rule 6).
  - `message_start` and `message_end` around each rendered
    chat message. Label is the rendered role.
  - `tool_call_start` and `tool_call_end` around each
    assistant tool-call span. Label is the tool name when
    available.
  - `tool_response_start` and `tool_response_end` around each
    tool-response span.
  - `media_start` and `media_end` around each image or video
    placeholder span.
  - `generation_prompt_start` and `generation_prompt_end`
    around the assistant generation prefix added by
    `add_generation_prompt`.
- When `emit_cache_boundaries` is false or unset, the adopted
  template must render the same bytes as the source template.
- The cache adapter recognizes the header and the boundary
  markers, treats them as untrusted metadata, and excludes
  them from the cache key and from any public diagnostic or
  metric label.

QA records both variants and compares the rendered request
body to confirm the only delta is the marker lines. The
existing `chat_template_new.jinja` files in the test-model
tree are the reference adaptations; V2 extraction in
section 2 produces a fresh adaptation only when the local
copy is missing.

## 4. Driver parameter contract

The 19 base scenario drivers (S12-S01..S08, S12-B01..B08,
S12-L01..L03) accept two new parameters:

- `-MtpVariant {0|1|2|3}`: 0 means no MTP variant (existing
  scenario, used by the non-MTP re-run session). 1, 2, 3
  select V1, V2, V3 respectively. Default 0.
- `-JinjaVariant {original|marked}`: selects the jinja file
  per part-21 section 4. Required for every Stage 12 MTP
  follow-up run; driver fails fast if omitted. No default
  value.

`jinja_path` is auto-resolved from `-MtpVariant`,
`-JinjaVariant`, and the model dir per part-21 section 4
before the scenario starts. The driver writes the resolved
absolute path to `jinja-path.txt` in the per-scenario evidence
dir so QA can confirm provenance. The same parameter set
applies to all 19 base drivers; per-driver variant logic is
not permitted. The harness inventory in part-19 section 7.1
records the same parameters on the automation side.

## 5. Multi-session execution plan

Four sessions, one fresh test report file per session. Each
session runs one MTP variant (or the non-MTP re-run) across
all 19 base scenarios and both jinja variants. The session
suffix is chosen before the first sub-run starts so per-
scenario evidence dirs name the parent report. Session
breakdown:

- V1: report file
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-V1.md`
- V2: report file
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-V2.md`
- V3: report file
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-V3.md`
- non-MTP re-run: report file
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-non-mtp.md`

Per-scenario evidence dir layout, identical for all four
sessions:

```text
._design_docs/.test_reports/mtp-jinja-run-YYYYMMDD-NN/
    S12-MTP-{base}-V{V}-J{original|marked}/
        server.out.log
        server.err.log
        metrics-before.txt
        metrics-during.txt
        metrics-after.txt
        resource-samples.csv
        baseline.json
        evidence-summary.md
        mtp-variant.txt
        jinja-variant.txt
        jinja-path.txt
        (additional files per base scenario, e.g.
         precondition.log for S12-S08, k6-results.json for
         S12-B01 and S12-B06)
```

Per-row wall-clock budget per session:

- Stress rows (S12-S01..S08): full 30-minute budget from
  part-18. No stress row is reduced in any session.
- Bench rows (S12-B01..B08): 1-minute reduced bench per
  simple-fix #4 (closure follow-up item 4 in part-07).
- Long-run rows (S12-L01..L03): full duration in V1 and V3
  sessions (production-like multi-hour run under MTP load);
  reduced 1-minute budget in V2 and non-MTP sessions so the
  4 sessions stay bounded.

Each session is one continuous run; QA may pause between
sub-runs to record progress but does not restart the
session report mid-run. The V2 session also runs the
section 2 jinja extraction step once at session start, not
per sub-run.

## 6. Handoff

This part hands back to part-21 for the cross-reference list
and the next-gate handoff. The execution details in this
part are referenced by part-21 sections 4, 7, and 8.
