# Part 95: Architect D39-EXEC-22 implementation review

Date: 2026-07-14
Verdict: REWORK; DESIGN PART 49 PASS
Scope: Design Part 48, implementation Parts 92-94, current helper, discovery source, and exec22 artifacts

## Verdict

The Prometheus correction conforms to Part 48. Both MTP callers share one
strict parser, parser errors fail closed, and the four requested nodes produced
12 passing cases. Exec22 correctly stopped before proof or apply.

The inventory mismatch is not diagnosable. Discovery and parsed metrics lived
only in helper memory and were written after the assertion that failed. Exact
rows, owners, residency, and metric values are unrecoverable. Do not change the
inventory assertion or authorize another normal rerun from the log alone.

## Proven source behavior

`stage39_build_snapshot_locked()` first validates descriptor ownership, kind,
pair state, links, cold files, and cold-byte accounting. Hot selection then uses
`enumerate_hot_policy_candidates_core()`. The forest excludes active slot
references, payload-free nodes, zero resident bytes, and nodes without target
or draft state. It orders unprotected rows before protected roots. Snapshot
construction keeps only each selected owner's linked exact descriptor when its
residency is `hot`, then sorts rows by payload ID.

Each cold set is scoped to one incoming hot owner and contains only cold
descriptors owned elsewhere. Apply later compares the submitted hot and cold
arrays with a fresh snapshot before selection. These are safe, fail-closed
selection semantics. They do not prove what exec22 returned, so they do not
prove that the helper assertion is wrong.

## Artifact review

The preserved midpoint root contains command, model metadata, source request
and hash, response, preflight result, resource capture, server log, and an empty
cold directory. It contains no discovery, metrics, proof, or apply artifact.
The log proves a 243.620 MiB saved entry, real checkpoints, positive target and
draft components, and 19 accepted draft tokens. It does not expose the guarded
discovery response.

Part 94's parser evidence is accepted. The route result remains blocked: zero
passes, one failure, zero skips, with step 2 not run.

## Required correction and gate

Implement only design Part 49's two pre-validation writes and capture-only
stop. Then run one fresh midpoint capability diagnostic under all existing
caps. Expected outcome is the fixed diagnostic block with both required JSON
files and no proof or apply artifacts. An earlier capability or cap block is
not diagnostic acceptance.

Fresh Architect review must inspect the observed rows and metrics before any
assertion, fixture, workload, product, proof, or apply change. Manager owns the
next gate. Part 49 supersedes only the evidence timing assumption in Part 48;
Part 94 remains historical fail-closed evidence. Canonical TP-39-03, step 2,
coverage, full QA, build, commit, and push remain blocked.
