# Stage 38 design: prefix and checkpoint partial restore

Source: [../cache-handling-phase38-design.md](../cache-handling-phase38-design.md)

## Restore rule

A partial restore is allowed only when the selected cache object is a strict
prefix of the requested prompt:

- same compatibility namespace;
- same target/draft pair state;
- candidate token count is less than request token count;
- every candidate token equals the request token at the same position;
- prefix checksum over `[0, candidate_tokens)` matches;
- candidate ends at an approved semantic boundary;
- payload descriptor version, checksum, residency, and pair-state checks pass;
- selected workload profile permits the restore point.

If any check fails, the result is a miss with a bounded reason. Do not refresh
hit counters for rejected candidates.

## Candidate selection

Selection order:

1. Exact restore remains first.
2. If exact restore fails, find the deepest strict-prefix candidate in the same
   namespace.
3. Prefer candidates whose selected payload kind is valid for the workload
   profile: checkpoint first for checkpoint-dependent profiles, exact blob
   first for plain transformer profiles.
4. Break ties deterministically by longer prefix, then payload rank, then
   existing branch ordering.

The selected node may be hot or cold. Cold promotion uses the existing
transactional path before live slot apply. A cold-promotion failure falls back
to recompute and records `payload_unavailable` or a more specific bounded
reason.

## Namespace and pair-state validation

Namespace validation must cover model identity, tokenizer or template identity,
tool definitions, adapters, control vectors, media layout, draft model identity,
MTP mode, workload profile, and any existing compatibility key fields. This is
the same gate used by exact restore. Prefix matching must not weaken it.

Pair state remains binary:

- `target_only` restores only target payloads;
- `target_and_draft` restores target and draft payloads as one atomic pair.

A pair-state mismatch is a restore miss. It must not partially restore one side
or process suffix tokens against mixed target/draft state.

## Semantic boundary validation

The prefix end must map to an approved boundary in prepared metadata or branch
metadata:

- end of shared system/developer setup;
- end of tool definition block;
- message end or prompt-span boundary with `metadata = "prompt"`;
- checkpoint-safe boundary selected by the checkpoint policy.

The validator must reject ambiguous boundary data, missing boundary data for
chat prefix restore, malformed boundary spans, checksum mismatch, template/tool
drift, media span drift, and multimodal metadata that cannot prove compatibility.

Stage 38 excludes `/completion` prefix restore. Token-position candidates from
`/completion` fallback metadata must be classified as unsafe and recomputed,
even when checksums match. A later stage may enable that path only with its own
boundary contract, validation rules, and route-specific tests.

## Checkpoint-dependent profiles

Checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP
profiles may restore only from checkpoint-safe points:

- a first-class checkpoint node selected by the checkpoint policy;
- an exact blob that represents the same checkpoint-safe prefix and is accepted
  by profile rules;
- a checkpoint descriptor whose boundary checksum validates against the
  requested prefix.

These profiles must not restore from arbitrary LCP offsets. If the deepest
strict prefix is not checkpoint-safe, keep the candidate rejected and record
`prefix_not_checkpoint_safe` or equivalent bounded reason.

## Suffix processing

After a partial restore:

1. Apply the restored payload to the live slot.
2. Set `restored_token_count` to the accepted prefix length.
3. Start prompt processing at `restored_token_count`.
4. Process the suffix through normal prefill and checkpoint creation.
5. Save the final state through the normal `tx_save` path.

The suffix is prompt input, not generated output. The implementation must not
inject cached logits, sampled tokens, or prior assistant output into the
response stream.

## Residency and branch behavior

Partial restore updates usage on the restored prefix node and its payload. It
must preserve protected branch behavior:

- protected roots gain retention priority but still obey hot and cold budgets;
- payload eviction remains separate from branch pruning;
- metadata-only ancestors may guide lookup but cannot be treated as restored
  unless re-materialization validation passes;
- suffix save creates or joins the validated branch for the full request rather
  than overwriting mismatched prefix metadata.

## Failure handling

All failures leave the slot in a valid recompute path. Restore planning happens
under the cache-state lock. Live slot apply remains outside the lock, followed
by `tx_apply_restore`. If apply fails, reset cache-read accounting and process
the prompt normally.
