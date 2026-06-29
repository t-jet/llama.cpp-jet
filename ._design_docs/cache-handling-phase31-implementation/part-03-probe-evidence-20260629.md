# Stage 31 probe evidence 2026-06-29

Status: probes complete; production fix authorized
Owner: Developer

## Scope

This part records P31-01 through P31-05 before production behavior edits.
Full live server probes were not rerun because Stage 30 already produced a
200-request live hybrid artifact set, and the root-cause question is inside
`hybrid_cache_controller::compute_namespace_id()` plus metric emission. Focused
unit probes exercise the same namespace function and branch lookup paths with
deterministic metadata, while Stage 30 artifacts cover live metrics and workload
shape.

## Probe code

Temporary current-behavior probe tests were added to
`tests/test-cache-controller.cpp` and run before production edits:

- `test_stage31_probe_namespace_root_cause_current_behavior`
- `test_stage31_probe_namespace_explosion_current_behavior`
- `test_stage31_probe_workload_token_fixture`

Test-only accessor added:

- `hybrid_cache_controller::debug_compute_namespace_id_for_tests()`

## P31-01 zero-hit reproducer

Focused unit evidence:

- Exact A/A metadata produced identical namespace ids.
- Exact A/A lookup found 4 matching tokens after saving A.
- Near-prefix A/B metadata produced different namespace ids.
- Near-prefix B lookup returned no match before the fix because branch lookup
  searched a different namespace.

Conclusion: exact save/lookup parity works when metadata is byte-identical.
Near-prefix reuse is blocked by prompt-local namespace input before validation
can evaluate the safe shared prefix.

## P31-02 namespace explosion

Focused unit evidence:

- 20 requests under one model/config with one prompt-local checksum/span change
  per request produced 20 unique namespace ids.
- `branch_forest.namespaces` also contained 20 namespaces.

Conclusion: namespace cardinality follows prompt-local metadata, not stable
runtime compatibility.

## P31-03 workload token equality

Stage 30 source artifact:

- `_test_output/stage30-cache-modes-20260629-01/workload.jsonl`
- 200 rows: `exact=78`, `near_prefix=65`, `new_branch=57`.
- Source-message hashing found 22 duplicate rendered-source groups before
  tokenization. Examples: `r-0030,r-0130`; `r-0023,r-0151,r-0154`;
  `r-0010,r-0047`.

Focused token fixture evidence:

- Exact fixture token vectors matched fully.
- Near-prefix fixture shared the full anchor prefix and added suffix tokens.

Conclusion: the workload contains repeated exact source prompts and
near-prefix-shaped prompts. A full live tokenizer probe would be more direct,
but it is not needed to prove the namespace root cause because current
namespace splitting occurs from metadata spans/checksums after tokens exist.

## P31-04 save-vs-lookup namespace parity

Focused unit evidence:

- Same metadata snapshot gives identical save and lookup namespace ids.
- Changing only `preparation_id`/degraded reason from
  `rendered-text-boundary-inference` to `token-position-fallback` changes the
  namespace id.
- Changing only prompt-local span/checksum changes the namespace id.

`preparation_id` decision:

- Assignments traced in `server-context.cpp`: `rendered-text-boundary-inference`
  and `token-position-fallback`.
- Both name request mapping/fallback paths, not runtime compatibility ABI.
- Decision: keep `preparation_id` validation/diagnostic-only and remove it from
  namespace computation.

## P31-05 metrics shape

Stage 30 metrics artifact:

- `_test_output/stage30-cache-modes-20260629-01/cold-start-cycle-1/hybrid/metrics-after.txt`

Observed public metric defects:

- 12 metric names had duplicate HELP blocks.
- 12 metric names had duplicate TYPE blocks.
- `llamacpp:cache_branch_lookups_total`: 326 HELP and 326 TYPE blocks.
- `llamacpp:cache_namespace_nodes`: 163 HELP and 163 TYPE blocks.
- `llamacpp:cache_branch_traversals_total`: 3 HELP and 3 TYPE blocks.
- Raw numeric namespace labels: 163 on branch lookup metrics and 163 on
  namespace stat metrics.

Conclusion: metric writer shape and public label cardinality need production
fixes. Raw namespace ids can remain in stats JSON.

## Build evidence before production fix

Command:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
.\build\bin\Release\test-cache-controller.exe
```

Result:

- Release build passed.
- `test-cache-controller.exe` passed, including the three Stage 31 probes.
- Debug build without `--config Release` failed before test compilation in a
  pre-existing debug-only const-mutex check at
  `server-cache-hybrid.cpp:4601`; Release is the active evidence path.

## Root cause

The Stage 30 zero-hit and namespace explosion symptoms are explained by
`compute_namespace_id(metadata)` hashing validation-only prompt data:
`preparation_id`, degraded reason, boundary spans, checksums, and labels. This
splits compatible prompts into different branch namespaces. Save and lookup use
the same function, so exact repeats with identical metadata can match, but
near-prefix and fallback-mapped requests are hidden from validation by namespace
filtering.

Production fix may proceed with the minimal approved scope:

- namespace from stable runtime compatibility only;
- prompt-local metadata remains validation/diagnostic-only;
- metric HELP/TYPE emitted once per metric name;
- public namespace/branch labels bounded;
- Stage 30 wording corrected or linked from durable docs.
