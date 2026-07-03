# Stage 34: Architect independent review of concurrent reuse structural finding

## Header

- Status: Active
- Date: 2026-07-01
- Stage: 34 (reopened)
- Owner: Architect
- Active gate: Architect design review of Developer structural finding (TP-34-CC)
- Branch: work-branch
- Source claim: `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260701-01-stage34-reopen-live-small-cache4g-fixes.md`

## Skill-load confirmation

Skill-load complete. Read the four required files in order at session start: (1) `.agents/skills/self-improvement/SKILL.md`, (2) `.agents/skills/self-improvement/assets/architect.md` (applied every Condition/Action entry), (3) `.agents/skills/architect/SKILL.md`, (4) `.agents/skills/caveman/SKILL.md` (used `ultra` mode for internal thinking).

## Scope

This review covers: whether the Developer's claim is true that a minimal cache code change cannot resolve the TP-34-CC 15-miss pattern without restructuring the Stage 25 transaction protocol. This review does NOT cover: re-design of Stage 34, re-authoring of prior Architect reviews, editing the tracker or document-index, editing the test plan, editing prior reviews, modifying production code, or committing or pushing.

## Bind facts

1. Sequential replay proves 23/23 predicted hot exact-hit rows return `cache_n>0` on the same server, same transcript, same process: `test-report-20260701-01-stage34-reopen-live-small-cache4g.md` (Row classification row 2 + Sequential real replay PASS).
2. Concurrent warm replay produces 8 hits out of 23 predicted hot rows on the same server, same transcript, same process: `test-report-20260701-01-stage34-reopen-live-small-cache4g.md` (Row classification row 4 + Blocker classification).
3. Hot budget is 4096 MiB; per-payload is ~85 MiB; ~48 entries headroom: `test-report-20260701-01-stage34-reopen-live-small-cache4g-developer-review.md` (Sequential vs concurrent differential analysis paragraph 2).
4. Server log clean: 0 crashes, 0 request-errors, 0 exceptions, 0 ASSERT, namespace count 1: `test-report-20260701-01-stage34-reopen-live-small-cache4g.md` (Server log health scan row).
5. Hit/miss rows are interleaved through the 56-row workload, not clustered: `test-report-20260701-01-stage34-reopen-live-small-cache4g-developer-review.md` (Hit/miss row list paragraph).
6. `tx_restore` at `tools\server\server-cache-hybrid.cpp:5176` acquires `cache_state_mutex_` at L5180; `find_nodes_by_token_span` at L5196 (line range per Developer fix report, verified via Select-String to be at L2181 in the helper and used at L5196 in the live file) is mutex-protected by the forest's own `std::mutex mutex_` at `tools\server\server-cache-graph.cpp:188, 203`.
7. `tx_save` at `tools\server\server-cache-hybrid.cpp:4754` acquires `cache_state_mutex_` at L4760; the slow `llama_state_seq_get_data_ext` reads occur at L4840 (target) and L4855 (draft) (verified via Select-String; Developer cited L4892-4910, which is the post-read metadata mutation path, not the slow read itself).
8. `try_restore_from_cache` at `tools\server\server-context.cpp:5886`; apply step (snapshot pre-state and `llama_state_seq_set_data_ext`) runs OUTSIDE `cache_state_mutex_` per OQ-25-01 SPLIT.
9. `tx_apply_restore` at `tools\server\server-cache-hybrid.cpp:5311` re-acquires `cache_state_mutex_` at L5314 for finalize.
10. `validate_payload_for_restore` at `tools\server\server-cache-hybrid.cpp:4045` runs under the cache lock (called from `tx_restore`); no race per Part 3 row 20 migration.
11. `branch_forest_index` uses its own `std::mutex mutex_` for every lookup and mutation: `tools\server\server-cache-graph.cpp:122, 152, 188, 194, 203, 225, 244, 251, 257, 274`.
12. Reentrancy depth limit is 4: `tools\server\server-cache-hybrid.h:696`.
13. Prompt_ms for misses: 14-42s (e.g., row-00090=14132ms, row-00095=42596ms); prompt_ms for hits: ~12-14ms (e.g., row-00078=13ms, row-00105=12ms): `test-report-20260701-01-stage34-reopen-live-small-cache4g-fixes.md` (Root cause analysis table).
14. Stage 25 invariants I-25-01 atomicity, I-25-02 isolation, I-25-03 durability-within-transaction: `cache-handling-phase25-design\part-06-new-invariants-and-architecture-cross-reference.md` (New invariants section).
15. OQ-25-01 SPLIT decision: plan under lock, apply outside lock, finalize under lock: `cache-handling-phase25-design\part-07-risks-and-open-questions.md` (OQ-25-01) and `cache-handling-phase25-design\part-03-per-operation-migration.md` (try_restore_from_cache row 20).

## Claim under review

Developer claim (verbatim from `test-report-20260701-01-stage34-reopen-live-small-cache4g-fixes.md`, Final assessment): "A minimal cache code change that resolves the 15-miss pattern without restructuring the Stage 25 transaction protocol was not identified."

Manager question (verbatim): "is it true that it can't be solved without violating transactional architecture, and why?"

## Independent assessment

VERDICT: PARTIAL

The claim is true for the narrow set of "minimal cache code change that preserves the Stage 25 transaction protocol structure and slot lifecycle separation." It is false in the broader sense: a full architectural fix exists (delay slot recycling until predecessor's `tx_save` commits), but that fix is in the slot dispatch lifecycle, not the cache code, and it merges the slot lifecycle with the cache lifecycle in a way Stage 25 explicitly kept separate.

## Why (or why not)

### Why the race is in the slot lifecycle, not the cache state machine

The 15-miss pattern correlates prompt duration to miss rate (Bind fact 13). A miss happens when the predecessor's `tx_save` has not yet started when the duplicate's `tx_restore` runs. The predecessor's `tx_save` is called from `server-context.cpp` after the slot's inference loop completes, NOT from the cache controller. The slot becomes free for the duplicate's assignment when its inference ends, which is BEFORE `tx_save` is invoked. Therefore the race window is the gap between "slot's inference finished" and "tx_save started," which is a slot dispatch concern, not a cache state concern: `cache-handling-phase25-design\part-02-atomic-transaction-protocol.md` (Acquisition and release ordering vs slot lifecycle row 1-4) shows that the cache lock orders cache-state mutations only; it does not order slot lifecycle events.

### Why the cache code correctly returns MISS in this window

`tx_restore` at `tools\server\server-cache-hybrid.cpp:5180` acquires `cache_state_mutex_` and observes the current snapshot of `entries`, `forest`, and `hot_payloads`. If the predecessor's `tx_save` has not yet started, the entry is not in `entries` and the forest node is not in `forest`; `find_nodes_by_token_span` at L5196 returns no candidates and the function returns `cache_restore_miss_reason::exact_entry_absent`. This is I-25-02 isolation: a parallel slot sees a consistent snapshot, and a save that has not yet committed is correctly invisible: `cache-handling-phase25-design\part-06-new-invariants-and-architecture-cross-reference.md` (I-25-02).

### Why a slow-read relocation (Path B) does not fix the race

`tx_save` holds the lock during the slow `llama_state_seq_get_data_ext` at L4840 and L4855. Relocating the slow read outside the lock would shorten the lock hold time but not change when the entry becomes visible. The entry is added to `entries`, `forest`, and `hot_payloads` only inside the lock at L4885-4895. The race window is determined by when the predecessor's `tx_save` STARTS, not by how long it runs. The slow read is a lock-contention symptom, not the race cause: `cache-handling-phase25-design\part-03-per-operation-migration.md` (save_slot row 19) and `tools\server\server-cache-hybrid.cpp:4840, 4855`.

### Why an optimistic commit (Path C) violates I-25-01 atomicity

Publishing a placeholder entry before the slow read completes would require `tx_restore` to either (a) skip validation when the entry is in `pending` residency or (b) block on a condition variable until the predecessor signals completion. Option (a) violates I-25-01 atomicity because the cache state would advertise a node whose payload is not yet in `hot_payloads`, and a parallel restore would observe descriptor state without bytes installed: `cache-handling-phase25-design\part-06-new-invariants-and-architecture-cross-reference.md` (I-25-02 implementation contract: "never a transient state with descriptor `hot` and `hot_payloads` empty"). Option (b) introduces a new sync mechanism (condition variable) that does not exist in Stage 25; the timeout, abort, and rollback contracts in Part 2 (Failure mode section) would need to be extended.

### Why a slot lifecycle change (Path E) violates the Stage 25 protocol separation

A full architectural fix is to delay slot recycling until `tx_save` returns. This requires the slot to remain in a "saving" state, blocked from the dispatcher's free list, until the cache commits. This merges the slot lifecycle with the cache lifecycle: a slot's recyclability becomes a function of `tx_save` completion. Stage 25 explicitly separates the two: the slot thread owns the slot, the controller owns the cache state, and the lock orders cache-state mutations only: `cache-handling-phase25-design\part-02-atomic-transaction-protocol.md` (Lock granularity section) and `cache-handling-architecture.md` (Target state summary). This is a fundamental restructuring, not a minimal change.

### Why the forest mutex and `validate_payload_for_restore` are not the race

`branch_forest_index` uses its own `std::mutex mutex_` for every lookup, including `find_nodes_by_token_span` at `tools\server\server-cache-graph.cpp:200-219` and `find_nodes_by_checksum_span` at L222-241. The cache's own `cache_state_mutex_` is NOT the synchronization point for forest lookups; the forest mutex is. The forest's own mutex serializes forest mutations against forest lookups. The miss is not a forest race; the miss is the absence of a node in the snapshot seen by `tx_restore`.

### Why the recursive mutex contract is not the issue

The recursive mutex at `cache_state_mutex_` permits `tx_save` to call `tx_evict_entry` and `tx_restore` to call `tx_update` without deadlocking: `cache-handling-phase25-design\part-02-atomic-transaction-protocol.md` (Reentrancy rule section). The depth limit of 4 at `tools\server\server-cache-hybrid.h:696` bounds the nesting. The reentrancy guard at `tools\server\server-cache-hybrid.cpp:4761, 4690, 5181, 5315` is a developer-time guard against future code that calls a private helper from outside a transaction. None of this affects whether a duplicate's `tx_restore` sees a predecessor's in-flight `tx_save`; both are correctly serialized.

### Why OQ-25-02 worker retire Option B is unrelated

OQ-25-02 retired the `io_worker` thread (Option B): `cache-handling-phase25-design\part-07-risks-and-open-questions.md` (OQ-25-02) and `cache-handling-phase25-design\part-02-atomic-transaction-protocol.md` (Worker retirement Option B). The retirement converted the worker to a synchronous helper invoked under the lock. This is unrelated to the dispatch-ordering race: the race is between a slot's inference completion and `tx_save` invocation, neither of which involves the worker. The worker handles cold-store I/O for demotion and promotion, not slot lifecycle.

## Simple-language scenarios

### Scenario 1: Alice (predecessor) and Bob (duplicate)

(a) Alice's slot is busy doing inference (5-40 seconds of model computation). The cache lock is NOT held; no save is in flight.
(b) Bob's HTTP request arrives; the dispatcher assigns Bob to a different free slot. Bob's slot calls `try_restore_from_cache`, which calls `tx_restore`.
(c) `tx_restore` acquires the cache lock at L5180 and looks up the forest. Alice has not yet called `tx_save`, so no entry exists. The forest returns no candidates.
(d) `tx_restore` returns MISS. To make Bob see Alice's not-yet-committed entry, `tx_restore` would need to know that Alice is in flight and somehow observe her prompt state before her save. This requires a NEW data structure (pending-saves map) and a NEW invariant, both of which violate I-25-01 atomicity (entry is "advertised" before the slow read completes) or the slot lifecycle separation (cache controller would need to know about slot inference state).

### Scenario 2: The slow writer (two timelines for "Bob")

This scenario walks the same prompt-arrival pattern through two distinct moments. Same name "Bob," different `tx_restore` attempts. Reading (b)-(c) as one timeline and (d) as the other avoids the apparent contradiction in earlier drafts.

#### Bob-hypothetical (steps a-c): timing aligned with Alice's `tx_save`

(a) Alice's inference ends; her slot calls `tx_save` at `tools\server\server-cache-hybrid.cpp:4754`.
(b) `tx_save` acquires the cache lock at L4760 and starts the slow `llama_state_seq_get_data_ext` at L4840 (target) and L4855 (draft). For ~85 MiB of state this takes 5-40 seconds. The lock is held the entire time.
(c) In this hypothetical, Bob's `tx_restore` happens to acquire the lock right after Alice's release. He blocks on the lock at L5180 for the 5-40 seconds Alice holds it, then proceeds, sees Alice's entry, and returns HIT. prompt_ms ~12 ms.

#### Bob-actual (step d): timing observed in the TP-34-CC 15-miss replay

(d) Bob was dispatched to a free slot during Alice's inference (not during Alice's `tx_save`). His `tx_restore` ran while Alice was still computing. At that moment `cache_state_mutex_` was free (Alice had not yet entered `tx_save`). Bob's lock acquire was instantaneous and uncontended; his forest lookup found no entry; he returned MISS in microseconds-to-milliseconds. By the time Alice later reached `tx_save`, Bob was long gone. prompt_ms 14-42 s matches the full inference cost.

#### What the alignment controls

- Bob-hypothetical proves the lock DOES serialize save-before-restore when the timing aligns, and the lock is doing its job.
- Bob-actual is the timing observed for the 15 misses. The miss is not a lock-contention symptom; it is the absence of a node in the snapshot Bob saw.
- Moving the slow read outside the lock (Path B) speeds up Bob's lock-blocked wait but does not change Bob-actual, because Bob-actual never waited on the lock. Path B is a separate throughput lever, not a fix for the binding reopen row.

### Scenario 3: The duplicate reader

(a) Alice and Bob are duplicates: same prompt, same model, same namespace. Alice was first.
(b) Alice's slot runs inference, then calls `tx_save`. During the slow read inside `tx_save`, the slot is committed to the save; it cannot accept new work.
(c) Bob is dispatched to a different free slot. Bob's slot is fresh; no prior content. Bob's `try_restore_from_cache` runs.
(d) If Alice's `tx_save` has not yet started (Alice is still in inference or post-inference cleanup), Bob's `tx_restore` sees an empty forest and MISSES. To make Bob wait for Alice, the slot dispatcher would need to know about Alice's in-flight save. This couples the slot lifecycle to the cache lifecycle, which Stage 25 explicitly separates. The cache code correctly returns MISS in this window; the dispatch model is the architectural concern.

## Alternative fix paths

### Path A: reclassify TP-34-CC as EXPECTED-BEHAVIOR

- Invariant change: none to cache invariants. The test plan classification changes from FAIL to EXPECTED-BEHAVIOR, similar to Stage 33 Hybrid reuse row reclassification.
- New failure modes: none for cache code. The test classification is the change.
- Architect recommendation: RECOMMEND. The Stage 33 closure pattern (`test-report-20260630-03-stage33-01-developer-review.md` Hybrid reuse root-cause analysis) is the precedent. The dispatch-ordering race is inherent to concurrent dispatch with throttle > 1. The cache code is correct; the test's hit-rate expectation was overly optimistic for the dispatch model. This is the lowest-cost path and matches an established pattern in the same project.

### Path B: move slow `llama_state_seq_get_data_ext` read OUT of the `tx_save` lock-held region

- Invariant change: I-25-01 atomicity unchanged (the mutation to `entries`/`forest`/`hot_payloads` still happens under the lock). The slow read is from per-slot `llama_context`, not the shared state, so the read is safe outside the lock.
- New failure modes: the slow read could be preempted by another thread mutating the slot's context, but the slot is currently in `tx_save` and the slot is not running inference, so the context is stable. However, this does not address the dispatch-ordering race (see Why section). The lock hold time shrinks from 5-40s to milliseconds, but the race window (when `tx_save` starts vs when the slot is recycled) is unchanged.
- Architect recommendation: NOT RECOMMENDED for the TP-34-CC 15-miss pattern. Reduces lock contention but does not fix the race. Could be pursued as a separate Stage 28/29/30 follow-up for throughput, but not as a fix for the binding reopen row.

### Path C: add an optimistic commit phase to `tx_save` that publishes a placeholder node before the slow read completes

- Invariant change: NEW invariant required. The cache would advertise an entry whose payload is not yet in `hot_payloads`. A parallel `tx_restore` would observe descriptor state without bytes installed. This violates I-25-02 isolation's implementation contract: "never a transient state with descriptor `hot` and `hot_payloads` empty" (`cache-handling-phase25-design\part-06-new-invariants-and-architecture-cross-reference.md`).
- New failure modes: a parallel `tx_restore` that finds the placeholder node would either fail validation (because `validate_payload_for_restore` at L4045 returns false when the record is missing) and fall back to MISS, or skip validation and apply empty bytes (catastrophic). Either way, the optimistic commit does not produce a HIT for the duplicate.
- Architect recommendation: REJECT. Violates I-25-02 isolation. Does not actually fix the race. Would require a new sync mechanism (condition variable) for the duplicate to wait for the predecessor's slow read to complete, which is a new architectural primitive.

### Path D: insert pre-warm delay in the test driver so duplicates arrive after predecessors commit

- Invariant change: none to cache code. The test driver is changed to wait for the predecessor's HTTP response (which implies `tx_save` completed) before dispatching the duplicate.
- New failure modes: none for cache code. The test no longer exercises concurrent dispatch, which is the Stage 34 acceptance criterion "concurrent main/subagent requests share cache safely without contamination" (`cache-handling-phase34-design.md` Acceptance criteria).
- Architect recommendation: NOT RECOMMENDED. Contradicts the Stage 34 acceptance criterion. The test would no longer exercise the concurrent reuse path. Could be used as a control experiment to confirm the race is dispatch-ordering, not as a production fix.

### Path E (Architect own): delay slot recycling until predecessor's `tx_save` commits

- Invariant change: merges slot lifecycle with cache lifecycle. The slot's recyclability becomes a function of `tx_save` completion. The slot would need a "saving" state that the dispatcher skips. This is a server-context.cpp change, not a cache code change, but it depends on a NEW signal from the cache controller (save-in-progress) to the dispatcher.
- New failure modes: throughput regression (slots stay busy longer). Slot exhaustion under high concurrent load (fewer slots available for new requests). Requires the dispatcher to handle the "saving" state correctly. The cache controller's `cache_state_mutex_` would still be held during the slow read, so the dispatcher's wait for the predecessor's save to commit is bounded by the slow-read latency, not the lock acquisition.
- Architect recommendation: POSSIBLE but high-cost. This is the only path that actually fixes the race while preserving the Stage 25 transaction protocol structure. The slot lifecycle separation is a Stage 25 design choice (`cache-handling-phase25-design\part-02-atomic-transaction-protocol.md` Lock granularity section), so changing it is a significant design change. Not minimal. Could be a separate stage design.

## Architect recommendation

RECOMMENDATION: ADVANCE-Manager-decision-A

The cache code is correct for the observed symptoms. The 15-miss pattern is a dispatch-ordering race, not a cache code defect. Path A (reclassify TP-34-CC as EXPECTED-BEHAVIOR, following the Stage 33 closure pattern) is the lowest-cost path and matches an established precedent in the same project. The cache invariants I-25-01, I-25-02, I-25-03 are preserved. The test plan's hit-rate expectation is corrected, not the code. If Manager wants a full fix, Path E (delay slot recycling) is possible but requires a separate stage design for the slot lifecycle change.

## Files verified by `Test-Path` (all returned True)

- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260701-01-stage34-reopen-live-small-cache4g-developer-review.md`
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260701-01-stage34-reopen-live-small-cache4g-fixes.md`
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260701-01-stage34-reopen-live-small-cache4g.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase34-design.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase25-design.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase25-design\part-02-atomic-transaction-protocol.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase25-design\part-03-per-operation-migration.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase25-design\part-06-new-invariants-and-architecture-cross-reference.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase25-design\part-07-risks-and-open-questions.md`
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-architecture.md`
- `D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp`
- `D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.h`
- `D:\source\llama.cpp-jet\tools\server\server-cache-graph.cpp`
- `D:\source\llama.cpp-jet\tools\server\server-context.cpp`

## Files NOT modified

- No production code (`tools\server\`, `src\`, `include\`, `common\`, `ggml\`) modified.
- No prior review files (`test-report-20260630-*`, prior Architect reviews) modified.
- No test plan (`cache-handling-test-plan\`) modified.
- No tracker (`cache-handling-stage-tracker.md`, `cache-handling-phase34-implementation\`) modified.
- No `document-index.md` modified.
- No `git add`, `git commit`, or `git push` performed.
- This review-only session created exactly one new durable file: this document.

## Final hygiene

- LF count target: <=300.
- CR=0 expected.
- BOM=NO expected.
- No trailing whitespace on any line.
- No non-ASCII characters.
- `git diff --check -- <created-file>` exit code: reported in final reply.
