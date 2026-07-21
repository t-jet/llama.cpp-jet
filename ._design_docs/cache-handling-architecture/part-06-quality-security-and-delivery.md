# Part 6: C5 quality, security, and delivery

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

## Correctness controls

- Candidate lookup and state application are separate phases.
- Namespace, tokens, checksums, descriptors, pair state, and boundaries are
  checked before a hit is accepted.
- Restore plans own deep copies and remain valid after the controller lock is
  released.
- Live target and draft state is snapshotted before apply and restored on any
  partial failure.
- Cold admission uses a manifest, quarantine, commit marker, and idempotent
  recovery.
- Capacity failures, I/O failures, and integrity failures use different paths
  and metrics.
- Deterministic tie-breakers make equal-rank lookup, dedupe, and victim choices
  reproducible.

## Security model

| Threat | Control |
| --- | --- |
| Path traversal or arbitrary file access | Cold root comes only from operator configuration; normalized paths must remain under it; file names use internal IDs. |
| Corrupt or substituted cold payload | Version, identity, pair state, lengths, header checksum, and payload checksums are validated before use. |
| Partial or torn write | Staging plus rename; Stage 39 manifest and quarantine protocol for multi-file room-making. |
| Prompt leakage | Evidence defaults off; redacted mode records hashes and counts; raw mode requires explicit prompt-log configuration and output directory. |
| Metrics cardinality attack | Public labels use fixed enums and aggregate scope; request IDs, namespaces, checksums, and paths are excluded. |
| Cross-model state reuse | Stable runtime namespace plus prompt-local token, checksum, boundary, and pair validation. |
| Client-forced protection | Protection derives from trusted prepared metadata and server policy, not raw marker strings. |
| Recovery ambiguity | Unknown or conflicting manifests disable cold mutation and preserve files. |

The cold directory has the permissions of the server process. It is not a
durable secret store. Operators must protect it like other local model runtime
data.

## Performance model

Hybrid cache trades storage and transaction work for lower repeated prefill
cost. Main performance choices are:

- branch and prefix indexes avoid a full linear lookup for common exact cases;
- payload bytes are separate from always-hot metadata;
- byte-accounted LRU bounds hot RAM;
- cold storage allows larger retained working sets;
- llama state serialization during save runs outside the cache mutex;
- a second dedupe pass removes races introduced by the unlocked read;
- restore apply also runs outside the mutex;
- cold I/O remains synchronous for state consistency, so cold promotion latency
  is paid by the requesting slot.

Synchronous cold I/O can increase tail latency. The design accepts that cost to
avoid background cache mutations and partially visible residency transitions.
Promotion latency buckets and transaction-wait diagnostics make the cost
observable.

## Failure policy

| Failure | Result |
| --- | --- |
| Missing or incompatible entry | Recompute. |
| Unsafe strict prefix | Recompute with `unsafe_prefix_rejected`. |
| Invalid descriptor or cold file | Mark unavailable or evicted as appropriate; recompute. |
| Demotion I/O or integrity failure | Keep hot payload; do not call it capacity exhaustion. |
| Restore target or draft apply failure | Roll back both live contexts and slot metadata; recompute. |
| Protected roots exceed budget | Preserve accounting, emit diagnostics, reject unsafe admission or evict only under defined pressure rules. |
| Metadata budget cannot prune safely | Reject metadata admission; preserve referenced topology. |
| Corrupt recovery manifest | Disable cold mutation and preserve disk evidence. |

## Verification strategy

| Layer | Required checks |
| --- | --- |
| Unit | Compatibility keys, token/checksum validation, policy order, graph topology, pair state, cold format, exact byte accounting. |
| Transaction | Reentrancy, rollback, multi-victim quarantine, every failure injection point, recovery before and after commit. |
| Integration | Controller factory, startup rejection, slot save/restore, exact and checkpoint hits, strict-prefix chat restore, `/completion` rejection. |
| Concurrency | Multi-slot restore snapshots, idempotent save races, active slot refs, no deadlock or partial state. |
| Observability | HELP/TYPE uniqueness, bounded label values/cardinality, byte gauges, fixed miss and transaction reasons. |
| Model-backed | Plain transformer, target-only, separate draft, MTP target-derived or separate-model configurations where fixtures support them. |
| Stress | Budget exhaustion, large forests, prompt storms, cold pressure, protected roots, integrity failure, long runs. |
| Performance | Output equivalence first, then hit count, hot-byte reduction, throughput, restore latency, and cold transition cost. |

Changed hybrid-cache production lines require at least 80 percent focused line
coverage. Coverage reports must identify product-only and combined rates rather
than substituting test-harness coverage for product coverage.

## Windows build and test baseline

Windows release and coverage gates must run from a VS2022 developer shell. Use
the repository build rules and an explicit VS2022 generator:

```powershell
cmake -S . -B build-cache-vs2022 -G "Visual Studio 17 2022" -A x64 -DLLAMA_BUILD_TESTS=ON
cmake --build build-cache-vs2022 --config Release --target llama-server test-cache-controller
ctest --test-dir build-cache-vs2022 -C Release -R cache --output-on-failure
```

CUDA or other backend options may be added for the intended deployment, but they
do not change the compiler baseline. Coverage builds must also produce full PDB
symbols using MSVC `/Zi` and linker `/DEBUG:FULL`.

`LLAMA_SERVER_CACHE_TESTS` enables focused test interfaces.
`LLAMA_STAGE39_LIVE_TEST_SEAM` must remain off in production and may be enabled
only for the guarded Stage 39 live pressure suite.

Artifacts built with Visual Studio 18 2026 are non-conforming for the Windows
release gate. Existing Stage 39 results remain useful behavioral evidence, but
the VS2022 build and test commands above must pass before this revision's
Windows environment requirement is closed.

On Windows, `--crash-dump-dir` installs an unhandled-exception minidump handler
before common argument parsing and a `std::terminate` trace handler. Dumps can
contain process memory and prompts, so the directory requires restricted access
and normal diagnostic-data retention controls. The implemented snapshot thread
is disabled because it raced with CUDA initialization.

## Release acceptance

A release candidate is acceptable when:

- legacy mode passes unchanged behavior tests;
- exact, checkpoint, cold, strict-prefix, and recompute paths preserve output
  correctness;
- target/draft negative tests prove no half-restore or half-eviction;
- hot, cold, quarantine, descriptor, and filesystem byte counts reconcile;
- payload pressure does not increment branch-pruning events;
- all public metric labels remain within their fixed sets;
- focused coverage meets the 80 percent gate;
- clean VS2022 Release build, controller tests, cache `ctest`, and required live
  route tests pass;
- no guarded test route or raw evidence setting is enabled by default.

## Known limits

- New payload admission first requires the payload to fit the positive hot RAM
  budget; direct-to-cold admission is not implemented.
- Strict-prefix restore is limited to the `openai-chat` metadata source.
- Cold data is local runtime cache, not a supported restart-persistent cache.
- Branch metadata budgeting and safe pruning exist, but the production soft
  limit defaults to `0` (disabled) and has no operator setting. R8b, R21a,
  R57a, and R93 are only partially met.
- LRU is the only implemented eviction policy. Pluggability, a public selector,
  and policy-specific settings required by R20-R20b remain open.
- Multimodal and unsupported runtime shapes prefer exact validated reuse or
  recomputation over speculative partial restore.
- No distributed sharing, output replay, or public cache-control API exists.
