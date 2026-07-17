VERDICT: REWORK

# Part 166: Architect D39-QA-05 fix review

Date: 2026-07-17
Scope: Part 165, report 20260717-05 fixes, guarded C++ seam, controller tests, and driver assertion

## Review result

The three counters are default-OFF and sit at the intended production helper
boundaries. Each hook increments while `cache_state_mutex_` is held and returns
before checkpoint-kind, post-abort pressure, or post-abort diagnostic work.
The pre-apply baseline and terminal sum have the right scope. Normal TP-39-03
source LRU removal changes generation without changing `later_work_delta`, so
generation span and forbidden-work evidence are now separate. No production
policy or default build behavior changed.

One test-evidence blocker remains.

## Finding

| ID | Severity | Finding | Required correction |
| --- | --- | --- | --- |
| F166-01 | BLOCKING | `stage39_capture_prepared_baseline_locked()` consumes `stage39_forbidden_effect_probe_` and increments the three members directly. `test_stage39_live_pressure_observed_later_work_probes()` selects those strings and checks only the summed `later_work_delta`. The negatives never enter `mark_payload_kind_evicted(checkpoint)`, `evict_until_within_budget()`, or `record_branch_metadata_pressure()` after the abort latch. They would still pass if any production-boundary increment were removed or moved. The aggregate assertion also does not prove that only the intended component counter changed. | Make each negative traverse its named production helper after the latch and after the baseline. Assert its component delta is exactly one, the other two are zero, summed `later_work_delta` is one, and the shared terminal matrix rejects the proof. Keep the successful LRU case at generation span one and summed later work zero. |

Direct member injection is valid for testing terminal-matrix rejection, but it
does not prove that production-boundary observation is wired. The accepted
counter fix requires both properties.

## Static checks

- `mark_payload_kind_evicted()` counts checkpoint entry after a prepared abort
  and returns before payload lookup, classification, demotion, or unlink.
- `evict_until_within_budget()` counts entry after abort and returns before
  planning, victim processing, warning, or branch-pressure diagnostics.
- `record_branch_metadata_pressure()` counts entry after abort and returns
  before gauge, warning, or log work.
- Baselines capture all three counters before `tx_update()`. Finalization sums
  monotonic deltas under the same recursive controller mutex.
- The successful signed-LRU test proves `final_generation ==
  common_sync_generation + 1` and `later_work_delta == 0`.
- PowerShell keeps the terminal zero assertion. No driver, fixture, budget,
  threshold, model, coverage, or product-policy change is needed.

## Handoff

Developer owns F166-01. Run only the focused seam controller and PowerShell 7/5
parser and pure checks after correction. Fresh Architect re-review remains
required. Canonical TP-39-03 and coverage stay blocked.
