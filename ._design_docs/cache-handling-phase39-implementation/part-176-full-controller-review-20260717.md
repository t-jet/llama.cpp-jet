# Part 176: full controller review

Date: 2026-07-17
Status: REWORK REQUIRED
Scope: Stage 39 controller/design implementation review before another Manager rerun gate

## Verdict

REWORK. Part 175 correctly ports `test-step7-promotion-protocol` to the current
synchronous controller API. It does not hide a product regression. The product
header and implementation still define promotion as inline synchronous work, not
as queued worker completion:

- `tools/server/server-cache-hybrid.h:383` records the Stage 25 transaction
  model under `cache_state_mutex_`.
- `tools/server/server-cache-hybrid.h:428` says `process_completions` was
  removed and demotion/promotion now run synchronously.
- `tools/server/server-cache-hybrid.cpp:782` and `:837` run
  `promote_payload()` through an inline cold-store read and immediate
  `handle_promotion_completion()`.
- `tools/server/server-cache-hybrid.cpp:5498` and `:5545` do the same in
  `tx_promote_payload()` under the recursive transaction lock.
- `tests/test-step7-promotion-protocol.cpp:193` and `:239` now assert immediate
  hot residency and retire the obsolete queue-full path.

However, the broader Stage 39 controller proof is not ready for another rerun.
The C++ terminal-proof predicate still ignores the three component
forbidden-effect fields added after D39-QA-05.

## Finding F176-01: C++ terminal matrix does not reject component forbidden effects

Blocking.

Part 167 says the controller matrix requires one selected component delta, zero
siblings, aggregate one, and terminal rejection. Part 168 accepts that claim.
Current code does not implement it.

Evidence:

- `tools/server/server-cache-hybrid.cpp:6178` through `:6185` derive
  `later_kind_work_delta`, `post_abort_pressure_delta`,
  `post_abort_diagnostic_delta`, and their `later_work_delta` sum.
- `tools/server/server-cache-hybrid.cpp:6256` through `:6267` serializes the
  three component fields in `terminal_state.forbidden_effects`.
- `tests/test-cache-controller.cpp:5346` through `:5358` defines
  `stage39_terminal_forbidden_effects_clear()`, but the checked key list omits
  `later_kind_work_delta`, `post_abort_pressure_delta`, and
  `post_abort_diagnostic_delta`.
- `tests/test-cache-controller.cpp:5363` through `:5367` runs negative probes
  only for the older seven fields. It does not set or verify the three
  component fields.
- The route driver is stricter: `stage39-two-layer-pressure.ps1:431` through
  `:444` requires all three component fields to exist and equal zero.

This leaves the C++ controller proof weaker than the route proof and weaker than
the accepted Part 167/168 documentation. A future product change could set one
component counter nonzero while leaving aggregate `later_work_delta` wrong or
uninspected in the controller test path, and the C++ common predicate would not
catch the component field directly.

Required correction:

- Add the three component fields to
  `stage39_terminal_forbidden_effects_clear()`.
- Add focused C++ negative probes for `later_kind_work_delta`,
  `post_abort_pressure_delta`, and `post_abort_diagnostic_delta`.
- Prove each negative reaches the named production helper after baseline and
  midpoint abort, rejects through the common terminal predicate, and leaves
  product state unchanged.
- Rerun the seam-ON controller build and `test-cache-controller.exe`.
- Update Part 167 or add a small correction part so the durable evidence matches
  the implemented C++ matrix.

Manager must not authorize another canonical TP-39-03 rerun until this is
fixed and reviewed.

## Non-blocking review notes

The repeated QA failures do not point to a product mismatch in the synchronous
transaction model. QA-07 failed in a stale test target before parser, pure,
model, or coverage work. Part 175's test-only port matches the current API and
the Stage 25/28 transaction direction.

The route driver's signed LRU and active-reference expectations match the
current terminal route shape. `stage39-two-layer-pressure.ps1:347` through
`:374` treats hot-LRU removal as signed `-1` while requiring retained lookup,
branch, cold exact bytes, and active referenced resident bytes. This is
consistent with the QA-05 raw terminal state, which had cold exact retention,
zero hot-LRU membership, one active referenced entry, and retained source
resident bytes above budget.

The route driver's forbidden-effect contract also matches the post-QA-06 driver
correction. `stage39-two-layer-pressure.ps1:431` through `:444` expects
classification and checkpoint descriptor/link mutation from the legitimate
step-2 checkpoint eviction, while requiring zero later-work components. That is
the right split between required checkpoint work and forbidden post-abort work.

I did not find evidence that the hot/cold two-layer retention policy, exact
ownership, checkpoint ownership, active-reference accounting, or route startup
assumptions need a new design correction. The open issue is the C++ controller
negative matrix and durable evidence mismatch above.

## Handoff

State: re-review required.

Developer owns F176-01. After the C++ controller matrix and evidence are fixed,
Architect must re-review before Manager considers another D39-QA-07 rerun gate.
Coverage remains blocked until canonical TP-39-03 reaches full `Assert-Tp3903`
PASS under the approved sequence.
