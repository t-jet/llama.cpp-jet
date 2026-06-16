# Stage 15 benchmark report: B05/B06 structural probe (29-token prompt, 2026-06-13)

- Date: 2026-06-13 local
- Stage: 15 (Full Test Suite Validation, Bug-Fix Loop, and Benchmark Report)
- Sub-session: focused B05/B06 structural probe (29-token prompt; length-matched)
- Owner: QA execution
- Scope: Stage 15 B05/B06 only. Probes whether the MTP fixture's hybrid cache
  can do exact-blob restore when the request task token length matches the
  stored entry token length. Confirms or refutes the 20260613-01 hypothesis
  that the blocker is an entry-length vs task-length mismatch.
- Evidence root (this run): ._test_output/bench-stage15-20260613-b56-rerun30/
- Evidence root (companion 36-token run): ._test_output/bench-stage15-20260613-b56/
- Prior reports:
  - [stage15-benchmark-20260613-01.md](stage15-benchmark-20260613-01.md)
  - [stage15-benchmark-20260612-01.md](stage15-benchmark-20260612-01.md)
- Baseline report:
  - [test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md)

## Status

B05 and B06 remain BLOCKED-no-successful-restores. The 20260613-01
hypothesis ("entry length 30 vs task length 27 mismatch") is REFUTED by
this structural probe. Two independent length-matched runs (36=36 in the
companion b56 run and 29=29 in this rerun30) both produced 0 successful
restores even though every restore attempt matched the LCP prefix at
sim_best=1.000. The structural reason is the MTP fixture's save path
produces entries without checkpoint boundary metadata, so the save is
stored as a regular entry (not a checkpoint) and the exact-blob restore
check rejects it. This is a checkpoint-admission problem, not a
prompt-length problem. The blocker is structural, not infra. Manager
plan-level decision is required to close B05/B06.

## Environment

| Item | Value |
| --- | --- |
| Build directory | build-cov Release |
| Binary | build-cov/bin/Release/llama-server.exe (27,117,056 bytes, 2026-06-13 00:13:52) |
| Git commit (work-branch HEAD) | 13d3cd86303dbe5e457c1c3cabf15671882209da |
| MTP fixture | ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf |
| Jinja template | chat_template_new.jinja (Stage 13 marked variant) |
| Server PID | started 2026-06-13 08:39, stopped 2026-06-13 08:40 |
| Port | 8604 |
| Server flags | --model MTP --jinja --chat-template-file chat_template_new.jinja --ctx-size 4096 --parallel 1 --cache-mode hybrid --cache-ram 100 --metrics --temp 0 --seed 42 |
| Request body (50 iter) | {"prompt":"S12-B05 restore latency probe with long shared prefix v0 v1 v2 v3 v4 v5 v6 v7","n_predict":0,"temperature":0,"seed":42,"cache_prompt":true} |
| Prompt token count | 29 (target 30; BPE could not land on 30) |
| n_predict | 0 (slot saves with exactly prompt token count) |
| Iterations | 50 |
| OK | 50 |
| Fail | 0 |
| Wall time (request batch) | 79s |
| Output dir | ._test_output/bench-stage15-20260613-b56-rerun30/ (gitignored) |

## Build evidence

The build-cov Release llama-server.exe from 2026-06-13 00:13:52 is
unchanged from the 20260613-01 and 20260612-01 runs. The QA improvement
memory entry on re-execution binary freshness allows skipping a fresh
clean build when the binary content is preserved from the prior
no-op-rebuild confirmation against the same source tree. No fresh build
was performed in this structural probe.

## Per-row results

Both rows remain BLOCKED with new hard evidence. Length-matching the
prompt (29-token prompt, 29-token stored entry) does not unlock the
exact-blob restore. The b56 companion run (36-token prompt, 36-token
stored entry) reaches the same conclusion independently.

| Row | Metric | Verdict | Evidence |
| --- | --- | --- | --- |
| B05 | Restore latency p50 | BLOCKED-structural-not-infra | 50/50 requests returned cache_n=0; 50/50 LCP-found-match at sim_best=1.000 with task 29, entry 29, prefix 29; 50/50 no-exact-match; 1 save with checkpoint admission skipped (missing checkpoint boundary metadata); 0 successful restore; 0 cache_n>0 events |
| B06 | Restore latency p99 | BLOCKED-structural-not-infra | same; 0 successful restore in 50 iterations |

## Hard evidence for B05/B06 BLOCKED-structural

Counts from server.stderr.log and per-request CSV (50-iter workload):

- 50 requests, all 200 OK
- 50 cache_n=0 events in response body (0 cache_n>0 across the batch)
- 1 save_slot event (the first request stored the prompt in cache)
- 1 "checkpoint admission skipped (missing checkpoint boundary metadata)" warning
- 50 try_restore - found match events (LCP prefix match on all subsequent requests)
- 51 try_restore - no exact match found events (warmup + 50 iterations)
- 0 cache_checkpoint_admissions (the save is never admitted as a checkpoint)
- 1 cache_checkpoint_admission_failures (the only save that tried checkpoint admission)
- Final /metrics: llamacpp_cache_entries=1, llamacpp_cache_tokens=29, llamacpp_cache_hits_total=0, llamacpp_cache_misses_total=51, llamacpp_cache_hot_payload_descriptors=1

The save_slot log line on the first request:

```text
save_slot:  - hybrid cache: saving slot 0 with 29 tokens, state size = 51.158 MiB
save_slot:  - hybrid cache: checkpoint admission skipped (missing checkpoint boundary metadata)
save_slot:  - hybrid cache: successfully saved slot 0 (namespace: 11845770371599200376, entries: 1)
```

The try_restore log line on every subsequent request:

```text
try_restore_:  - hybrid cache: try_restore - found match: task 29 tokens, entry 29 tokens, prefix 29
try_restore_:  - hybrid cache: try_restore - no exact match found
```

The LCP match is perfect (task 29, entry 29, prefix 29) but the
exact-blob restore still fails because the saved entry is not a
checkpoint (admission was skipped).

## Cross-run structural confirmation

Three independent runs on the MTP fixture all show the same
exact-blob-restore failure pattern. The b56 companion run and this
rerun30 prove the failure is NOT caused by the request task length
differing from the stored entry length.

| Run | prompt | task | entry | prefix | LCP-found | no-exact | admission-skip | restore_hits | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20260612-01 (7 distinct) | varies | 27 | 30 | 27 | 49 | 50 | 1 | 0 | BLOCKED (theory: length mismatch) |
| 20260613-01 (50 identical) | 27 | 27 | 30 | 27 | 49 | 50 | 1 | 0 | BLOCKED (theory: length mismatch) |
| b56 (50 identical, 36) | 36 | 36 | 36 | 36 | 50 | 50 | 1 | 0 | BLOCKED (length matched, but still fails) |
| rerun30 (50 identical, 29) | 29 | 29 | 29 | 29 | 50 | 51 | 1 | 0 | BLOCKED (length matched, but still fails) |

The 20260613-01 "task 27 tokens, entry 30 tokens, prefix 27" reading
was a misread of a pre-200-iter log line. The first run's stored entry
was 30 tokens because that warmup used a different prompt body
(`v2 fixed MTP restore probe checkpoint admitting variant`); the 27-
token body in the main 50-iter batch was 27 tokens but the stored
entry was from the 30-token first request. Once the prompt is
tokenized to match the entry length (b56 with 36, rerun30 with 29),
the LCP match is perfect and the exact-blob restore STILL fails. The
real cause is the checkpoint admission, not the length.

## Comparison with V2 baseline (separate-draft fixture)

| Metric | V2 baseline | Stage 15 20260613-02 (MTP) | Verdict |
| --- | --- | --- | --- |
| B05 restore latency p50 | PASS, 95/96 hits (Qwen3-8B + Qwen3-0.6B draft) | BLOCKED-structural, 0/50 hits | fixture difference, not infra |
| B06 restore latency p99 | PASS, 23/24 hits (Qwen3-8B + Qwen3-0.6B draft) | BLOCKED-structural, 0/50 hits | fixture difference, not infra |
| Checkpoint admission failures | 0 in V2 (separate-draft fixture, no checkpoint path exercised) | 1 in this run (the only save that tried) | MTP fixture does attempt checkpoint admission but skips it on the save path |

The V2 fixture is separate-draft (Qwen3-8B target + Qwen3-0.6B draft
via draft-simple). The V2 path admits regular cache entries and gets
hits. The MTP fixture is the only one in scope that exercises the
checkpoint path, and the MTP save path produces non-checkpoint entries.
V2 had no checkpoint metrics exposed; the MTP build exposes the four
cache_checkpoint_* rows and shows the admission skip in /metrics.

## Regression-detection section

No new metric has a non-zero product delta. The B01 zero hit rate
and the B05/B06 zero restore rate are EXPECTED-COST for the MTP
fixture (not product bugs). The structural pattern (save without
checkpoint boundary metadata) is consistent across b56 and rerun30
on the same build, so it is not a regression introduced in this
sub-session. EXPECTED-COST, TUNING-GAP, PRODUCT-BUG, TOOLING-GAP,
and LEGACY-REGRESSION classifications per Stage 12 design part 3 are
deferred to the Manager closure decision.

## Legacy comparison

Not produced. The V2 bench report records no legacy throughput or
latency row for B05, B06 (V2 only had request_count and evictions
columns for these rows).

## Aggregate verdict

| Class | Count |
| --- | --- |
| PASS (incl. PASS-observed-zero) | 0 (this run only covers B05/B06) |
| FAIL | 0 |
| BLOCKED-structural-not-infra | 2 (B05, B06) |
| Total rows in this report | 2 |

The 6 PASS rows from 20260613-01 (B01, B02, B03, B04, B07, B08) are
not re-evaluated here; this report is a focused structural probe for
B05/B06 only.

## State-check evidence

- Get-Process at session start: 0 llama-server.exe running.
- Start-Process llama-server with MTP fixture and chat_template_new.jinja
  on port 8604 reached /health 200 within 120s.
- /metrics captured before workload (20,124 bytes) and after workload
  (20,246 bytes). The 122-byte growth is from one new
  cache_checkpoint_admission_failures counter increment and the
  hybrid cache entries/bytes/tokens deltas.
- 50 /completion requests issued, 50 returned 200 OK, 0 failed.
- Stop-Process terminated the server cleanly. Get-Process llama-server
  after stop: 0.

## Manager plan-level decision required

The 20260613-01 hypothesis is refuted. The blocker is structural, not
infra. Three closure options for the Manager, in priority order:

Option 1 (recommended): Reclassify B05/B06 to `NOT-IN-SCOPE` for the
MTP fixture. Document in the Stage 15 part-25 test plan that B05/B06
require a fixture that admits checkpoints via the natural save path.
Use the V2 separate-draft fixture (Qwen3-8B + Qwen3-0.6B draft) for
B05/B06 in a future stage. Reference: V2 B05 had 95/96 hits.

Option 2: Add a Developer task to make the MTP fixture's hybrid
cache save path emit checkpoint boundary metadata. Re-run B05/B06
after the fix. This is a product change and requires Architect
design review and a Stage 16 or backport decision.

Option 3: Drop B05/B06 from the Stage 15 matrix entirely. Mark the
stage as `B05/B06 out of scope; see Manager closure decision` and
move on. This violates the Stage 12 design part 3 acceptance rule
that B05/B08 are required for the bench artifact, so this is the
least-preferred option.

## Exact Manager plan decision text (recommended)

> Stage 15 B05/B06: BLOCKED-structural-not-infra. The MTP fixture's
> hybrid cache save path produces entries without checkpoint boundary
> metadata, so the stored entry is never a checkpoint and the
> exact-blob restore check rejects every subsequent identical
> request. The 20260613-01 length-mismatch hypothesis is refuted by
> the b56 36=36 run and this rerun30 29=29 run. Decision:
> reclassify B05/B06 to NOT-IN-SCOPE for the MTP fixture. The Stage
> 15 part-25 test plan records that B05/B06 require a fixture that
> admits checkpoints via the natural save path. Future stage to
> exercise B05/B06 on the V2 separate-draft fixture
> (Qwen3-8B + Qwen3-0.6B draft) which had 95/96 and 23/24 hits in V2.

## Handoff

- This structural probe is the current Stage 15 B05/B06 evidence
  at ._design_docs/.test_reports/stage15-benchmark-20260613-02.md.
- Raw evidence: ._test_output/bench-stage15-20260613-b56-rerun30/
  (metrics-before.txt, metrics-after.txt, requests.csv, summary.json,
  summary.txt, server.stderr.log, warmup.log, tokenize.log,
  run-b05-b06-rerun30.ps1).
- Companion 36=36 evidence: ._test_output/bench-stage15-20260613-b56/
  (same files, 36-token prompt).
- Supersedes 20260613-01 B05/B06 BLOCKED-no-successful-restores
  with BLOCKED-structural-not-infra and refutes the length-mismatch
  hypothesis.
- No Stage 15 design, implementation, test plan, or other durable
  docs were modified.

NEEDS-MANAGER-DECISION (B05/B06 BLOCKED-structural-not-infra; see
Manager plan-level decision section above for the recommended exact
text).
