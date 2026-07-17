# Manager intake: Stage 39 hybrid two-layer removal

Date: 2026-07-12
Status: DESIGN READY FOR MANAGER GATE

## Directive

Add and manage a stage to completion so hybrid-cache entries are removed only
when both hot and cold layers are filled.

## Baseline

- Stage 38 closed PASS on 2026-07-12.
- Hybrid cache mutations remain synchronous transactions under
  `cache_state_mutex_`.
- Current hot-pressure code can skip demotion while hot usage is already over
  budget, then evict payload immediately even when cold storage still has room.
- Payload eviction, branch pruning, and entry removal are separate operations.

Upstream search found prompt-cache and disk-offload work, including issues
`#20697`, `#21831`, and `#22746`, but no matching two-layer removal contract.
The local hybrid controller remains the design authority for this stage.

## Scope decision

"Entry removal" means irreversible loss of reusable payload bytes from both
layers. It does not mean removing branch metadata. Stage 39 must:

1. try cold admission when hot pressure selects a hot payload;
2. retain a cold payload while cold capacity exists;
3. allow payload eviction only when hot cannot retain the payload and cold
   cannot admit it because cold capacity is filled;
4. keep branch pruning governed by metadata pressure and descendant safety;
5. preserve atomic target/draft handling and transactional rollback.

## Gate state

Architect design is ready for Manager review. No code work is authorized until
Manager records design-gate PASS.
