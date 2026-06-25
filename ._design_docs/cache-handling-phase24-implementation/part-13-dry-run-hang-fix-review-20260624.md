# Part 13: dry-run hang fix review 2026-06-24

Status: PASS
Date: 2026-06-24
Owner: Architect
Scope: Stage 24 bug-fix review gate for the dry-run hang fix. Review only; no
full live comparison and no product code changes.

## Inputs reviewed

- `._design_docs/.test_reports/test-report-20260624-01.md`
- `._design_docs/cache-handling-phase24-implementation/part-12-dry-run-hang-fix-20260624.md`
- `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
- `._design_docs/cache-handling-test-plan/part-29-stage24-chat-s02-s03-comparison.md`
- `._design_docs/cache-handling-test-plan/stage-24-manager-cuda-rerun-gate-20260624.md`
- `._design_docs/cache-handling-phase24-implementation/part-11-implementation-correction-review-20260624.md`

## Verdict

PASS.

No blocking architectural, runner-contract, or documentation findings remain for
this bug fix. Manager may reopen fresh Stage 24 CUDA QA execution with a new
report/run suffix. The blocked `test-report-20260624-01.md` remains setup
evidence only.

## Decisions

1. Root cause and evidence: PASS.

   The blocked report shows the required CUDA dry-run and S02 diagnostic
   dry-run hung before `dry-run-plan.json`, with no live leg started
   (`test-report-20260624-01.md:61`, `test-report-20260624-01.md:74`,
   `test-report-20260624-01.md:120`). Part 12 ties the hang to Windows
   PowerShell 5 `ConvertTo-Json -Depth 12` inside `Write-JsonFile` and records
   that PowerShell 7 did not reproduce it (`part-12-dry-run-hang-fix-20260624.md:19`,
   `part-12-dry-run-hang-fix-20260624.md:28`). That diagnosis is plausible for
   the QA path because the Manager gate and runner command use the Windows
   PowerShell `-File` shape.

2. JSON serializer contract: PASS.

   `Write-JsonFile` now serializes a bounded plain-object copy before calling
   `ConvertTo-Json` (`stage24-chat-s02-s03-comparison.ps1:71`). The helper keeps
   nulls, strings, booleans, numeric values, dictionaries, arrays, and readable
   object properties (`stage24-chat-s02-s03-comparison.ps1:91`). Unsupported
   leaves are bounded by depth and converted to strings, so the runner does not
   walk arbitrary wrapper objects indefinitely. The reviewed plan JSON retained
   rows, variants, route, paths, CUDA build proof, request classes, and flags.
   Live `summary.json` and `comparison.json` use the same writer, but their
   source objects are runner-owned ordered dictionaries and arrays, so the shape
   is preserved.

3. Row normalization: PASS.

   `Normalize-RowsToRun` splits comma-delimited scalar input, trims empty parts,
   and rejects an empty row list (`stage24-chat-s02-s03-comparison.ps1:124`).
   It does not silently accept invalid row ids because `Get-Plan` still calls
   `Get-RowSpec`, which throws on unsupported rows
   (`stage24-chat-s02-s03-comparison.ps1:397`). Local review check:
   `-RowsToRun BAD-chat -DryRun` rejected with `Unsupported Stage 24 row
   'BAD-chat'` and wrote no plan.

4. Dry-run behavior: PASS.

   The `-DryRun` branch creates `RunRoot`, writes `dry-run-plan.json`, prints one
   status line, and exits before any live execution block
   (`stage24-chat-s02-s03-comparison.ps1:1097`). `Start-Process` and all HTTP
   calls are below that branch or inside request helpers
   (`stage24-chat-s02-s03-comparison.ps1:652`,
   `stage24-chat-s02-s03-comparison.ps1:940`). Local Windows PowerShell checks:
   S02-only plan wrote 1 row and 2 legs; full scalar child-process plan wrote 2
   rows and 4 legs in 444 ms; normal string-array input wrote 2 rows and 4 legs.
   `llama-server` process count stayed 0.

5. CUDA, route, and flag proof: PASS.

   The runner sets one route, `/v1/chat/completions`
   (`stage24-chat-s02-s03-comparison.ps1:28`), and puts that route in the plan
   and leg request paths (`stage24-chat-s02-s03-comparison.ps1:409`,
   `stage24-chat-s02-s03-comparison.ps1:430`). `Get-ServerFlags` adds
   `--n-gpu-layers all` and `--fit off` to every variant leg
   (`stage24-chat-s02-s03-comparison.ps1:374`). `Get-Plan` exposes
   `cuda_build_proof` (`stage24-chat-s02-s03-comparison.ps1:440`). Local plan
   inspection found `badRoute=0`, `badFlags=0`, and `cuda=PASS` for S02-only,
   full scalar child-process, and full array dry-runs.

6. S02 and S03 policies: PASS.

   The active test plan still carries the S02 `FAIL-http-request` risk and
   requires preservation of request/log evidence if it reproduces
   (`part-29-stage24-chat-s02-s03-comparison.md:36`,
   `part-29-stage24-chat-s02-s03-comparison.md:282`). The S03 unsafe-prefix
   policy still fails only hybrid near-prefix nonzero `cache_n`; native
   near-prefix `cache_n` remains diagnostic
   (`part-29-stage24-chat-s02-s03-comparison.md:283`). The runner implements the
   same distinction in `Get-NearPrefixRestoreCheck`
   (`stage24-chat-s02-s03-comparison.ps1:521`).

7. Documentation and hygiene: PASS.

   Part 12 records the fix scope, evidence, and residual risk without changing
   product behavior. The implementation entry and document index now link this
   review state. Reviewed and edited documents stay below 300 lines, ASCII-only,
   LF-only, no UTF-8 BOM, and no trailing whitespace. `git diff --check` is
   clean for the reviewed paths.

## Required corrections

None.

## Handoff

State: ready for Manager handoff.

Manager may reopen fresh Stage 24 CUDA QA execution with a new
`test-report-YYYYMMDD-NN.md` suffix and matching run root. QA should rerun the
dry-run gate first, then proceed to live S02/S03 only if the new plan and CUDA
proof pass.
