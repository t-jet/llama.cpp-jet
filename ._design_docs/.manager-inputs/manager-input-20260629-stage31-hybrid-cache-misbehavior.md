# MANAGER INPUTS - NOT AN APPROVED DESIGN

## Stage 31 intake brief: Hybrid cache misbehavior after Stage 30

This is a Manager intake brief, not an approved design. Stage 31 opens because
the Stage 30 run produced symptoms that contradict the intended hybrid cache
reuse model.

## User directive

Open a new stage to analyze the Stage 30 run and investigate zero cache hits,
the large namespace count, and other hybrid cache misbehaviors.

The user supplied a Prometheus excerpt where
`llamacpp:cache_branch_lookups_total` had many numeric `namespace` label values
in hybrid mode. The user reported about 170 namespaces in total.

## Stage goal

Find why the Stage 30 hybrid run produced no cache hits and many namespaces,
then decide whether the fix belongs in namespace computation, prompt metadata,
branch graph admission and lookup, metric emission, the comparison workload, or
the Stage 29/30 test driver.

The stage is investigation-first. Do not change production behavior until the
root cause is documented and reviewed.

## Source evidence

- Stage 30 report:
  `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`
- Stage 30 run root:
  `_test_output/stage30-cache-modes-20260629-01/`
- Hybrid cold-cycle metrics:
  `_test_output/stage30-cache-modes-20260629-01/cold-start-cycle-1/hybrid/metrics-after.txt`
- Hybrid cold-cycle requests:
  `_test_output/stage30-cache-modes-20260629-01/cold-start-cycle-1/hybrid/requests.jsonl`
- Stage 29 design and implementation docs reused by Stage 30:
  `._design_docs/cache-handling-phase29-design.md`
  and `._design_docs/cache-handling-phase29-implementation.md`

## Manager evidence snapshot

These values were read from the Stage 30 run artifacts on 2026-06-29:

- Branch: `work-branch`
- Hybrid cold cycle requests: 200
- `llamacpp:cache_hits_total{mode="hybrid"}`: 0
- `llamacpp:cache_misses_total{mode="hybrid"}`: 200
- `llamacpp:cache_restore_misses_total{reason="exact_entry_absent"}`: 200
- `llamacpp:cache_checkpoint_admissions_total{mode="hybrid"}`: 200
- `llamacpp:cache_checkpoint_hits_total`: 0
- `llamacpp:cache_namespace_count{mode="hybrid"}`: 163
- Unique namespace labels in `cache_branch_lookups_total`: 163
- `cache_branch_lookups_total` sample lines: 978 total, 163 `token_span`
  namespace series and 163 `checksum_span` namespace series
- `cache_namespace_nodes` sum: 200 nodes across 163 namespaces
- Namespace node distribution: 141 namespaces with 1 node, 11 with 2 nodes,
  9 with 3 nodes, 1 with 4 nodes, 1 with 6 nodes
- `cache_validation_mismatches_total`: 0
- `cache_namespace_validation_failures_total`: 0
- Hybrid `requests.jsonl`: all first sampled rows have `cache_n=0` and
  `cache_hit=false`

## Initial hypotheses to test

H31-01: `compute_namespace_id(const prepared_prompt_metadata & metadata)`
includes request-specific metadata fields, especially boundary checksums and
token spans, so repeated model/config traffic is split across many namespaces.

H31-02: Stage 30 cold-start status hid a reuse failure. The exact workload mix
contains 78 exact rows, so a 200-request cold cycle should still produce some
in-cycle reuse if the generator repeats full prompt tokens within the same
server process.

H31-03: Branch graph lookup metrics have a cardinality bug. The `/metrics`
writer emits one series per namespace for both lookup methods and repeats HELP
and TYPE blocks for every series, making Prometheus output much larger than
needed even if the underlying namespace count were valid.

H31-04: Checkpoint admission works but restore never searches the same
namespace because save and lookup use different metadata snapshots.

H31-05: The Stage 29/30 workload labels `exact`, `near_prefix`, and
`new_branch` may not match token-level equality after chat templating, MTP
headers, or prompt generation changes.

## Active gate

Design.

The next owner should produce a Stage 31 design/investigation plan that:

- traces namespace inputs from request metadata to branch graph admission and
  lookup;
- compares generated workload classes with actual token equality;
- explains whether 163 namespaces is product behavior, metric behavior, or
  workload behavior;
- defines focused probes or unit tests before any production fix;
- gives acceptance criteria for cache hits, namespace count, and metric
  cardinality.

## Current owner

Architect, then Developer if the design review passes.

