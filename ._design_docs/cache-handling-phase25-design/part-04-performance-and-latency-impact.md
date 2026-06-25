# Stage 25 design: Part 4: performance and latency impact

Source: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)

This part estimates the slot request latency and throughput impact
of moving every cache mutation into a synchronous transaction under
a single recursive mutex. Numbers are estimates for the Qwen3.5-4B
MTP fixture used in Stage 24 chat runs; final values come from
implementation evidence in a later stage.

## Slot request latency model

A slot request under the new model has three phases:

| Phase | Operations | Approximate duration today | Approximate duration after |
| --- | --- | --- | --- |
| Pre-acquire | `tx_restore`: plan + cold promote + owner-view sync | none for hot exact hits; async promote for cold | same; promote is now inline within the transaction |
| Core processing | slot thread owns `llama_context` for tokenize + prefill + decode | unchanged | unchanged |
| Post-release | `tx_save`: admit entry + attach payload + inline demotion if needed | admission sync; demotion async | both sync inside the transaction |

The critical sections are:

- `tx_restore` critical section: plan + cold promote. For a hot exact
  hit, the critical section is O(1) on the lookup path plus O(1) on
  the owner-view refresh. For a cold promote, the critical section
  adds the cold-store read latency, which is dominated by disk read
  and integrity check.
- `tx_save` critical section: admit + attach + inline demotion.
  The inline demotion adds the cold-store write latency, dominated
  by disk write and atomic rename.

Today the cold-store read and write run on the worker thread and the
slot thread returns before they complete. After Stage 25 they run on
the slot thread under the cache-state lock. This moves the cost
from "background" to "foreground".

## Concurrency model

Today the controller allows N concurrent slot threads, all of which
can call `save_slot`, `try_restore_from_cache`, or `load_slot`
without serialization against the worker thread or against
`update`. After Stage 25:

- Read-only lookup paths inside `tx_restore` are serialized through
  the same recursive mutex as write paths. The mutex is held for the
  duration of the cold promote when the lookup selects a cold
  payload.
- Write paths inside `tx_save` are serialized against other write
  paths and against read paths.
- The worker thread is repurposed to a synchronous helper invoked
  under the cache-state lock. No background thread races with the
  slot thread.

Concurrency is reduced from "N slot threads run in parallel; worker
thread runs in parallel" to "N slot threads run in parallel;
mutations serialize through the cache-state mutex; reads are
co-resident with writes". For workloads with rare cold restores and
small hot budgets the serialization cost is small. For workloads
with frequent cold restores and large cold budgets the cost is the
cold-store read latency per slot request.

Throughput regression estimate:

- Hot-only workload, no cold restores: 0% to 5% regression. The
  critical section is short (O(1) hash lookup plus O(1) owner-view
  refresh). The mutex itself adds a few atomic operations per
  request.
- Mixed workload, 10% cold restores: 10% to 20% regression. Each
  cold restore adds the cold-store read latency to the critical
  section. Other slot requests wait on the mutex for the duration
  of the cold read.
- Cold-dominated workload, 50% cold restores: 30% to 50%
  regression. Half the requests wait on the mutex while a cold read
  completes.

The Stage 24 chat S02/S03 runs use a 512 MiB hot budget and 512 MiB
cold budget on the Qwen3.5-4B MTP fixture. Most requests fit hot.
The expected regression for S02 is 0% to 5%. The expected
regression for S03 is 5% to 10% because the chat workload promotes
cold entries more frequently.

## Memory pressure profile

Today the controller tolerates hot-budget overage because the
worker drains demotions asynchronously, freeing hot bytes as
worker completions arrive. After Stage 25, demotion is inline
inside the transaction. Hot-budget overage is tolerated only inside
the transaction window: the slot thread may temporarily exceed the
hot budget by the bytes of the entry being admitted, then drops
back below as the inline demotion completes.

If the inline demotion itself adds bytes to the cold budget, the
transaction calls `tx_cold_budget_make_room` first, which may
trigger cold eviction of unprotected cold payloads. The eviction
runs under the same lock, so the order is well-defined: cold
eviction, then admission, then inline demotion.

## Latency histogram impact

The cold promotion latency histogram (eight buckets, 0-1ms through
1s+) is preserved. The histogram is updated at the end of
`tx_promote_payload` instead of inside
`handle_promotion_completion`. The buckets do not change. The
distribution shifts toward the higher buckets because the cold read
is on the slot thread's critical path.

The cold demotion latency histogram (if any) is added at the end of
`tx_demote_payload`. Stage 6 does not currently track demotion
latency. Stage 25 adds a small histogram to surface demotion cost
on the slot critical path.

## Determinism and jitter

Mutex serialization adds jitter on the slot critical path: a slot
thread that needs a cold promote may wait for another slot thread's
cold promote to finish. Today the worker handles cold promotes in
FIFO order on the worker thread, so the slot thread is not blocked.

For workloads with rare cold restores the jitter is small. For
workloads with frequent cold restores the jitter is the cold-store
read latency variance. The implementation planning must capture
p99 latency on the Qwen3.5-4B MTP fixture before and after Stage
25 to verify the regression estimate.

## Throughput regression estimate summary

| Workload | Hot budget | Cold budget | Estimated regression |
| --- | --- | --- | --- |
| Hot-only chat (S02) | 512 MiB | 512 MiB | 0% to 5% |
| Mixed chat (S03) | 512 MiB | 512 MiB | 5% to 10% |
| Cold-dominated synthetic | 256 MiB | 4 GiB | 30% to 50% |

Final values come from implementation evidence on the Stage 24
chat fixture and on a synthetic cold-dominated fixture.
