# Stage 32 QA focused retest 2026-06-30 02

VERDICT: PASS

## Scope and status

Focused retest after Architect fix re-review PASS in
`cache-handling-phase32-implementation/part-05-architect-fix-re-review-20260630.md`.
This run did not execute the full 180 minute comparison. It covered the
approved focused scope:

- clean Release CUDA configure and build proof;
- `test-cache-controller` direct run and `ctest -R cache`;
- short live hybrid `/v1/chat/completions` duplicate probe using the Stage 32
  Qwen3.5 MTP fixture and known duplicate group
  `r-0051,r-0059,r-0080,r-0109,r-0162,r-0187`;
- `/metrics` scrape before and after the probe;
- request-row reuse, hybrid hit-counter delta, namespace bound, metric-label
  shape, HELP/TYPE uniqueness, and server-log hygiene checks.

Artifact root:

```text
D:\source\llama.cpp-jet\_test_output\stage32-focused-retest-20260630-02
```

Live probe root:

```text
D:\source\llama.cpp-jet\_test_output\stage32-focused-retest-20260630-02\live-probe
```

Cold path:

```text
D:\tmp\cache-cold-stage32-focused-20260630-02
```

## Build and focused tests

| Gate | Verdict | Evidence |
| --- | --- | --- |
| Clean Release CUDA configure | PASS | `proof\configure.exit.txt` = 0; `proof\cuda-proof.txt` = `GGML_CUDA:BOOL=ON`. |
| Release build | PASS | `proof\build.exit.txt` = 0 for `llama-server` and `test-cache-controller`. |
| Binary proof | PASS | `proof\setup-env.json`: HEAD `96398cceca0c54ffe9fa2a016fbdba8811461bf1`; `llama-server.exe` UTC `2026-06-30T13:12:55.2703028Z`; controller UTC `2026-06-30T13:13:01.4812934Z`. |
| Direct controller | PASS | `proof\test-cache-controller.exit.txt` = 0. |
| `ctest -R cache` | PASS | `proof\ctest-cache.exit.txt` = 0; log reports `100% tests passed, 0 tests failed out of 1`. |

The build directory was deleted before configure, then rebuilt in Release with
`GGML_CUDA=ON`. No stale build evidence was used.

## Live duplicate probe

Command shape:

```text
llama-server.exe -m ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf --cache-mode hybrid --port 8933 -c 4096 --parallel 2 --cache-ram 512 --metrics --seed 42 --cache-cold-max-mib 2048 --cache-cold-path D:\tmp\cache-cold-stage32-focused-20260630-02
```

The request body came from the existing Stage 32 workload row `r-0051`. The
probe sent that same chat completion request six times.

| Check | Verdict | Evidence |
| --- | --- | --- |
| Request rows show reuse | PASS | `live-probe\requests.jsonl`: `cache_n` values `0,1911,1911,1911,1911,1911`; 5/6 rows have `cache_hit=true`. |
| Hybrid hit counter delta | PASS | `probe-summary.json`: `hits_before=0`, `hits_after=5`, `hit_delta=5`. |
| Namespace count bounded | PASS | `probe-summary.json`: `namespace_count=1`. |
| No public cache `namespace` label | PASS | `probe-summary.json`: `namespace_label_line_count=0`; `namespace-label-lines.txt` is empty. |
| HELP/TYPE unique | PASS | `probe-summary.json`: `help_type_duplicate_count=0`; `help-type-duplicates.json` is empty. |
| Server log hygiene | PASS | `probe-summary.json`: `forbidden_log_hit_count=0`; scan found no crash, exception, request error, `token_count_mismatch`, or `checksum_mismatch`. |

Probe summary:

```text
status=PASS
requests=6
cache_hit_rows=5
max_cache_n=1911
hit_delta=5
namespace_count=1
```

## Outcome

Focused Stage 32 retest PASS. The fixed chat usage parser records positive
request-row reuse on repeated exact chat requests, and the independent
`llamacpp:cache_hits_total{mode="hybrid"}` metric increased on the same run.
The aggregate metric label fix also held in live `/metrics`: no public cache
metric row used `namespace="all"` or any `namespace` label in the after scrape.

This report does not close the full Stage 32 long comparison. Per the Architect
handoff, a longer comparison rerun remains a Manager decision after focused
PASS.

## Handoff

Status: ready for Manager decision.

Next owner: Manager. Decide whether Stage 32 needs the full comparison rerun
now that the focused duplicate chat retest passed.
