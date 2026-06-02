# Stage 9 public checkpoint admission follow-up - 2026-06-02

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Prior review: [part-14-test-results-review-rerun-20260601.md](part-14-test-results-review-rerun-20260601.md)
Related report: [../.test_reports/test-report-20260601-06.md](../.test_reports/test-report-20260601-06.md)
Owner: Manager
Status: Developer follow-up required

## Scope

This note follows up on Q102 and Q103 after QA rerun report 20260601-06. The
goal was to find a test-side way to satisfy public checkpoint admission before
deciding whether the remaining blocker needed product work.

## Findings

The original `/completion` probe could not admit a checkpoint because its
prepared metadata exposed one full-prompt boundary, while the runtime checkpoint
covered the prompt minus the final four tokens. A 64-token prompt still failed:
the checkpoint span was 60 tokens and the only public boundary was 64 tokens.

A normal `/v1/chat/completions` request also failed. Qwen's rendered chat
template adds role markers before the user text, so inferred message boundaries
do not start at token 0. Stage 9 checkpoint admission requires a matching
boundary with `token_start == 0`, the checkpoint token span, and the same
checksum.

A custom public chat template did solve the admission precondition. The template
rendered the user message at the start of the prompt and added a four-token
generation suffix:

```jinja
{%- for message in messages -%}
{{- message.content -}}
{%- endfor -%}
{%- if add_generation_prompt -%}
 tail tail tail tail
{%- endif -%}
```

With the local Qwen3.5 MTP fixture and `--chat-template-file` plus `--jinja`,
a 60-token message rendered to a 64-token prompt. The message boundary covered
tokens 0..60 and matched the server's end-of-prompt checkpoint span. The first
request produced:

- `cache_checkpoint_admissions_total{mode="hybrid"} 1`
- `cache_checkpoint_admission_failures_total{mode="hybrid"} 0`
- MTP draft activity in response timings

Artifacts:

- `._test_output/cache-handling/followup-stage9-custom-template-probe/summary.json`
- `._test_output/cache-handling/followup-stage9-custom-template-probe/candidate-60.json`
- `._test_output/cache-handling/followup-stage9-custom-template-probe/server.err.log`

## Remaining blocker

The second identical public request selected the admitted checkpoint payload but
failed while applying the target state:

```text
state_seq_set_data: error loading state: failed to restore kv cache
try_restore - failed to restore target state
```

The likely cause is a flag mismatch between checkpoint export and hybrid
checkpoint restore. Live context checkpoints are created with
`LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY` in `server_context::create_checkpoint`.
The hybrid cache restore path applies checkpoint payload bytes with
`LLAMA_STATE_SEQ_FLAGS_NONE` in `hybrid_cache_controller::try_restore_from_cache`.
The older in-slot checkpoint restore path loads live checkpoints with
`LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY`.

This means prompt shaping can solve checkpoint admission, but it has not proven
Q102 or Q103. Q102 still lacks successful live checkpoint restore and hit metric
labels. Q103 still lacks model-backed checkpoint-first restore evidence.

## Decision

The follow-up found a test-side admission recipe, so the earlier blocker should
be narrowed. The remaining issue is no longer "public checkpoint admission" but
"public checkpoint restore fails after admitted checkpoint selection."

Next owner: Developer.

Recommended next action:

- Treat the custom-template probe as the public admission harness for Q102/Q103.
- Investigate the checkpoint restore apply flags before another QA rerun.
- If Developer confirms the flag mismatch, make a narrow product fix and rerun
  the custom-template public probe plus focused Stage 9 checkpoint tests.
