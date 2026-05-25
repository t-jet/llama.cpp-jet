# Cache Requirements QA - Part 2: Q12. What source of truth must be used to re-materialize a payload for a metadata-only branch node?

Source: [../cache-requirements-qa.md](../cache-requirements-qa.md)

## Q12. What source of truth must be used to re-materialize a payload for a metadata-only branch node?

Affected requirements: R39, R71c, R72-R73, R91.

Answer: Open. The document now requires recomputing and materializing a payload when a metadata-only branch node becomes the selected branch point again, but it still does not define what data the implementation must rely on to rebuild that payload correctly.

Why this is open:

- R39 requires metadata to be sufficient for locating, ranking, and restoring branches without eagerly loading cold payloads, but not necessarily for recomputing dropped payloads.
- R71c requires re-materialization of a payload for a metadata-only node.
- R72-R73 require lookup and traversal through the graph, but not the authoritative recomputation path.
- R91 requires each restore path to produce equivalent valid model state, which depends on a precise recomputation source.

Options to resolve in the requirements document:

1. Require recomputation from the nearest retained ancestor plus the node's token span. State that the implementation must rebuild the node state from the closest valid retained restore point and replay the required prompt segment.
2. Require each metadata-only node to retain enough reconstruction data. State that a node kept without payload must still retain the exact prompt or checkpoint reconstruction inputs needed to re-materialize its payload deterministically.
3. Allow either strategy behind an explicit contract. State that the implementation may re-materialize from an ancestor replay path or from node-local reconstruction data, but must define and test the chosen method for each branch type.

## A12. What source of truth must be used to re-materialize a payload for a metadata-only branch node?

It's possible that several nodes in a row will be metadata only, e.g. if system prompt, tools description, skills prompts and agent's instructions were the same for the agent for a long time, but at some point user changed only the agent prompt. In that case the agent prompt will be resued continously and will have most hits having many user prompt branches as descendants, but the system prompt and all other parent prompts will be metadata-only and their re-calculation will be required to get into the new agent prompt branch. In such cases recomputation will start from the nearest retained ancestor with payload or, even from the root if all ancestors are metadata-only as in the example above, but the payload should be re-materialized onllly for the parent noda of the changed prompt (the latest skill promt for the example above). So, computation happens from the nearest retained ancestor, but blobs re-materialized and stored only for the node with changed prompt.
If the question is about tokens which should be used for recomputing, then the anser is that tokens from the supplied prompt should be used, because there are no tokens in the metadata and identity of the provided tokens to the chosen path confirmed by the length and chacksum verification.

## Q13. What must happen when supplied-prompt tokens fail validation against a metadata-only branch path during re-materialization?

Affected requirements: R39b, R36, R71c, R90-R92.

Answer: Open. The document now requires verification of the supplied prompt tokens before replaying them to re-materialize a metadata-only node, but it still does not define whether a validation mismatch should cause a safe fallback, branch invalidation, or branch replacement.

Why this is open:

- R39b requires validation against branch metadata before replay.
- R36 defines safe fallback when referenced payloads are unavailable or invalid, but not when replay input mismatches the selected branch path.
- R71c requires re-materialization when a metadata-only node becomes the selected branch point.
- R90-R92 require correctness and explicit handling of unsupported or invalid combinations.

Options to resolve in the requirements document:

1. Require safe fallback without materialization. State that a validation mismatch must reject that branch path, emit diagnostics, and fall back to a valid slower path without creating a new payload for the mismatched node.
2. Require branch invalidation on mismatch. State that a validation mismatch must reject the path, mark the stale branch metadata invalid or prune it, and then fall back safely.
3. Allow mismatch-driven branch replacement. State that a validation mismatch may trigger creation of a new branch or replacement metadata entry, but only after explicit validation failure handling and correctness-preserving replay from a valid ancestor or root.

## A13. What must happen when supplied-prompt tokens fail validation against a metadata-only branch path during re-materialization?

It's not an option. If supplied prompt tokens doesn't match the branch node metadata, then prompt is different and requires creation of the new braanch starting with latest branch with matched metadata as a parent. If there are no such nodes, then the new branch will be created from the scratch.

## Q14. How is the latest validated matched ancestor selected when multiple paths partially validate?

Affected requirements: R36b, R39b, R72-R73, R123.

Answer: Open. The document now requires new-branch creation from the latest validated matched ancestor after replay validation fails, but it still does not define how to choose that ancestor when more than one candidate path or ancestor segment validates.

Why this is open:

- R36b uses the phrase latest validated matched ancestor, but does not define a selection rule.
- R39b requires validation of the selected path segment, but does not define how competing validated segments are compared.
- R72-R73 require branch lookup and traversal, which may yield more than one partially matching path.
- R123 prefers deterministic behavior, so parent selection needs an explicit deterministic rule.

Options to resolve in the requirements document:

1. Require the deepest validated ancestor on the selected path. State that the parent for mismatch-driven new-branch creation must be the deepest ancestor whose metadata validates against the supplied prompt.
2. Allow policy-based choice among validated candidates. State that the implementation may choose among validated ancestors using branch-ranking policy, but must define deterministic tie-breakers.
3. Separate restore selection from mismatch-parent selection. State that once a candidate path is selected for validation, mismatch handling must use only ancestors on that path, with the deepest validated ancestor becoming the parent.

## A14. How is the latest validated matched ancestor selected when multiple paths partially validate?

It's not an option. The first step is to walk through the branch graph step-by-step, choose candidate descendants, match against descendants and remove non-matches and so on until we get the point where there are no matches on the next step. At this point we still can have several candidates, but only for the fallback option, because the message-bounded checkpoints will give the only one candidate. For the fallback option a candidate with the longest prompt match should be selected as the latest validated matched ancestor, because it will give the most reuse and the least replay cost for the new branch creation. It's not possible to have two candidates with the same length and same checksum, because algorithm will choose to reuse exiting one instead of creating similar entry.
One more related note that cache implementation should be thread-safe and allow parallel slots to validate and reuse the same branch node concurrently, so only one new node will be created for the same prompt, and other threads will reuse it after it's created. This is important to avoid cache pollution with many similar branches when there are many parallel requests with the same prompt.

