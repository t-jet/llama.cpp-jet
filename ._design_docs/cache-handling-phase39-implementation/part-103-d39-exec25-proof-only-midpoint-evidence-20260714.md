# Part 103: D39-EXEC-25 proof-only midpoint evidence

Date: 2026-07-14
Status: PASS; ARCHITECT REVIEW NEXT
Scope: one proof-only midpoint process and root

## Execution

The sole authorized midpoint node passed in 166.57 seconds. Pytest reported
one passed test and two warnings. The helper used the fixed two-request command
and stopped after repeated read-only discovery and proof. It did not construct
or send an apply request.

Source and incoming requests returned HTTP 200 in that order. Their preserved
byte counts and SHA-256 values are:

| Request | Bytes | SHA-256 |
| --- | ---: | --- |
| source | 5,687 | `d34dee12bb4b0c0782975f853f25a9a063f1a01d76d1552de1202e7457379a49` |
| incoming | 5,688 | `a81ced76f8500dcbc4ab5c291f5f51aa61253d988dda72fff98205bfcbf1948b` |

## Lifecycle and proof

Branch nodes moved from one after source admission to two after incoming
admission. Source discovery had no eligible hot row or cold set. Final
discovery selected one released hot exact row:

- payload 1, owner 1, store-backed residency `hot`;
- `slot_reference_count=0`, `pair_state=target_and_draft`;
- resident bytes 187,834,252;
- cold-set key payload 1 and owner 1, with zero candidates.

Proof generation 36 expanded payload 1 to this same-owner pair:

| Kind | Payload | Store | Owner | Target bytes | Draft bytes | Resident bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `exact_blob` | 1 | 1 | 1 | 172,761,412 | 15,072,840 | 187,834,252 |
| `checkpoint` | 2 | 2 | 1 | 52,691,548 | 14,928,780 | 67,620,328 |

Both rows are hot `target_and_draft` records. Both report runtime draft
present, runtime pair match, no mismatch flags, and component bytes equal to
resident bytes. Each target-plus-draft sum equals its resident byte count.
Payload and store IDs are nonzero and distinct.

Repeated discovery and proof matched their first values exactly. Parsed
metrics also remained unchanged: two branch nodes, zero two-layer decision
events, and zero cold transaction events. Cold inventory stayed empty.

## Caps, artifacts, and verdict

Peak captured RSS was 5,842,055,168 bytes. Final captured elapsed time was
166.265 seconds, cold bytes were zero, and server log size was 46,773 bytes.
All fixed caps held and the server process ended.

`Test-Path` confirmed all 20 required node artifacts. The node-local
`artifact-manifest.json` records those results and zero unredacted token or
HMAC matches. `preflight-result.json` says `PASS`, with request count two,
generation 36, payload IDs 1 and 2, and owner 1.

`apply-request.json`, `apply-response.json`, prepared-proof retrieval, final
metrics, final cold inventory, terminal proof, and fault artifacts are absent.
D39-EXEC-25 passes. Fresh Architect review owns the next gate. Fault execution,
step 2, product changes, build, canonical TP-39-03, coverage, full QA, commit,
and push remain blocked.
