# Part 3: implementation-plan corrections

Date: 2026-07-12
Status: READY FOR ARCHITECT RE-REVIEW

## Resolution

| Finding | Correction |
| --- | --- |
| F39-IPR-01 | Part 1 makes the fsynced `committed` manifest the commit point before descriptor apply and hot release. Pre-commit recovery restores victims and removes only the uncommitted incoming copy. Post-commit recovery keeps incoming state and retries cleanup. Failure injection covers every rename, manifest replace, apply, release, and unlink boundary. |
| F39-IPR-02 | Part 1 separates logical final, physical final, staging, and quarantine bytes. The cold budget applies to logical committed bytes. One exact incoming object is the bounded temporary reserve. Quarantine cleanup debt blocks later mutations. Exact-fit, one-byte-over, multi-victim, overflow, cleanup-failure, and restart equations are fixed. |
| F39-IPR-03 | Part 1 fixes C++ signatures, replaces the old write and room-making APIs, places recovery before worker wiring and reconciliation, defines stats JSON rows, and maps every TP-39 row to production entry, named focused/live tests, tuples, and preserved artifacts. TP-39-12 enters through real `tx_save`. |

## Advisories

Victims use existing reuse rank then payload ID. Missing, corrupt, shared, paired,
or ownership-ineligible bytes never count in `V`. Payload pressure changes only
payload residency and descriptor tombstones; lookup entries and branch nodes
remain. Metric mode remains the closed value `hybrid`, with 32 and 27 series
ceilings. No code work is authorized by this correction.

## Gate

F39-IPR-01 through F39-IPR-03 are addressed. Request fresh Architect
implementation-plan re-review. Manager implementation-plan gate stays closed.
