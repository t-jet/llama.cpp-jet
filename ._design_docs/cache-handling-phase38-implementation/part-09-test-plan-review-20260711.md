VERDICT: REWORK

# Stage 38 test-plan review

Date: 2026-07-11
Reviewer: Architect
Scope: Stage 38 test-plan artifacts after Manager implementation gate PASS

## Scope and gate status

This is a fresh test-plan review only. No production code, tests, staging,
commits, pushes, reverts, or execution runs were performed.

Reviewed artifacts:

- `._design_docs/cache-handling-phase38-implementation/part-08-qa-test-plan-20260711.md`
- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md`
- `._design_docs/cache-handling-test-scripts/stage38-prefix-restore-and-cold-budget.ps1`
- `._design_docs/cache-handling-test-scripts/README.md`

Baseline checked:

- Approved Stage 38 design entry and observability/test part.
- Manager design gate constraints from design part 07.
- Architect implementation re-review PASS in implementation part 06.
- Manager implementation gate PASS in implementation part 07.
- Manager test-plan review criteria: current scope, generic wording, stale
  content removal, clear evidence format, clean-build rule, ASCII status
  labels and no unicode icons, automation and README alignment, and complete
  TP-38 row coverage.

Gate result: REWORK. QA must correct the test-plan artifacts and return for
test-plan re-review before Manager can open execution.

## Findings

### F38-TP-01: live suffix evidence does not verify `timings.cache_n`

Blocking.

The Stage 38 design requires accepted partial restore reporting through all
cache-specific fields:

- `slot.n_prompt_tokens_cache`
- `timings.cache_n`
- `usage.prompt_tokens_details.cached_tokens`

Part 42 correctly lists the requirement: a model-backed
`/v1/chat/completions` suffix run must prove `timings.cache_n` equals the
accepted prefix length. The implementation log also keeps this as a live QA
requirement after implementation PASS.

The Stage 38 standalone script does not extract or assert `timings.cache_n`.
It parses only:

- `usage.prompt_tokens`
- `usage.prompt_tokens_details.cached_tokens`
- `llamacpp:cache_hits_total{mode="hybrid"}`
- `cache_prefix_candidates_total`
- `llamacpp:cache_cold_budget_bytes{mode="hybrid"}`

The generated report rows likewise omit `timings.cache_n`. A QA execution could
therefore PASS the Stage 38 live row while the OpenAI-compatible cached-token
field is positive but the direct timing field is missing, zero, or unequal to
the accepted prefix length.

Required correction:

- Update `stage38-prefix-restore-and-cold-budget.ps1` to extract
  `timings.cache_n` from the suffix response or another binding direct-stats
  channel.
- Assert `timings.cache_n == usage.prompt_tokens_details.cached_tokens` for the
  suffix turn.
- Include both values in the report row evidence.
- Update README and part 42 so they name this assertion in the script contract.

Acceptance check:

- The script cannot return PASS for `TP-38-PR-02-live` unless cached tokens are
  positive and `timings.cache_n` equals the same accepted prefix length.

### F38-TP-02: full `prompt_tokens` proof is weaker than the plan contract

Blocking.

Part 42 says the standalone Stage 38 verification adds "full public
`prompt_tokens` equal to request length." The design says public
`usage.prompt_tokens` must remain the full request prompt length, not the
restored prefix length.

The script comments acknowledge that stronger contract, but the actual check is
only:

```powershell
$fullOk = $promptTokens -gt $cachedTokens
```

That proves `prompt_tokens` is not exactly the cached prefix length. It does
not prove the value equals the full rendered request length. A wrong value such
as `cachedTokens + 1` could still pass.

Required correction:

- Either add a binding way to compute the full rendered request token count and
  assert `usage.prompt_tokens` equals it, or narrow the durable plan wording so
  the accepted evidence explicitly proves only "not prefix length alone."
- If exact full-length proof is not feasible in the standalone script, keep the
  exact full-length requirement assigned to a separate live evidence row and
  make the script row a partial helper, not a PASS condition for the whole
  model-backed contract.

Acceptance check:

- Part 42, README, the script, and the report row all describe the same
  `prompt_tokens` evidence strength.
- A QA report cannot claim the full Stage 38 public-token row from a check that
  only proves `prompt_tokens > cached_tokens`.

### F38-TP-03: script README metadata is stale after Stage 38 additions

Blocking for documentation hygiene.

`cache-handling-test-scripts/README.md` now contains the Stage 38 script
section and command, but its header still says:

```text
Last updated: 2026-07-10
```

The reviewed QA handoff says the README was updated for Stage 38 on
2026-07-11. The stale header conflicts with that change and fails the
test-plan review criterion that stale content is removed and README alignment
is clear.

Required correction:

- Update the README `Last updated` field to 2026-07-11.
- Keep the Stage 38 section aligned with the corrected script behavior from
  F38-TP-01 and F38-TP-02.

Acceptance check:

- README header date matches the Stage 38 test-plan update session and its
  Stage 38 section matches the actual script assertions.

## Decisions

The following checks passed and do not need rework unless later edits disturb
them:

- Scope is current for approved Stage 38: chat strict-prefix partial restore
  and D36-FU-01 cold-budget gauge.
- `/completion` prefix restore remains out of scope and recompute-only.
- TP-38-PR-01 through TP-38-PR-10 and TP-38-MET-01/02 all have at least one
  named evidence path.
- Clean Release build and stale-binary rules are documented.
- Status labels in Stage 38 plan/report/script output are plain ASCII:
  `PASS`, `FAIL`, `SKIP`, and `BLOCKED`.
- No unicode status icons were found in the reviewed Stage 38 additions.
- The cold-budget live gauge check looks for
  `llamacpp:cache_cold_budget_bytes{mode="hybrid"} 2147483648`.
- The script records request/response and metrics artifacts under a
  non-durable run root and writes only the Markdown report to the durable
  reports directory.
- Reviewed Stage 38 files are LF-only, no BOM, and ASCII-only. The script
  README has pre-existing non-ASCII em dash characters outside the Stage 38
  section; they are not unicode status icons and are not a Stage 38 label
  issue.

## Required corrections

QA must update:

- `._design_docs/cache-handling-test-scripts/stage38-prefix-restore-and-cold-budget.ps1`
- `._design_docs/cache-handling-test-scripts/README.md`
- `._design_docs/cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md`
- `._design_docs/cache-handling-phase38-implementation/part-08-qa-test-plan-20260711.md`

After correction, return for Architect test-plan re-review. Do not proceed to
Manager test-plan gate or QA execution until the re-review passes.

## Handoff state

State: re-review required.

Next owner: QA.

Next gate: test-plan correction, then Architect test-plan re-review.
