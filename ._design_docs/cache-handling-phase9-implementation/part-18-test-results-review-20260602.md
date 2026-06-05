# Stage 9 test-results review after public restore rerun - 2026-06-02

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
QA report: [../.test_reports/test-report-20260602-01.md](../.test_reports/test-report-20260602-01.md)
Fix review: [part-17-public-checkpoint-restore-fix-review-20260602.md](part-17-public-checkpoint-restore-fix-review-20260602.md)
Owner: Developer
Status: PASS

## Scope

This review covers QA report 20260602-01, the focused Stage 9 rerun after the
public checkpoint restore fix passed Architect review in Part 17.

Rows reviewed:

- Q102 PASS
- Q103 PASS
- Q110 PASS
- Q111 PASS
- Q112 PASS

QA also refreshed focused evidence for Q90-Q100 and Q104-Q108 through
`test-cache-controller`. This review does not reopen the full Stage 9 matrix
from report 20260601-06.

## Verdict

PASS.

No Stage 9 product bug, QA harness blocker, environment blocker, or accepted
public-evidence limit remains open from the focused rerun.

The prior Q102/Q103 blocker is closed. QA used the custom public chat template
from Part 15 with the local Qwen3.5 MTP fixture. The first request admitted a
checkpoint with no admission failures. The second identical request restored
from that checkpoint, reported checkpoint hit metrics, and still showed MTP
draft activity.

## Classification summary

| Row | QA status | Classification | Review decision |
| --- | --- | --- | --- |
| Q102 | PASS | Closed public metrics evidence | Public `/metrics` showed checkpoint admission, successful checkpoint restore, checkpoint hit labels, and generic cache hit labels. |
| Q103 | PASS | Closed model-backed restore evidence | The Qwen3.5 MTP run restored 60 cached tokens from the admitted checkpoint on the second identical chat request, with `draft_n=2` on both responses. |
| Q110 | PASS | Closed regression coverage | Stage 4-5 regression coverage passed through `test-cache-controller`. |
| Q111 | PASS | Closed metrics regression coverage | `test-step10-metrics` passed. |
| Q112 | PASS | Closed Stage 8 regression coverage | `test-step12-branch-graph` and `test-step13-stage8` passed. |

## Evidence checked

QA report 20260602-01 records a clean rebuild from a removed `build`
directory and then reran the focused regression targets:

- `ctest --test-dir build -C Release -R "test-cache-controller|test-step10-metrics|test-step12-branch-graph|test-step13-stage8" --output-on-failure`: PASS, 4/4 tests.
- `build\bin\Release\test-cache-controller.exe`: PASS, 60 tests.
- `build\bin\Release\test-step10-metrics.exe`: PASS.
- `build\bin\Release\test-step12-branch-graph.exe`: PASS.
- `build\bin\Release\test-step13-stage8.exe`: PASS.
- `pytest tools/server/tests/unit/test_cache_modes.py`: PASS, 3 passed and 1 xfailed.

The public Q102/Q103 probe used:

- Local fixture:
  `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Runtime flags: hybrid cache, `--spec-type draft-mtp`,
  `--spec-draft-n-max 2`, `--ctx-checkpoints 4`,
  `--checkpoint-every-n-tokens 64`, public chat completions, custom
  `--chat-template-file`, and `--jinja`.
- First response: `prompt_n=64`, `cache_n=0`, `draft_n=2`.
- Second response: `prompt_n=4`, `cache_n=60`, `draft_n=2`.

Public metrics after the repeated request included:

- `cache_checkpoint_admissions_total{mode="hybrid"} 1`
- `cache_checkpoint_admission_failures_total{mode="hybrid"} 0`
- `cache_checkpoint_restores_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_and_draft",result="success"} 1`
- `cache_checkpoint_hits_total{mode="hybrid",profile="checkpoint_dependent",payload_residency="hot",pair_state="target_and_draft"} 1`
- `llamacpp_cache_hits_total{mode="hybrid"} 1`
- `llamacpp_cache_misses_total{mode="hybrid"} 1`

The rerun also preserved artifacts under
`._test_output/cache-handling/test-report-20260602-01/`.

## Remaining findings

None.

The earlier Q102/Q103 evidence limit is resolved by model-backed public
evidence. The earlier readiness attempt on port 8142 is setup-only evidence; QA
discarded it because the readiness probe expected a startup MTP marker that this
build did not emit. The accepted rerun on port 8143 proved draft activity from
the response timings before using the second response as restore evidence.

## Next action

Next owner: Manager.

Recommended gate action:

- Accept report 20260602-01 as closing the focused Stage 9 public checkpoint
  restore rerun.
- Treat Q102 and Q103 as PASS, not accepted evidence limits.
- Proceed to Stage 9 closure review or manager closure decision.
