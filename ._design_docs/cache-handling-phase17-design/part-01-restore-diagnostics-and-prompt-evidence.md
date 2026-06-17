# Stage 17 design: restore diagnostics and prompt evidence -- Part 1

Source: [../cache-handling-phase17-design.md](../cache-handling-phase17-design.md)

## Problem statement

The Stage 16 long-run log shows 19 restore lookups and 0 exact hits. The
existing log says "no exact match", but it does not say whether the miss came
from namespace drift, token count drift, checksum drift, absent exact entry, or
an unsafe prefix candidate. Stage 17 adds bounded evidence so the next fix can
distinguish those cases without dumping prompt text into normal logs.

## Restore-miss reason enum

Every hybrid restore lookup must end with one bounded outcome. Exact hits keep
their existing hit path. Misses use this enum:

| Reason | Meaning | Required evidence |
| --- | --- | --- |
| `namespace_mismatch` | At least one candidate has matching token shape or checksum evidence but a different compatibility namespace. | lookup namespace, candidate namespace hash, profile, pair state |
| `token_count_mismatch` | Namespace matches, but no candidate has the requested token count for exact restore. | lookup token count, nearest lower and higher candidate token counts |
| `checksum_mismatch` | Namespace and token count match, but token-span checksum differs. | lookup checksum, candidate checksum, token count |
| `exact_entry_absent` | No exact candidate exists for the lookup namespace. | lookup namespace, token count, exact entry count in namespace |
| `unsafe_prefix_rejected` | A prefix candidate exists but cannot be restored under Stage 17 policy. | prefix token count, requested token count, reject reason |
| `payload_unavailable` | Metadata matched, but payload is missing, invalid, evicted, or promotion failed. | descriptor id hash, residency, failure reason |
| `unsupported_route_or_profile` | Request shape cannot use the attempted restore mode safely. | route family, workload profile, pair state |

The implementation may use narrower internal causes, but public logs and
metrics must map to this bounded set. Labels must not include prompt text,
file paths, raw namespaces, or raw descriptor IDs.

## Classification order

The restore planner classifies a miss after namespace and candidate discovery:

1. Build the lookup identity from preparation id, namespace, token count,
   token-span checksum, pair state, profile, boundary count, and first-user
   boundary.
2. Search exact candidates in the same namespace.
3. If no same-namespace exact candidate exists, check whether other namespaces
   contain matching token evidence and classify `namespace_mismatch` or
   `exact_entry_absent`.
4. If same-namespace candidates exist but token counts differ, classify
   `token_count_mismatch`.
5. If token count matches but checksum differs, classify `checksum_mismatch`.
6. If exact candidate metadata matches but payload cannot be restored, classify
   `payload_unavailable`.
7. If a prefix candidate is found, run prefix safety checks and classify
   `unsafe_prefix_rejected` when Stage 17 policy forbids restore.
8. If route or workload profile blocks reuse before candidate ranking, classify
   `unsupported_route_or_profile`.

Each lookup records exactly one primary reason. Additional candidates may be
counted in debug-only evidence, but metrics use the primary reason.

## Prompt identity evidence

Stage 17 adds per-request prompt identity evidence next to existing prompt
logging. Evidence records are written only when hybrid mode and a prompt
evidence option are enabled.

Required fields:

| Field | Purpose |
| --- | --- |
| `preparation_id` | Stable id for the prepared prompt instance before queueing. |
| `namespace_hash` | Redacted namespace identity for compatibility grouping. |
| `profile` | Workload profile such as plain transformer, checkpoint dependent, or target plus draft. |
| `pair_state` | Target only or target plus draft. |
| `token_count` | Prepared prompt token count used for lookup. |
| `boundary_count` | Number of prepared prompt boundaries. |
| `first_user_boundary` | Token span for the first user boundary, if known. |
| `token_span_checksum` | Checksum over the prepared prompt token span. |
| `lookup_outcome` | Hit or bounded miss reason. |
| `prefix_candidate` | Redacted candidate summary when prefix policy considered one. |
| `raw_prompt_file` | Relative file name only, when raw prompt capture is allowed. |

## Evidence modes

| Mode | Behavior | Use |
| --- | --- | --- |
| `off` | No new prompt identity files are written. | Default. |
| `raw` | Pair each evidence JSON/JSONL record with a raw prompt file from `--log-prompts-dir` or equivalent fork-local prompt logging. | Local debugging with approved prompt capture. |
| `redacted` | Write hashes, token counts, boundary counts, checksums, and lookup outcomes only. No prompt text. | Production-like runs where prompt text is not allowed. |

Raw mode must not write raw prompts unless the operator explicitly configures a
prompt directory. Redacted mode must work without raw prompt logging.

## Interfaces

Stage 17 design expects an implementation-facing evidence sink with:

- a configuration value for evidence mode
- optional evidence directory rooted under a server-configured path
- a per-lookup record writer
- a redaction helper for namespace, descriptor id, and candidate ids
- a deterministic token-span checksum helper shared with cache validation

The sink must be called from the cache lookup path after prompt preparation and
before any live restore mutation. It must tolerate write failure by emitting a
bounded diagnostic and continuing with normal cache behavior.

## Constraints

- Evidence writing must not change cache identity or namespace construction.
- Prompt text never appears in Prometheus labels or normal bounded diagnostic
  lines.
- Raw prompt file names must come from internal ids, not request content.
- Evidence failure cannot fail a request unless a future Manager decision makes
  evidence mandatory for a dedicated debug profile.
- The exact restore path remains non-destructive.

