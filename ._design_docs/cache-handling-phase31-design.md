# Stage 31 design: hybrid cache Stage 30 misbehavior investigation

Status: closed; Manager closure PASS 2026-06-29
Date: 2026-06-29
Stage: 31 (Hybrid cache misbehavior after Stage 30)
Owner: Architect
Current gate: closed
Branch: work-branch

## Review status

- [Design review 2026-06-29](./cache-handling-phase31-design/part-01-design-review-20260629.md): PASS. No blocking or non-blocking findings remain open.
- [Manager closure 2026-06-29](./cache-handling-phase31-implementation/part-06-manager-closure-20260629.md): PASS.

## Intake

Stage 31 investigates a Stage 30 finding, not a new cache feature. Stage 30
showed that hybrid mode bounded hot RAM and wrote cold payloads, but it also
showed zero cache hits and unexpectedly high namespace cardinality in one
hybrid server process.

Inputs:

- `._design_docs/.manager-inputs/manager-input-20260629-stage31-hybrid-cache-misbehavior.md`
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-graph.h`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`

## Observed symptoms

Stage 30 cold hybrid leg completed 200 requests in one server process. The
after-run metrics showed:

- `llamacpp:cache_hits_total{mode="hybrid"} = 0`
- `llamacpp:cache_misses_total{mode="hybrid"} = 200`
- `llamacpp:cache_restore_misses_total{reason="exact_entry_absent"} = 200`
- `llamacpp:cache_checkpoint_admissions_total{mode="hybrid"} = 200`
- `llamacpp:cache_checkpoint_hits_total = 0`
- `llamacpp:cache_namespace_count{mode="hybrid"} = 163`
- 200 branch nodes across 163 namespaces
- 163 raw namespace labels in `llamacpp:cache_branch_lookups_total`
- no namespace validation failures and no token/checksum validation mismatches

The Stage 30 report called the zero hits "cold start, no hits yet". That
wording is incomplete. A cold server can still get in-cycle hits when the same
request stream contains exact repeats after the first occurrence.

## Scope

In scope:

- HTTP request to prepared prompt metadata construction.
- Namespace computation and branch graph save/lookup behavior.
- Stage 29/30 workload class truth at token level.
- Public Prometheus metric shape and cardinality.
- Focused probes that reproduce the issue without the full comparison run.
- Durable correction to Stage 30 report wording or a follow-up note that
  records the exact-repeat caveat.

Out of scope:

- Re-running the full Stage 30 comparison before root cause is known.
- Changing production behavior before Developer writes an implementation plan.
- Treating prompt similarity or response-cache behavior as the same problem as
  KV-cache branch reuse.

## Request-to-graph trace

1. HTTP route parses request JSON in `server_routes`.
2. Chat-compatible requests render `prompt` and build `chat_messages`.
3. `server_context.cpp` tokenizes the rendered prompt into `server_tokens`.
4. `cache_metadata_for_request()` builds `prepared_prompt_metadata`.
5. Chat paths call `cache_metadata_from_chat_messages()`, which adds per-message
   boundaries plus `[0, token_end]` prompt boundaries with token checksums.
6. The server task carries both `task.tokens` and `task.prompt_metadata`.
7. Restore path calls `hybrid_cache_controller::tx_restore()`.
8. `tx_restore()` computes `lookup_namespace_id =
   compute_namespace_id(task.prompt_metadata)`.
9. Branch graph lookup searches `forest.find_nodes_by_token_span()` under that
   namespace, then searches checksum spans for boundaries with `token_start=0`.
10. Save path calls `hybrid_cache_controller::tx_save()` after processing.
11. `tx_save()` computes `namespace_id = compute_namespace_id(metadata)` and
    admits the saved entry into the same branch forest.
12. `branch_forest_index` only matches nodes whose `node.namespace_id` equals
    the lookup namespace.

Current risk: `compute_namespace_id(const prepared_prompt_metadata &)` appends
every boundary type, token span, checksum, and boundary metadata before hashing.
This makes the namespace depend on prompt content. Exact repeats can still
match, but near-prefix reuse and cross-prompt branch reuse cannot share a
compatibility namespace. The Stage 30 163-namespace count for 200 requests is
consistent with prompt-local namespace input.

## Namespace decision

Compatibility namespace must describe runtime compatibility, not prompt
identity. If reuse should cross prompts in the same model/config, namespace
must not include request-local boundary spans or boundary checksums.

Allowed namespace inputs:

- model path/hash and model parameters
- draft/MTP context mode and draft model identity
- tokenizer and chat template identity
- LoRA adapters, control vectors, and multimodal projector identity
- `n_ctx`, `n_batch`, KV-unified state, and workload profile
- stable metadata ABI key such as `metadata.compatibility_key`

Validation-only inputs:

- `prompt_boundary.token_start` and `token_end`
- boundary checksum values
- per-boundary metadata text such as role, tool name, or `"prompt"`
- prompt-local protected boundary flags
- diagnostic source and degraded reason text
- prompt token hashes or request body hashes

`preparation_id` needs a narrow decision in Developer planning. It may remain a
namespace input only if it names a stable preparation ABI, not a prompt-local
event. If it is used only to explain how a request was mapped, it should be a
validation or diagnostic field.

Validation still protects safety. Candidate restore must continue to compare
tokens, checksum spans, descriptor boundary metadata, pair state, payload kind,
and checkpoint boundary requirements before any slot mutation.

## Investigation probes

P31-01 zero-hit reproducer:
Run one hybrid server with cold path enabled. Send prompt A twice, then prompt B
that shares a long prefix with A. Expected current behavior: first A misses,
second A should hit if save/lookup parity works, B should at least produce a
prefix candidate under corrected namespace rules. If second A misses, focus on
save-vs-lookup parity or payload residency.

P31-02 namespace explosion probe:
Send 20 requests from one model/config with 5 exact anchors and 15 near-prefix
variants. Scrape `cache_namespace_count`, branch namespace stats, and branch
lookup namespace labels. Expected corrected behavior: a small bounded namespace
count, normally 1 for this fixture unless profile or runtime mode changes.

P31-03 workload token equality probe:
For Stage 29/30 `workload.jsonl`, render/tokenize each request through the same
server path used by completions. Record token vector hash, token count, and
first differing token for each `cache_class`. Exact rows must have repeated
token hashes after the first occurrence. Near-prefix rows must share a prefix
long enough to exercise branch lookup.

P31-04 save-vs-lookup namespace parity probe:
Add temporary or test-only diagnostics around `tx_save()` and `tx_restore()` for
request id, token hash, namespace id, preparation id, boundary count, first
prompt-span checksum, and workload profile. Exact repeats must show identical
save and lookup namespace ids. Save-only and lookup-only namespace values are a
blocking bug.

P31-05 metrics cardinality and HELP/TYPE probe:
Parse `/metrics` output from a focused run. Assert each metric name has one
HELP line and one TYPE line. Assert public labels for branch lookup and namespace
stats are bounded. Raw namespace ids may remain in debug JSON or redacted
diagnostics, but not in unbounded Prometheus label sets.

## Expected implementation surfaces

Likely production surfaces:

- `hybrid_cache_controller::compute_namespace_id(const prepared_prompt_metadata &)`
- tests or helpers that expose namespace computation under
  `LLAMA_SERVER_CACHE_TESTS`
- branch lookup stats in `record_branch_lookup()` and `get_stats()`
- Prometheus metric writers in `server_context.cpp`
- Stage 29 workload or analysis script for token equality evidence
- Stage 30 report wording correction or linked follow-up note

Likely test surfaces:

- focused C++ cache-controller tests for namespace parity and validation-only
  boundary behavior
- focused Prometheus writer tests for HELP/TYPE and bounded labels
- small PowerShell or Python probe that reads workload JSONL and records token
  equality through a live server

## Risks

- Removing prompt-local fields from namespace can expose unsafe candidates if
  validation is weak. Mitigation: keep token and checksum validation mandatory.
- Checkpoint-dependent profile may still require stricter admission than exact
  blob restore. Mitigation: test profile-specific restore and checkpoint hits.
- Metrics fixes can hide useful forensic detail. Mitigation: keep raw namespace
  detail in stats JSON or opt-in diagnostics, not high-cardinality Prometheus.
- Stage 29/30 workload labels may be wrong after chat templating. Mitigation:
  measure rendered token vectors, not source JSON shape.

## Regression test plan

TP31-01 exact repeat:
Two identical chat completions in one hybrid server process produce first miss,
second hit, stable namespace id, and `cache_n > 0` or restored-token evidence.

TP31-02 near-prefix:
Prompt B shares a long prefix with prompt A. It must search the same namespace,
report prefix candidate evidence, and either restore a safe checkpoint or reject
with bounded `unsafe_prefix_rejected` reason.

TP31-03 namespace isolation:
Changing model identity, tokenizer/template identity, draft/MTP mode, LoRA,
multimodal projector, `n_ctx`, or workload profile changes namespace. Boundary
checksum-only changes do not.

TP31-04 checkpoint-dependent profile:
With MTP or checkpoint-dependent fixture, checkpoint admission and restore use
the corrected namespace while descriptor boundary validation still rejects bad
checksum or bad boundary metadata.

TP31-05 bounded metrics labels:
`/metrics` has bounded branch lookup labels, bounded namespace stats labels, and
one HELP and one TYPE block per metric name.

TP31-06 Stage 30 report wording:
Durable docs must correct or qualify the Stage 30 statement that zero hits were
expected because the run was cold. The correction must say exact-repeat rows can
produce in-cycle hits and Stage 31 owns that investigation.

## Acceptance criteria

Design gate passes when:

- HTTP request to branch graph admission/lookup trace is documented.
- Namespace decision separates compatibility from validation-only prompt data.
- Minimal probes cover zero hits, namespace explosion, workload token equality,
  save-vs-lookup namespace parity, and metric shape.
- Expected implementation surfaces and risks are explicit.
- Regression tests cover exact repeat, near-prefix, namespace isolation,
  checkpoint-dependent profile, bounded metrics labels, and Stage 30 wording.
- Next owner can write Developer implementation planning without guessing root
  cause or changing production behavior first.

## Handoff

Next owner: none.

Next gate: closed. Developer planning, implementation, review, QA execution,
Developer test-results review, and Manager closure all passed on 2026-06-29.
