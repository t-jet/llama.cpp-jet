# Stage 17 design: cold storage budget and eviction -- Part 3

Source: [../cache-handling-phase17-design.md](../cache-handling-phase17-design.md)

## Problem statement

The Stage 16 long-run log shows cold writes failing after large payloads are
demoted. Hot cache RAM had an 8 GiB budget, but cold files grew until the
filesystem rejected writes. Stage 17 makes cold storage an explicit budget with
predictable eviction or skipped demotion before filesystem failure.

## CLI budget option

Stage 17 introduces a cold disk budget option for hybrid mode:

| Option | Meaning |
| --- | --- |
| `--cache-cold-max-mib N` | Maximum cold payload bytes in MiB. |

Value semantics:

| Value | Behavior |
| --- | --- |
| `0` | Disable cold writes. Hot payloads may be evicted under pressure, but no new cold files are written. |
| positive `N` | Limit cold payload files to `N` MiB, enforced by cold-byte accounting. |
| `-1` | Unlimited cold writes, subject only to filesystem capacity. Accepted only when explicitly configured. |

If implementation uses a different final flag name, it must preserve these
semantics or record a Manager decision before implementation planning passes.

## Startup validation

Startup validation must run before the server accepts requests:

- Reject cold budget flags when hybrid mode or cold path support is disabled,
  unless the existing configuration contract already permits a no-op warning.
- Reject negative values other than `-1`.
- Reject positive budgets too small to admit the minimum paired payload shape
  for the configured target/draft mode, when that minimum can be estimated.
- Normalize the cold root under the configured path.
- Check that the cold root is writable when cold writes are enabled.
- Count existing cold payload files and orphan staging files.
- Remove orphan staging files that match the internal staging pattern.
- Record starting cold bytes before admitting new demotions.

Startup validation must not trust request-derived paths.

## Accounting semantics

Cold-byte accounting counts payload bytes that the current process claims as
cold-restorable:

- exact full-state blob cold payloads
- checkpoint cold payloads
- target and draft sides of a pair
- descriptor-owned payload files only

Cold-byte accounting excludes:

- branch metadata in RAM
- hot payload bytes
- orphan staging files after cleanup
- raw prompt evidence files
- normal server logs

A descriptor transitions into cold-byte accounting only after atomic write and
rename succeed and descriptor ownership is attached. If a demotion fails, the
descriptor must not claim cold residency.

## Cold pressure behavior

Before starting a cold write, the controller estimates whether the write would
exceed the cold budget. If pressure exists, it must try these actions in order:

1. Evict unprotected cold payloads by the cache policy until enough space is
   available.
2. Delete cold payload files only after descriptor ownership checks prove no
   retained branch or descendant owns them.
3. If eviction cannot create space, skip demotion and keep or evict the hot
   payload according to hot-budget policy.
4. Emit a bounded diagnostic with reason `cold_budget_exceeded` or
   `cold_demotion_skipped`.
5. Never discover routine budget pressure by writing until the filesystem
   fails.

Filesystem write failures can still happen because free space changes outside
the process. Those failures remain explicit cold-store I/O failures, not normal
budget control.

## Interaction with hot eviction

Hot and cold budgets are separate:

- `--cache-ram` remains the hot payload budget.
- `--cache-cold-max-mib` is the cold payload budget.
- Payload demotion can satisfy hot pressure only if cold budget permits the
  write.
- When cold writes are disabled or cold budget is full, hot pressure may evict
  payload bytes and leave metadata-only nodes when topology is still useful.
- Branch pruning remains distinct from payload eviction.

Protected roots raise retention priority but do not bypass either budget.

## Orphan staging cleanup

Cold writes must use an internal staging name and atomic rename. Stage 17
requires cleanup for:

- staging files left by interrupted writes
- temporary pair files whose partner never committed
- files not referenced by any live descriptor after startup scan

Cleanup must stay under the configured cold root. It must not follow symlinks
or delete paths derived from request content. Failures are logged with bounded
reason and do not silently disable budget accounting.

## Observability

Cold budget behavior needs these observable events:

| Event | Required fields |
| --- | --- |
| budget configured | limit MiB, mode disabled/limited/unlimited |
| startup scan | cold bytes counted, payload count, staging files removed |
| demotion admitted | estimated bytes, new cold byte total |
| cold eviction | payload kind, bytes removed, protected state |
| demotion skipped | reason, estimated bytes, budget remaining |
| write failure | bounded I/O reason, descriptor state |

Prometheus labels must stay bounded. Logs may include the configured cold root
only where existing server logging already permits local paths.

## Failure handling

- Cold budget failure cannot corrupt live slot state.
- Failed demotion leaves the payload hot or evicted according to hot-policy
  rules; it does not attach a cold descriptor.
- Partial target/draft cold residency is invalid.
- Promotion from cold still validates descriptor version, checksum, and pair
  state before live restore mutation.
- Cold cleanup failure does not delete branch metadata.

