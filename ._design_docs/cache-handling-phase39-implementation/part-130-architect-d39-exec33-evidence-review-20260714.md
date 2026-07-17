# Part 130: Architect D39-EXEC-33 evidence review

Date: 2026-07-14
Verdict: REWORK; ROUTE EVIDENCE CONTRACT INCOMPLETE
Scope: Parts 124-129, both D39-EXEC-33 roots, and current route helper

## Verified evidence

Both isolated nodes passed without skip or fallback. Their pytest outputs give
the required `2 PASS / 0 FAIL / 0 BLOCKED`. Separate process identities,
sessions, ports, cold roots, artifact roots, and run IDs are present. Actual
request-file hashes match the accepted 5,687-byte source and 5,688-byte
incoming hashes. No `llama-server` process remains.

The midpoint record contains only the exact preparation; step 2 contains exact
then checkpoint preparations. Both preserve generation order 36, 42, 45, 46
where applicable, one common sync, coherent exact-cold/checkpoint-hot entry and
branch state, empty staging, unchanged topology, exactly one
`retained_cold/cold_room` decision, and exactly one `commit/none` transaction.
All seven observed fields are zero: checkpoint classification, publish,
commit, cold-file, descriptor, link, and explicit-generation deltas. The full
descriptor, link, and cold-file before/after observations also match.

Authenticated byte-equivalent retrieval and consumed retry execute in both
nodes. RSS, cold-root, log, and elapsed caps pass. Current controller source and
header hashes remain the Part 124 values. Current helper hash is
`F184EA82C9C6217A7D6B18A80765534B409211E7F69BEBB589FAB9F894E581BD`;
the seam server is newer than all three inputs.

## Blocking findings

### F39-ROUTE-01: route tamper rejection did not run

Parts 124-125 require HMAC retrieval and tamper rejection in the two route
nodes. `_retrieve_terminal_proof()` sends only the valid terminal HMAC. Both
node bodies call it once, then retry the original apply to prove consumption.
No tampered `prepared_proof` request exists in the helper or saved artifacts.
Earlier controller tamper coverage does not satisfy this route gate. Part 129's
claim that route tamper rejection passed is unsupported.

### F39-ROUTE-02: required artifact manifests are absent

Part 124 requires a per-node manifest, and Part 126 names it as a separate
artifact group. Each D39-EXEC-33 node root has 25 files, but neither contains
`artifact-manifest.json`. Current helper has no manifest writer. Part 129's
claim that each root covers a manifest is false.

## Correction and next gate

No product or design correction is needed. Manager may authorize one Python
helper-only correction that:

1. sends a terminal-proof retrieval with one changed HMAC, requires rejection,
   and saves the redacted request/response for each fault node;
2. writes `artifact-manifest.json` after final capture, listing every required
   artifact, forbidden leftovers, and zero unredacted token or HMAC matches;
3. adds cheap pure tests for valid retrieval, tamper rejection, manifest
   completeness, missing-file failure, and redaction before model execution.

After fresh Architect correction review, rerun midpoint then step 2 in fresh
processes under the unchanged Part 124 contract. Acceptance stays
`2 PASS / 0 FAIL / 0 BLOCKED`. No C++ build is needed unless C++ inputs change.
Canonical TP-39-03, default build, coverage, and full QA remain blocked until
this route evidence re-review passes. Then hand off to fresh clean-build QA for
the complete approved Stage 39 plan, including previously blocked TP-39 rows
and coverage, ordered from cheap checks to model-backed scenarios.
