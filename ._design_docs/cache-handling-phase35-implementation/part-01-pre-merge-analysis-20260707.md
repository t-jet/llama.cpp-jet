# Stage 35 pre-merge analysis 2026-07-07

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Metadata

| Field | Value |
| --- | --- |
| Stage | 35 upstream merge cycle |
| Branch | `work-branch` |
| Local tip | `d77dabc3f2814b725c613ffbed15a294891d2f56` |
| Source ref | `origin/upstream_master` |
| Source tip | `108f186d1701d56133a0239dd6754c8814374cbf` |
| Fork point / merge base | `18ef86ecec723361362a332a79b4d913fd724d40` |
| Date opened | 2026-07-07 |
| Date closed | 2026-07-07 |
| Owner | Developer |
| Reviewer | Architect |
| Manager approver | Manager |
| Working tree at open | Dirty before this artifact; see blocker below. |

Pre-existing dirty state before this artifact:

```text
 M ._design_docs/document-index.md
 M .agents/skills/self-improvement/assets/architect.md
 M .agents/skills/self-improvement/assets/manager.md
?? ._design_docs/.manager-inputs/manager-input-20260707-stage35-upstream-merge.md
?? ._design_docs/cache-handling-phase35-design.md
?? ._design_docs/cache-handling-phase35-design/
```

This blocks merge execution under guide part 04 section 11 unless Manager records
an exception. It does not change the upstream staleness result.

## Upstream reference verification

| Command | Output |
| --- | --- |
| `git rev-parse origin/upstream_master` | `108f186d1701d56133a0239dd6754c8814374cbf` |
| `git log -1 --format='%H %ai %s' origin/upstream_master` | `108f186d1701d56133a0239dd6754c8814374cbf 2026-07-07 17:20:52 +0800 [SYCL] fix unsupported UT cases of CONT & CPY (#25231)` |
| `git merge-base HEAD origin/upstream_master` | `18ef86ecec723361362a332a79b4d913fd724d40` |
| `git rev-list --count HEAD..origin/upstream_master` | `308` |
| `git remote -v` | `origin https://github.com/t-jet/llama.cpp-jet.git (fetch)`; `origin https://github.com/t-jet/llama.cpp-jet.git (push)` |
| `git ls-remote https://github.com/ggml-org/llama.cpp.git master` | `108f186d1701d56133a0239dd6754c8814374cbf refs/heads/master` |

Staleness verdict: current after Manager refresh. `origin/upstream_master`
matches actual upstream `master`, so refreshed triage continued.

## Commit range

Range expression: `HEAD..origin/upstream_master`

Total commits: 308

Date range: 2026-06-11 to 2026-07-07

Filtered count: 89 commits matched the Stage 35 file-glob or subsystem filters.
Pure backend-only, docs-only, CI-only, and unrelated test-only commits were
excluded unless they touched a Stage 35 runtime or evidence surface.

Delta since prior source tip `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`:

- `108f186d1701` (`[SYCL] fix unsupported UT cases of CONT & CPY (#25231)`)
  touches `docs/ops.md`, `docs/ops/SYCL.csv`,
  `ggml/src/ggml-sycl/cpy.cpp`, and `ggml/src/ggml-sycl/ggml-sycl.cpp`.
  It is backend/docs-only for Stage 35 and adds no filtered row.

Decision shorthand:

- NO-OP: integrate without local action; no protected Stage 35 contract touched.
- INTEGRATE: integrate with focused conflict scan and regression for named surface.
- REWORK-REQUIRED: Manager/Architect rework decision needed before merge execution.

## Per-commit triage

| SHA | Subject | Groups | Contracts | Decision | Reason / owner |
| --- | --- | --- | --- | --- | --- |
| `099ea76fb47d` | SYCL CI build/release | Build | Build evidence | NO-OP | CI-only for local closure evidence; Developer notes no runtime contract. |
| `88a39274ecf8` | EAGLE3 speculative decoding | Spec, KV | Stage 5, checkpoint/MTP | REWORK-REQUIRED | New speculative architecture crosses target/draft and KV assumptions; Architect/Manager. |
| `f7ca93d12c52` | PWA support | HTTP, build | Routes | INTEGRATE | Static route changes need endpoint smoke only; Developer. |
| `ebc10770ac5a` | Reasoning budget precedence | HTTP | Route adapters | INTEGRATE | Server arg precedence can affect chat route inputs; Developer. |
| `f58bad4137c3` | Release CI fix | Build | Build evidence | NO-OP | CI-only; no local build command change. |
| `e37abd6b5fc9` | mtmd batching API | HTTP, ctx | Stage 13 routes | INTEGRATE | Server context shape changes need route and metrics scan. |
| `d8a24ccee207` | wrap memory data | Ctx, metrics | Metrics | INTEGRATE | Context memory reporting can touch public metrics evidence. |
| `57fe1f07c3b6` | static assets cleanup | HTTP, build | Routes | INTEGRATE | Static asset serving touches server HTTP path. |
| `597b6672e800` | UI file name/path | HTTP, build | Routes | INTEGRATE | Static asset routing and build artifact naming need smoke. |
| `341babcf73f1` | jinja split/replace fix | Chat | Prompt/template | INTEGRATE | Template behavior affects prompt identity. |
| `e8067a8b3624` | gzip UI assets | HTTP, build | Routes | INTEGRATE | Server static response behavior changes. |
| `f05cf4676af4` | jinja negative slice | Chat | Prompt/template | INTEGRATE | Template behavior affects chat-path prompt-span inputs. |
| `4988f6e86605` | Cohere2-MoE arch | KV, spec | Checkpoint/MTP | INTEGRATE | Model/runtime additions need KV and checkpoint scan. |
| `acd79d603cb2` | jinja aliases | Chat | Prompt/template | INTEGRATE | Template filter behavior can change rendered prompt. |
| `aedb2a5e9ca3` | Cohere2MoE parser | Chat | Prompt/template | INTEGRATE | Chat parser affects route prompt metadata. |
| `a6dff7127092` | chat whitespace fixes | Chat tests | Prompt/template | INTEGRATE | Parser-generator behavior needs chat regression scan. |
| `e3cab403bfac` | mtmd post-decode callback | HTTP, ctx | Routes | INTEGRATE | Callback changes server context lifecycle. |
| `0ae3f450f0c6` | grammar generator bug | Chat tests | Prompt/template | INTEGRATE | Test surface covers parser behavior. |
| `581e8eca8b41` | harden peg tool call parsing | Chat | Prompt/template | INTEGRATE | Tool-call parser can alter chat prompt/output path. |
| `38d546330ad3` | full unparsed prompt debug | Chat | Diagnostics | INTEGRATE | Debug field scan needed for bounded diagnostics. |
| `7dad2f1a17d6` | LFM2 double escaping | Chat tests | Prompt/template | INTEGRATE | Parser escaping affects route transcript parsing. |
| `635b65ad7a19` | speculative metrics | Spec, metrics | Metrics, MTP | INTEGRATE | Public metric shape and bounded labels need scan. |
| `a1824902b573` | backend sampling for EAGLE3 | Spec | MTP | INTEGRATE | Spec path change follows EAGLE3 rework decision. |
| `890f1a27ed48` | OpenVINO update | Build | Build evidence | NO-OP | Backend packaging only for Stage 35 scope. |
| `4b4d13ae721e` | router model management API | HTTP, ctx | Stage 13 routes | REWORK-REQUIRED | Large router API changes can alter route compatibility; Manager. |
| `968c43891abb` | router args forwarding | HTTP | Routes | INTEGRATE | Child server arg forwarding affects route behavior. |
| `552258c5350d` | router hf preset repo | HTTP | Routes | INTEGRATE | Router option path needs focused smoke. |
| `10786217e9d4` | invalid grammar HTTP 400 | Chat tests | Routes | INTEGRATE | Public error status changes need endpoint check. |
| `08023072ef63` | generation speed display | Ctx, metrics | Metrics | INTEGRATE | Metric/log field scan required. |
| `e1efd0991d85` | schema and validation | HTTP, ctx | Routes | INTEGRATE | Request schema changes need endpoint compatibility scan. |
| `fe7c8b2414bb` | stopping_thread hang | HTTP | Routes | INTEGRATE | Router lifecycle change touches server process management. |
| `32eddaf2ea8d` | UI build readonly source | Build | Build evidence | NO-OP | Build helper only; no local evidence command change expected. |
| `40f3aafc4599` | X-Accel-Buffering header | HTTP | Routes | INTEGRATE | Streaming headers affect public route evidence. |
| `80452d65b9b1` | slot selection consolidation | Ctx | Slot lifecycle | INTEGRATE | Slot selection is protected by cache route contracts. |
| `159d093a43e8` | ctx shifting n_discard | Ctx | Slot/KV | INTEGRATE | Context shift touches KV and slot assumptions. |
| `b14e3fb90ca8` | EAGLE3 qwen3.5/3.6 | Spec, ctx | MTP | INTEGRATE | Spec support follows EAGLE3 rework decision. |
| `8c2d6f6475f2` | `--agent` arg | HTTP, ctx | Routes | INTEGRATE | CLI and route naming need compatibility scan. |
| `fabde3bf5136` | api-key-file comments | HTTP | Routes | NO-OP | Auth file parsing does not touch cache contracts. |
| `175147e8f612` | remove webui mentions | HTTP, ctx | Routes | INTEGRATE | Naming cleanup can affect diagnostics/tests. |
| `4b48a53b6cc6` | token probabilities optimization | HTTP, ctx | Routes | INTEGRATE | Response-shaping path needs route regression. |
| `2b686a9120e2` | child-router communication | HTTP, ctx | Routes | REWORK-REQUIRED | Router IPC refactor may alter server lifecycle and route evidence. |
| `67e9fd3b74b7` | docker prebuild UI | Build | Build evidence | NO-OP | Packaging-only for Stage 35. |
| `e27f30859737` | CORS auth header | HTTP tests | Routes/security | INTEGRATE | Security route behavior needs smoke. |
| `84de01a1f1c8` | quantization LLM_KV | KV | Checkpoint/KV | INTEGRATE | Metadata key change needs checkpoint descriptor scan. |
| `c57607016a1e` | grammar spacing tests | Chat tests | Prompt/template | INTEGRATE | Parser test surface maps to chat route behavior. |
| `063d9c156e81` | peg AC parser | HTTP tests | Routes/tools | INTEGRATE | Tool route parser behavior needs scan. |
| `d789527482d9` | Step3.5/3.7 flash mtp3 | Spec, KV | Stage 5, MTP | REWORK-REQUIRED | New MTP flow changes draft-context semantics; Architect/Manager. |
| `8a118ee86c3b` | speculative whitespace cleanup | Spec | MTP | NO-OP | Mechanical cleanup in spec helper. |
| `d6d899580dcf` | model load progress SSE | HTTP, ctx | Routes/metrics | INTEGRATE | New SSE route surface needs route and metric checks. |
| `bfa3219177c8` | schema verbose field | HTTP, chat | Routes | INTEGRATE | Public schema expansion needs compatibility scan. |
| `2f89acc2bc61` | mtmd load progress callback | HTTP, ctx | Routes/metrics | INTEGRATE | Load progress metrics/logs need scan. |
| `bf533823cd06` | jinja call statement | Chat | Prompt/template | INTEGRATE | Template control flow can alter prompt rendering. |
| `0d135df48cce` | mtmd memory usage fix | HTTP, ctx | Metrics | INTEGRATE | Memory metric source changed. |
| `bddfd2b1137c` | batch construction refactor | Ctx | Slot lifecycle | INTEGRATE | Batch construction touches slot processing. |
| `7c082bc417bb` | spec model load stages | HTTP, ctx | Routes/metrics | INTEGRATE | Loading diagnostics and route output changed. |
| `52b3df002365` | AC parser generation | Chat tests | Prompt/template | INTEGRATE | Parser generation affects chat template tests. |
| `d0f9d2e5ac5d` | edit_file crash | HTTP | Tools route | INTEGRATE | Tool route behavior needs smoke. |
| `6ee0f65793da` | input file schema | HTTP | Routes | INTEGRATE | Request schema change needs endpoint scan. |
| `721354fbdfb7` | model download process | HTTP, ctx | Routes | REWORK-REQUIRED | Child process split can alter server lifecycle and test harness. |
| `dec5ca5577d6` | tool call response id | HTTP, task | Routes | INTEGRATE | Public response schema expansion needs route scan. |
| `73618f27a801` | checkpoints at every user message | Chat, HTTP, ctx | Checkpoint/admission | REWORK-REQUIRED | Upstream checkpoint placement can conflict with Stage 9 and architecture part 9. |
| `75ad0b23ed6d` | remote preset handling | HTTP tests | Routes | INTEGRATE | Router config path needs focused smoke. |
| `be4a6a63eb2b` | draft context creation error | HTTP, ctx | MTP/slot | INTEGRATE | Draft context error handling touches MTP route. |
| `8be759e6f70d` | hexagon cached graphs | Build | Build evidence | NO-OP | Backend script only for Stage 35. |
| `09cedfd6996d` | chat caps harden | Chat | Prompt/template | INTEGRATE | Capability detection affects parser selection. |
| `b3ce5cedf4c0` | quantizing moe with mtp | KV, spec | MTP/KV | INTEGRATE | MTP metadata path needs scan. |
| `e12a0128ab0b` | libmtmd XCFramework | Build | Build evidence | NO-OP | Apple packaging only. |
| `60bc8866b11f` | model handling refactor | HTTP | Routes | INTEGRATE | Model API refactor affects server route setup. |
| `e9d1b76d0ad8` | 403 for disabled features | HTTP tests | Routes | INTEGRATE | Public status change needs compatibility decision. |
| `1a87dcdc452d` | SSE replay buffer | HTTP, ctx | Routes/session | REWORK-REQUIRED | Replay/session behavior overlaps Stage 34 branch/session evidence. |
| `83d385b4294a` | chat-template test fix | Tests | Prompt/template | NO-OP | Test-only unless merge changes parser behavior. |
| `27c8bb4f63ad` | logs reduce v2 | HTTP, ctx, spec | Diagnostics | INTEGRATE | Bounded diagnostics and logs need scan. |
| `d1b34251bc57` | DFlash support | Spec | MTP | REWORK-REQUIRED | New speculative mode needs target/draft contract review. |
| `f68a788b0bf4` | jinja dump-prog | Chat | Prompt/template | INTEGRATE | Debug tool flag, verify no route drift. |
| `c818263f2a5d` | MiniCPM5 parser | Chat | Prompt/template | INTEGRATE | Parser addition affects chat compatibility. |
| `7cb8576e7c35` | stop and reasoning skip | HTTP, ctx | Routes | INTEGRATE | Stream/stop behavior needs endpoint smoke. |
| `b3fed31b99f9` | reasoning-preserve flag | Chat, HTTP, ctx | Prompt/template | INTEGRATE | Prompt rendering flag can affect prompt identity. |
| `8c146a836630` | DeepSeek V4 | KV, spec | Checkpoint/KV | REWORK-REQUIRED | New KV-cache files and model path need checkpoint contract review. |
| `799fcc04a5bb` | IPv6 URL authority | HTTP | Routes | INTEGRATE | Proxy/model URL parsing needs route smoke. |
| `13e673863b36` | hexagon flash rework | Build | Build evidence | NO-OP | Backend scripts only for Stage 35. |
| `fdb1db877c52` | model ftype name | HTTP, ctx | Metrics/routes | INTEGRATE | Server model metadata output changes. |
| `b5315e16e0c3` | SSE ping/kick policy | HTTP, ctx | Routes/session | INTEGRATE | Streaming session policy needs route regression. |
| `152d337fadb9` | DFlash p-min | Spec | MTP | INTEGRATE | Follows DFlash rework decision. |
| `2d973636e292` | StepFun parser trim | Chat | Prompt/template | INTEGRATE | Parser trimming affects prompt/output path. |
| `a4107133a634` | K/V rotation guard | KV, spec | KV/checkpoint | INTEGRATE | KV safety fix likely integrates; verify checkpoint path. |
| `2da668617612` | stale tensor-split draft params | KV, spec | MTP | INTEGRATE | Draft model setup affects MTP fixtures. |
| `48719618e832` | HF_TOKEN UI assets | Build | Build evidence | NO-OP | Asset download helper only. |
| `bfdf581b8b2a` | skip model API test | Tests | Test harness | NO-OP | Temporary upstream test skip; no local contract. |
| `9abce7473ad9` | load_models deadlock | HTTP tests | Routes | INTEGRATE | Router deadlock fix should integrate with route smoke. |

## Aggregate summary

| Decision | Count |
| --- | ---: |
| NO-OP | 13 |
| INTEGRATE | 67 |
| REWORK-REQUIRED | 9 |
| DEFER | 0 |
| REVERT | 0 |

Prior-stage surfaces touched: Stage 5 target/draft MTP, Stage 9 checkpoint
admission, Stage 13 route compatibility, Stage 25 transaction assumptions,
Stage 31/32 metric/namespace shape, Stage 34 branch/session replay evidence,
and architecture part 9 prompt-span boundary.

Expected touched local files and dirs:

- `common/chat.*`, `common/jinja/**`, `common/speculative.*`
- `src/llama-context.*`, `src/llama-graph.*`, `src/llama-model.*`,
  `src/llama-kv-cache*`, `src/llama-quant.cpp`
- `tools/server/server.cpp`, `tools/server/server-context.*`,
  `tools/server/server-common.*`, `tools/server/server-http.*`,
  `tools/server/server-models.*`, `tools/server/server-schema.*`,
  `tools/server/server-stream.*`, `tools/server/server-task.*`,
  `tools/server/server-tools.cpp`
- `tools/server/tests/**`, `tests/test-chat*`, `tests/test-jinja*`,
  `tests/test-chat-template.cpp`
- `scripts/ui-assets.cmake`

## Manager decisions requested

- Dirty worktree policy: confirm the pre-existing dirty state is acceptable for
  this planning-only artifact, or require cleanup before any merge execution.
- Rework threshold: decide whether all 9 REWORK-REQUIRED candidates open
  rework parts before merge execution, or whether some downgrade to INTEGRATE
  with focused checks.
- Router/SSE scope: decide whether router process changes, model-management API,
  and SSE replay/session behavior share one route rework or remain normal
  INTEGRATE items.
- Checkpoint placement: decide how upstream "checkpoints at every user message"
  maps to Stage 9 and architecture part 9 prompt-span boundary.
- MTP/KV scope: decide whether EAGLE3, Step MTP, DFlash, and DeepSeek V4 share
  one MTP/KV rework or separate reworks.

If the source ref changes after this report, reopen analysis and Architect
review before merge execution.

## Open questions

- Does upstream SSE replay buffer overlap Stage 34 replay evidence enough to
  require a Stage 34 rework?
- Do upstream model-download child process changes alter local server launch
  evidence commands or only route internals?
- Should new upstream speculative metrics be preserved as additive public
  metrics, or mapped through the existing bounded metric-label policy first?
- Are chat/template parser changes enough to require a focused prompt-span
  boundary admission row before full regression?
