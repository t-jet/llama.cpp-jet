# Part 17: persistent ownership claims

Date: 2026-07-12
Status: PARTIAL

## Change

Committed cold transactions now update `ownership.claims` before manifest
cleanup. The journal stores the full recovered descriptor image and exact file
size for each live cold payload. Victim claims are removed in the same journal
replace. Ordinary cold payload deletion removes its claim after deleting the
payload file.

Startup loads and validates claims before transaction replay and orphan
reconciliation. It rejects missing owners, invalid kind/link pairs, duplicate
owner links, duplicate payload IDs, and missing claimed files by disabling cold
mutation. Committed manifests repair the journal before cleanup, so recovery is
safe if the commit marker became durable before the journal replace.

Fresh controller reconstruction installs claimed descriptors and per-ID byte
accounting before orphan reconciliation. Repeated reconstruction does not delete
claimed payloads.

## Tests

Focused coverage now proves:

- committed cleanup leaves one persistent incoming claim;
- second and third cold-store recovery return the same claim;
- second and third fresh controllers retain the claimed `.cold` file;
- payload deletion clears its claim;
- missing-owner and duplicate-owner-link journals disable mutation.

## Verification

- Release `test-cache-controller` build: PASS.
- Release `llama-server` build: PASS.
- `test-cache-controller.exe`: PASS.
- `ctest -C Release -R cache-controller`: PASS, 1/1.
- Stage 39 PowerShell parser check: PASS.

## Remaining work

TP-39-14 still needs descriptor-apply injection and the complete pre/post-commit
multi-victim position matrix. Coverage measurement and live model-backed
execution also remain open. Implementation is not ready for Architect review.
