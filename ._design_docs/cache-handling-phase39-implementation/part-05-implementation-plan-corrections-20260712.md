# Part 5: implementation-plan corrections

Date: 2026-07-12
Status: READY FOR FRESH ARCHITECT RE-REVIEW

## Resolution

| Finding | Correction |
| --- | --- |
| F39-IPR-02 | Part 1 now defines final, staging, quarantine, logical, and physical bytes for prepared state, every partial victim step, published state, committed state, and cleaned state. Incoming bytes occur in staging or final, never both. Exact-fit, one-byte-over, partial multi-victim, overflow, cleanup-failure, and restart examples use that table. |
| F39-IPR-03 | Part 1 fixes store recovery result structs and controller-owned apply and cleanup APIs. Startup applies committed records under the controller lock before worker wiring and ordinary reconciliation. The TP matrix replaces wildcard, alternative, and slash-separated expectations with named subcases, one exact tuple, one exact test, and one log source per subcase. |

## Gate

F39-IPR-01 remains closed. F39-IPR-02 and F39-IPR-03 are corrected. No code is
authorized. Request a fresh Architect implementation-plan re-review. Manager
implementation-plan gate remains closed pending Architect PASS.
