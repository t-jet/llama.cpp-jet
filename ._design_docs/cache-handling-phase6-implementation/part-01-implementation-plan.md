# Phase 6 implementation plan - Part 1

Source: [../cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)

## Status

Planning date: May 30, 2026
Implementation state: complete
Plan state: ready for independent Architect review

## Approved design baseline

Implement Stage 6 against the accepted design in
[cache-handling-phase6-design.md](../cache-handling-phase6-design.md), Parts 1 through 7, as
approved by the independent design review in
[Part 8](../cache-handling-phase6-design/part-08-independent-design-review.md) (verdict: PASS)
and the manager design gate in
[Part 9](../cache-handling-phase6-design/part-09-manager-design-gate.md) (verdict: PASS,
date May 30, 2026).

Key design decisions binding this plan:

- Cold layer is opt-in. All Stage 5 behavior is preserved when `--cache-cold-path` is absent.
- `server_cache_store_cold` handles all file operations. The controller must not construct
  cold file paths directly.
- `server_cache_io_worker` runs as a single background thread. The `server_context` thread
  must never block on cold I/O or on a full work queue.
- Target and draft sides of a `target_and_draft` descriptor always move together across cold
  transitions.
- Atomic write-and-rename ensures that a reader never sees a partial cold file at the indexed path.
- Integrity validation on promotion checks magic, format version, header checksum, checksum
  algorithm, payload_id, pair_state, byte sizes, and per-side checksums in that order.
- Startup failure on invalid `--cache-cold-path` terminates the server with an error before it accepts requests. The implementation must use a graceful exit mechanism (return error code, `exit()`, or throw), not the C `abort()` function, which produces an unhandleable dialog on Windows.
- Design decision 2 (single worker thread) and decision 5 (fallback on queue full) are binding.
- NB-1 through NB-5 from Part 8 must be resolved in this plan before code work begins.

## `store_ref` schema compatibility decision

Stage 5 defines `payload_store_ref` as `struct { uint64_t id = 0; }`. This is an opaque handle
with no concrete hot-RAM address. The `id` field is already used as a registry key into the
`hot_payloads` map inside `hybrid_cache_controller`.

For Stage 6, `server_cache_store_cold` maintains its own internal registry mapping cold ref IDs to
cold file paths. The controller stores a cold ref ID in `store_ref.id` when the descriptor moves to
`cold` state. The `payload_store_ref` struct does not need a new field or a new type. The `id`
interpretation changes based on `residency_state`: when `hot`, `id` is a hot-payload registry key;
when `cold`, `id` is a cold-ref registry key inside `server_cache_store_cold`.

Decision: `format_version` in `payload_descriptor` does NOT need to be incremented for Stage 6.
`payload_store_ref` is already abstract enough to hold a cold file reference without a schema
change. This resolves the implementation-time question flagged in design review Part 8, item 2.

## Non-blocking observation resolutions (NB-1 through NB-5)

### NB-1: Transient states

Step 1 adds `demoting` and `promoting` values to the `payload_residency_state` enum. The
implementation log evidence for Step 1 documents the full state machine, including allowed
transitions into and out of transient states and which operations are blocked while a descriptor
is in a transient state.

### NB-2: Queue-full revert made explicit

Steps 6 and 7 pin the revert: the controller sets the transient state before the enqueue call. If
`enqueue_demotion` returns a queue-full failure, the controller immediately reverts the descriptor
to `hot` before returning. If `enqueue_promotion` returns a queue-full failure, the controller
immediately reverts the descriptor to `cold` before returning. No state change persists from a
failed enqueue.

### NB-3: `cold_ref_for(payload_id)` removed

Within Stage 6 scope the controller always holds the cold ref in `store_ref.id` for any cold
descriptor. A separate `cold_ref_for(payload_id)` lookup is not needed. Step 2 removes this
operation from the `server_cache_store_cold` interface and documents the removal. If a future stage
requires a scan-based lookup, it can be added then.

### NB-4: Completion callback model selected

The result-queue model is chosen: the worker posts a completion record to an internal result queue;
`server_context` drains this queue at safe scheduling points before selecting new eviction or
restore candidates. Descriptor state mutations remain on the `server_context` thread. No
per-descriptor lock is required. Step 5 documents this choice and the locking guarantees in the
implementation.

### NB-5: Hot-byte ownership transfer timing pinned

Hot bytes are NOT released from the hot payload record until the demotion completion callback
confirms success. The completion callback is the exclusive site of hot-byte release. Step 6 pins
this to a specific protocol step number. If the callback carries a failure result, the controller
reverts the descriptor to `hot` and retains the hot record. If the callback carries a success
result, the controller releases the hot record, sets `store_ref.id` to the returned cold ref ID,
and sets `residency_state = cold`.

## Ordered implementation steps

### Step 1: Transient residency states and full state machine

Goal: extend `payload_residency_state` with `demoting` and `promoting` transient values and
document the full transition table.

Affected files:

- `tools/server/server-cache-hybrid.h`

Changes:

- Add `demoting` and `promoting` to `payload_residency_state` enum.
- Add a comment block in the same header documenting the full state machine: allowed transitions,
  which operations are blocked per transient state, and how each transient state resolves to a
  stable state via the completion callback or enqueue failure.
- Update `payload_debug_fault` enum to add `demoting_residency` and `promoting_residency`
  fault injection values for tests.

Acceptance test: compile the header and confirm the two new enum values are present. Confirm the
transition comment block lists all six transitions: `hot->demoting`, `demoting->cold`,
`demoting->hot` (failure revert), `demoting->evicted` (failure with bytes gone), `cold->promoting`,
`promoting->hot`, `promoting->cold` (failure revert or queue-full revert), `promoting->evicted`
(integrity failure).

Dependencies: none.

---

### Step 2: `server_cache_store_cold` interface and module files

Goal: define and create the cold store module with the complete interface as specified in design
Part 2, minus the `cold_ref_for(payload_id)` operation.

Affected files:

- `tools/server/server-cache-store-cold.h` (new)
- `tools/server/server-cache-store-cold.cpp` (new)
- `tools/server/CMakeLists.txt`

Changes:

- `server-cache-store-cold.h`: declare `cold_ref` as a `uint64_t` typedef; declare
  `server_cache_store_cold` class with `configure`, `write`, `read`, `remove`, and
  `is_configured` operations as specified in design Part 2. Omit `cold_ref_for(payload_id)`.
  **Design correction required:** before Step 2 is implemented, a supersession note must be added
  to design Part 2's interface table marking `cold_ref_for(payload_id)` as removed by NB-3
  resolution, so the design and implementation remain consistent. This correction will be created
  as a design amendment part before Step 2 code work begins.
  Include the `cold_store_header` struct with all fields from the design Part 2 table: `magic`,
  `format_version`, `checksum_algorithm`, `payload_id`, `pair_state`, `target_size_bytes`,
  `draft_size_bytes`, `target_checksum`, `draft_checksum`, `header_checksum`. Declare `magic` as a
  four-byte constant.
- `server-cache-store-cold.cpp`: implement all declared operations as stubs returning failure.
  The stubs establish the module boundary and satisfy the build before the worker is wired.
- `CMakeLists.txt`: add `server-cache-store-cold.cpp` to the `llama-server` and
  `test-cache-controller` source lists.

Acceptance test: build `llama-server` target. Confirm the new module compiles without errors or
warnings. Confirm `is_configured()` returns false for a default-constructed instance.

Dependencies: none.

---

### Step 3: Atomic write and rename implementation

Goal: implement the complete demotion write path in `server_cache_store_cold`, including staging
file creation, header serialization, checksum computation, and atomic rename.

Affected files:

- `tools/server/server-cache-store-cold.cpp`

Changes:

- Implement `configure`: normalize root path, confirm it is a directory and writable, store root,
  set `is_configured` to true.
- Implement `write`: derive staging path from payload_id using hex encoding; serialize the
  `cold_store_header` with all fields populated; compute `target_checksum`, `draft_checksum`, and
  `header_checksum` using the same FNV-1a helper already in the hybrid module; write staging file;
  compute final path from payload_id using hex encoding; rename staging to final; return cold ref
  ID on success. On any failure before rename, delete staging file and return failure.
- File path construction: final path is `<root>/<hex(payload_id)>.cold`. Staging path appends
  `.tmp` before renaming. Path normalization must reject traversal sequences. No user-supplied
  content used in path construction.

Acceptance test: in a temporary directory, call `configure` and then `write` with a known payload
and descriptor snapshot. Confirm the final `.cold` file exists, the staging file does not exist,
and the returned cold ref is non-zero. Confirm that interrupting before rename leaves no indexed
file. This check can be done in the focused C++ test target.

Dependencies: Step 2.

---

### Step 4: Cold file read, validation, and checksum verification

Goal: implement `read` in `server_cache_store_cold` with all ten ordered validation checks from
design Part 3.

Affected files:

- `tools/server/server-cache-store-cold.cpp`

Changes:

- Implement `read`: open file at path derived from cold_ref; read and validate header in the order
  specified in design Part 3 (magic, format_version, header_checksum, checksum_algorithm,
  payload_id, pair_state, target_size_bytes, draft_size_bytes, target payload bytes against
  target_checksum, draft payload bytes against draft_checksum for `target_and_draft`); return
  target bytes, draft bytes, and descriptor snapshot on success; return failure with a
  `failure_reason` on the first check that fails. Do not return partial payload bytes on any check
  failure.
- Implement `remove`: delete file at path derived from cold_ref; log if file is not found but do
  not treat missing file as a hard error; return void.

Acceptance test: write a cold file, read it back, confirm bytes and descriptor fields match. Corrupt
the file at each of the ten validation points in turn using the test byte-flip helper, call `read`,
confirm failure is returned for each. Add these cases to `tests/test-cache-controller.cpp` under
the `LLAMA_SERVER_CACHE_TESTS` guard.

Dependencies: Step 3.

---

### Step 5: `server_cache_io_worker` thread implementation

Goal: implement the worker thread with bounded work queue, task dispatch, completion result queue,
and clean shutdown.

Affected files:

- `tools/server/server-cache-io-worker.h` (new)
- `tools/server/server-cache-io-worker.cpp` (new)
- `tools/server/CMakeLists.txt`

Changes:

- `server-cache-io-worker.h`: declare `io_task_type` enum (`demotion`, `promotion`);
  `io_completion_result` struct (`payload_id`, `task_type`, `success`, `failure_reason`,
  `cold_ref` for successful demotion); `server_cache_io_worker` class with `start`, `stop`,
  `enqueue_demotion`, `enqueue_promotion`, and `drain_completions` operations.
  Document the chosen result-queue completion model (NB-4 resolution) in a comment block.
  Queue capacity constant `IO_WORKER_QUEUE_DEPTH = 32` documented as tunable.
- `server-cache-io-worker.cpp`: implement thread lifecycle, bounded queue with mutex and condition
  variable, task execution calling `server_cache_store_cold::write` for demotion and `read` for
  promotion, result posting to the completion result queue, and `stop` draining with cancelled
  callbacks. Worker holds a reference to the configured `server_cache_store_cold` instance.
- `CMakeLists.txt`: add `server-cache-io-worker.cpp` to source lists.

Acceptance test: construct a worker with a fake in-memory cold store. Enqueue a demotion, call
`drain_completions`, confirm the completion result is present. Enqueue past capacity, confirm
queue-full is returned immediately without blocking. Call `stop` while a task is in progress,
confirm the in-progress task completes before the thread joins. Add these cases to the focused C++
test target.

Dependencies: Steps 2, 3, 4.
