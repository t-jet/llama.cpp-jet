# Stage 11 design: scope, prerequisites, and upstream reference -- Part 1

Source: [../cache-handling-phase11-design.md](../cache-handling-phase11-design.md)

## Goal

Stage 11 is an operational stage. It does not add a new cache feature. It
re-syncs the fork with `upstream_master` and reworks prior stages when the
upstream changes invalidate them. The design records the upstream reference
strategy, the prior-stage contracts the merge must preserve, and the
prerequisites the merge assumes.

## Scope carried forward from the architecture

The architecture defines Stage 11 as upstream merge integration. The scope is
fixed by the architecture and is not redefined in this design. The design
treats the architecture scope as the baseline and writes the operational
contract that lets the merge and rework proceed.

Architecture deliverables the design must support:

- Pre-merge analysis of upstream commits touching cache, checkpoint,
  speculative decoding, server context, slot, and HTTP layers
- Merge execution with conflict resolution that keeps `--cache-mode hybrid`
  and the legacy default path unchanged
- Rework assessment mapping upstream changes to affected Stages 1-10, with
  required code or design updates
- Regression test reruns for any behavior the upstream change touches
- Merge log: decisions, deferred upstream commits, and known gaps

Architecture exit criteria the design must support:

- Merge complete with no unresolved conflicts
- All prior-stage tests pass on the merged tree
- Hybrid mode invariants from earlier stages hold
- Upstream cache-related changes are integrated or recorded as known gaps
  with a follow-up plan
- Legacy mode behavior is unchanged

## Prior-stage contracts the merge must preserve

The merge and any rework must keep these contracts from the closed stages
intact. Each contract names the architecture or stage design that owns it.

| Contract | Owner | What the merge must preserve |
| --- | --- | --- |
| Hybrid mode opt-in CLI flag | Architecture, Stage 1 | `--cache-mode hybrid` remains explicit and opt-in. No silent default change. |
| Legacy default path unchanged | Architecture, Stage 1 | When `--cache-mode` is not `hybrid` or the flag is absent, the legacy cache path behaves exactly as before the merge. |
| Hybrid mode gate isolation | Stage 1 | Mode dispatch in `server_context` keeps hybrid and legacy controllers separated. |
| Compatibility namespace key | Stage 2, Stage 5, Stage 7, Stage 9 | The namespace key continues to include target model identity, draft model identity or absence, tokenizer-compatible prompt semantics, workload profile, and material runtime modifiers. |
| Draft runtime mode identity | Stage 5 | The richer mode identity for separate draft model, MTP on target, and MTP on a separate draft model stays distinct in the namespace and in the runtime shape observed by the cache. |
| Target and draft pairing | Stage 5 | All save, restore, offload, eviction, and cold-layer operations preserve target and draft coupling. A branch with both payloads must not allow only one side to be restored, evicted, or demoted independently. |
| Prepared-prompt boundary metadata | Stage 2, ADR-004 | Boundaries captured at prompt preparation continue to flow into `server_task` and reach `server_context`. |
| Hot and cold residency for full-state blobs and checkpoint payloads | Stage 4, Stage 6, Stage 9 | Hot and cold residency, eviction, and promotion rules apply to both payload kinds. |
| Byte-accounted LRU with protected roots | Stage 4 | Resident-byte accounting and protected-root priority remain in force. |
| Payload descriptor separation and validation | Stage 5 | Descriptors carry id, kind, pair state, version, size, checksum, store reference, and residency state. Pre-restore validation remains mandatory. |
| Atomic target and draft restore | Stage 5 | The transactional restore contract from Stage 5 remains in force. A partial paired restore is a blocking defect. |
| Cold store integrity and root containment | Stage 6 | Versioned descriptors, checksums, atomic write/rename, staging files, normalized root, and root-containment checks remain in force. |
| Branch forest, namespace validation, slot references | Stage 7 | The shared forest, namespace validation before restore, slot references without ownership transfer, and global LRU eviction remain in force. |
| Metadata-only nodes and re-materialization | Stage 8 | Re-materialization from the nearest retained payload-bearing ancestor, validation mismatch handling, and mismatch-parent selection with deterministic tie-breaking remain in force. |
| Equivalent-branch deduplication | Stage 8 | Convergence on the same validated prompt path joins the existing node rather than creating a duplicate. |
| Cold cleanup ownership | Stage 8 | Pruning verifies that no retained branch or descendant owns the descriptor before cold deletion. |
| Checkpoint payloads as first-class branch nodes | Stage 9 | Checkpoint payloads move, restore, evict, and demote as first-class branch node references. |
| Workload profile detection and restore strategy | Stage 9 | Plain-transformer, checkpoint-dependent, and target-plus-draft profile detection and the restore strategy order remain in force. |
| Prepared-prompt boundary checkpoint placement | Stage 9 | Checkpoint placement at prepared-prompt boundaries when metadata is available remains in force. |
| Public Prometheus metric set and label shape | Stage 10, ADR-008 | The R61-R68 metric set, the bounded labels, the absence of sensitive material in labels, and the S10-IMPL-01 corrected metric shape remain in force. |
| Bounded diagnostics for failure and fallback paths | Stage 10 | Structured diagnostics for unsupported configuration, marker validation, namespace or pair rejection, cold-store failure, and restore failure remain in force. |
| OWASP review mitigations | Stage 10 | Cold-store path normalization, root containment, marker sanitization, descriptor integrity, paired atomicity, and monitoring mitigations remain in force. |
| Deterministic test seams | Stage 10 | Injected clocks, fake stores, deterministic graph lookup, and worker completion order remain in force. |
| 80% hybrid path coverage floor (T114) | Stage 10, test plan Part 12 | The combined-rate 80% floor on the hybrid-mode denominator remains a closure contract. |
| 70% product-only hybrid path coverage floor (T114a) | Test plan Part 13, effective Stage 11 onward | The product-only rate 70% floor on the 11 product files named in the Architect review remains a closure contract. |
| Per-file aggregation rule (T115) | Test plan Part 12, Part 13 | The `coverage-report.md` per-file table lists each hybrid-mode file exactly once, with deduplication by lowercased full path. |
| Checkpoint admission public /metrics row (T121) | Stage 10 implementation Part 9, test plan Part 12 | The four `cache_checkpoint_*` rows must remain exposed through the public /metrics endpoint when a hybrid-mode server with MTP or checkpoint-capable draft is exercised. |
| Stage 5 speculative-mode namespace isolation | Architecture Part 6 | Target-only, separate draft, MTP-on-target, and MTP-on-separate-draft descriptors must not reuse each other's entries. |
| Stage 7 multi-namespace concurrent operation with shared budgets | Architecture Part 2 | The shared hot-payload, branch-metadata, and cold-layer budget pool remains global across namespaces, with no per-namespace quota. |

The merge may extend the contracts listed above, but it must not weaken,
rename, or remove any of them. Any contract that an upstream change would
weaken is a rework candidate and not a silent integration.

## Upstream reference strategy

The design assumes a single primary upstream reference. The Developer fills
the concrete ref name and commit range when implementation planning opens.

| Reference item | Design assumption | Concrete value source |
| --- | --- | --- |
| Upstream remote name | `upstream` | Implementation plan |
| Upstream branch | `master` on the `upstream` remote | Implementation plan |
| Local integration branch | The local default branch | Implementation plan |
| Fetch policy | `git fetch upstream` followed by `git fetch --tags upstream` | Implementation plan |
| Commit range rule | All upstream commits reachable from the local fork point to the upstream `master` tip that are not already in the local history | Implementation plan |
| Excluded upstream refs | Upstream feature branches and PR refs are not part of the merge unless an Architect review marks them as required | Implementation plan |
| Tag handling | Tags are fetched for traceability but are not part of the merge range unless the Developer records a reason in the merge log | Implementation plan |

The Developer is responsible for confirming the remote URL, the local fork
point, and the existence of the upstream ref at the time the merge is opened.
A change to the upstream ref or to the local fork point is recorded in the
merge log, not silently absorbed.

## Host tooling and credential assumptions

The merge assumes the following on the host where the merge is run:

- Git is available on `PATH` and supports the merge command family the
  Developer will execute
- The local clone has the `upstream` remote configured with read access
- The local clone has the local default branch checked out at a clean tree
  before the merge begins
- The fork's local credentials allow push to the local default branch
  after the merge resolves cleanly
- The host can run the local build and the regression ctest command family
  used by prior-stage verification
- The host has access to the coverage and benchmark scripts used by the
  closed stages

A missing or misconfigured remote, credential, or build prerequisite is a
blocker for the merge and must be reported in the merge log. It is not
silently skipped or worked around with an unrecorded alternative.

## Boundary with the prior stage designs

Stage 11 is not a replacement for any prior stage design. The prior stage
designs remain the source of truth for behavior, contract, and traceability
within their own stage. Stage 11 only adds the operational layer that
audits, integrates, and reworks prior stages against upstream changes.

When an upstream change would invalidate a prior stage contract, the
Architect opens a rework of that stage. The rework follows the standard
stage workflow (Design, Implementation, Test, Closure) but starts from the
current state of that stage's docs and code, not from scratch. The rework
records its own evidence, its own review, and its own closure decision in
the implementation log of the stage being reworked, not in the Stage 11
implementation log.
