# Phase 6 design: cold layer and asynchronous I/O - Part 4: Async I/O worker design

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Thread model

`server_cache_io_worker` runs as a single background thread owned by the hybrid cache controller. It starts when the controller is initialized with a cold store configured, and it stops cleanly when the server shuts down.

The thread lifecycle is:

1. The controller calls `start()`. The worker allocates its queue, starts the thread, and returns. If startup fails (for example, thread creation error), the controller must fail the cold store configuration and treat the server startup as a budget validation failure.
2. During operation, the worker thread waits on its queue. When a task arrives, the worker executes it (demotion write or promotion read), then calls the completion callback.
3. On shutdown, the controller calls `stop()`. The worker finishes any task in progress, drains remaining tasks by calling each with a cancelled failure result, then exits the thread. The controller joins the thread before releasing any resources the worker references.

The worker thread does not hold any lock owned by `server_context`. All communication from `server_context` to the worker is through the bounded work queue. All communication from the worker back to `server_context` is through completion callbacks placed onto a result queue that `server_context` polls or drains at safe scheduling points.

## Work queue design

The work queue is bounded. Its capacity must be defined by the implementation and must be documented as a tunable constant. A recommended default is a queue depth sufficient to absorb burst demotion requests from a single eviction cycle without blocking, typically in the range of 16 to 64 entries.

Queue entries hold:

- task type: `demotion` or `promotion`
- `payload_id`
- for demotion: a copy of or pointer to the payload bytes to write (ownership rules below)
- for promotion: the `cold_ref` and a descriptor snapshot for validation
- completion callback

Ownership of payload bytes for demotion tasks: when the controller enqueues a demotion, it must either copy the bytes into the queue entry or transfer ownership such that the hot store will not release them until the worker signals completion. The preferred approach is to transfer the byte buffer ownership to the queue entry. The controller marks the descriptor as `demoting` and does not release the hot record until the worker calls the completion callback.

If the queue is full when the controller tries to enqueue:

- For demotion: the controller treats this as a demotion failure. It may retry at the next eviction cycle, or it may evict the payload immediately by marking it as `evicted` and releasing the hot bytes. Eviction without demotion must emit a diagnostic.
- For promotion: the controller treats this as a promotion failure. The current request falls back to the slower path. The descriptor remains `cold` and may be promoted by a future request.

## Completion notification

The completion callback signature must carry:

- `payload_id`
- task type
- success flag
- on failure: a `failure_reason` enumeration value

The callback is called from the worker thread. The controller must not assume it is called from the `server_context` thread.

The controller may handle completion by posting a result to an internal result queue and draining that queue at safe `server_context` scheduling points. This keeps descriptor state mutations on the `server_context` thread without requiring locking of descriptors.

Alternatively, if the controller uses fine-grained locking per descriptor, the callback may update the descriptor's `residency_state` directly under that lock. This approach must be documented in the implementation and must not lock any resource that is also held by `server_context` during normal request processing.

Both approaches are permitted by this design. The implementation must choose one and document it.

## Locking model

| Resource | Owner | Lock scope |
| --- | --- | --- |
| Work queue | `server_cache_io_worker` | Short mutex + condition variable. Held only to enqueue, dequeue, or signal. |
| Descriptor registry | Hybrid cache controller | `server_context` thread in the preferred model. If the callback model allows cross-thread updates, a per-descriptor or per-registry lock is required. |
| Hot payload store | Hybrid cache controller | `server_context` thread. Never held while waiting for I/O. |
| Cold files | Filesystem | No application-level lock. Atomic rename ensures visibility safety at creation. Deletion is called only from the controller after the descriptor is `evicted`. |

The `server_context` thread must never block on:

- cold file writes
- cold file reads
- the work queue when it is full (fail-fast, not block)
- the worker thread join (join happens only at shutdown)

## Error handling and retry policy

The worker retries a task at most once per enqueue if the failure reason is a transient OS-level error (such as a temporary filesystem unavailability or a write interrupted by a signal). The retry uses the same queue entry and does not require re-enqueue.

The worker does not retry on:

- checksum mismatch
- format version mismatch
- `payload_id` mismatch
- file not found (for promotion)
- insufficient disk space (for demotion)

For demotion, a non-retryable failure leaves the payload bytes in limbo. The controller must handle this by either retaining the hot bytes and reverting the descriptor to `hot`, or accepting that the bytes are gone and marking the descriptor `evicted`. The implementation must document which path it takes and must emit a diagnostic either way.

For promotion, a non-retryable failure marks the descriptor `evicted`. The cold file may be left for operator inspection or removed. The cold file must not be removed silently; removal should be logged.

## Worker shutdown race

If a task is in progress when `stop()` is called, the worker completes the in-progress task before joining. This prevents the cold file from being left in an incomplete staging state.

Tasks that are queued but not started when `stop()` is called receive a cancelled failure callback. The controller must handle the cancelled result as a failure for each task type: cancelled demotions revert or evict; cancelled promotions leave descriptors `cold`.

If the controller has already released hot bytes for a cancelled demotion, it must mark the descriptor `evicted` rather than reverting to `hot`, because the hot bytes no longer exist.

## Interaction with `server_context` thread

`server_context` interaction with the worker falls into three categories:

1. Enqueue at eviction time: controller calls `enqueue_demotion` during the LRU eviction cycle.
2. Enqueue at restore time: controller calls `enqueue_promotion` when a cold descriptor is selected as a restore candidate.
3. Process completions: controller drains the result queue (or processes callbacks) at safe scheduling points before or after request processing.

The controller must process pending completions before selecting new eviction or restore candidates. This ensures that recently demoted or promoted descriptors have up-to-date `residency_state` before they are re-evaluated by the policy.
