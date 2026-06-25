# Stage 25 design: Part 7: risks and open questions

Source: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)

This part lists the implementation risks, the open design questions
that need user clarification, and the residual risks that the
design accepts as documented tradeoffs.

## Risks

| ID | Risk | Severity | Mitigation |
| --- | --- | --- | --- |
| R-25-01 | Cold-promote latency on the slot critical path increases p99 latency for cold-dominated workloads. | high | Estimate via Part 4 numbers; verify with implementation evidence; if regression exceeds 50% on the Qwen3.5-4B MTP fixture, propose worker retirement Option B and measure again. |
| R-25-02 | Inline demotion during `tx_save` extends the critical section by cold-store write latency. | medium | Bound by the same mutex; cold-store write is dominant. Add demotion-latency histogram so p99 is observable per Part 4. |
| R-25-03 | Recursive mutex permits accidental reentrancy from future code that calls a private helper from outside a transaction. | medium | `tx_assert_mutex_held` helper fails a debug assert and a release diagnostic. Document the inner-call set in Part 2. |
| R-25-04 | Stage 24 S03 silent crash (D-EXEC-24-03) may reappear or change shape under the synchronous model. | medium | Stage 25 evidence must include a fresh S03 run. If the crash reproduces, escalate per D-CLOSURE-24-01 follow-up (b). The synchronous model removes async races but does not fix the underlying cold-store write + memory pressure failure. |
| R-25-05 | Lock contention on a high-parallel slot count (>16 parallel slots) increases wait time beyond the `transaction_wait_exceeded` threshold. | medium | The default 500 ms threshold is documented; tune per implementation evidence. The diagnostic is bounded and does not abort. |
| R-25-06 | Existing test hooks that rely on the worker thread completing after `enqueue_demotion` must be updated. | low | Documented in Part 5; tests assert on residency after `tx_*` returns, not on worker completion. |
| R-25-07 | Public Prometheus metric shape changes if internal counters leak. | low | Internal counters are debug-only and not exposed. Part 5 records the policy. |
| R-25-08 | Worker retirement Option A keeps a thread that is never used and confuses future readers. | low | Part 5 documents Option B as the cleaner alternative; Manager gate picks. |

## Open questions for user clarification

The following questions need user direction before implementation
planning can finalize. They are recorded here for the Manager design
gate.

### OQ-25-01: apply-step lock scope

`tx_restore` returns a plan and the slot thread applies the plan to
the live slot without holding the cache-state lock. After apply,
`tx_apply_restore` re-acquires the lock to finalize owner-view sync.
The user requirement states that all writes block until transaction
finished; does that mean the apply step itself must be inside the
transaction, or is the split (plan under lock, apply outside lock,
finalize under lock) acceptable?

Option A: split (current design). The plan is computed under lock.
Apply is outside lock because the slot thread owns the live
`llama_context` and apply can take non-trivial time. Finalize is
under lock.

Option B: full apply under lock. The slot thread holds the
cache-state lock for the entire `tx_restore` including apply. This
serializes inference-apply with other cache mutations, which may
add latency.

### OQ-25-02: worker retirement

Should `io_worker` thread be retired (Option B) or kept asleep
(Option A)? Option B is cleaner and removes the never-used thread;
Option A keeps the existing test scaffolding.

### OQ-25-03: timeout default

Default threshold for `transaction_wait_exceeded` diagnostic. The
design suggests 500 ms. The user may want a different default based
on operator visibility or p99 latency budget.

### OQ-25-04: reentrancy depth limit

Default reentrancy depth limit. The design suggests 4. Higher
values permit deeper nesting; lower values fail-fast on accidental
reentrancy.

### OQ-25-05: cold-store metric drift follow-up

The cold-store metric-vs-filesystem drift observed in Stage 24
(D-CLOSURE-24-01 c) is out of scope for Stage 25. The user should
confirm whether to keep this as a future observation or to fold it
into Stage 25 evidence.

### OQ-25-06: reentrancy helper API

Should the reentrancy counter be a thread-local on the controller
or a member of the slot thread context? The design assumes
thread-local on the slot thread. The user may want a different
placement for testability.

## Residual risks

The design accepts these tradeoffs without further mitigation:

- Throughput regression on cold-dominated workloads is bounded by
  the cold-store latency on the slot critical path. The user
  requirement is explicit: "all operations which requires cache
  modifications should be performed in atomic transactional mode".
  Throughput regression is the cost of the user's correctness
  requirement.
- The worker thread may remain idle (Option A) or be removed
  (Option B). Either is correct; the design does not depend on the
  choice.
- The Stage 24 S03 silent crash is not a Stage 25 bug. It is a
  separate investigation tracked under D-CLOSURE-24-01 follow-up
  (b). The synchronous model removes async races but does not
  diagnose the underlying Windows process termination.

## Handoff

Next owner: Manager for design gate. The Manager design gate must
record decisions on OQ-25-01..06 and either approve or rework the
design before implementation planning opens.
