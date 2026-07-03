# Stage 34 TP-34-RN-02 renderer fix (bug-fix iteration 1)

Status: bug-fix iteration 1 complete
Date: 2026-06-30
Stage: 34
Owner: Developer
Branch: work-branch
Scope: single-row product bug TP-34-RN-02 only

## Scope

This part is the implementation evidence for the bug-fix iteration opened by the
Stage 34 test-results Developer review on TP-34-RN-02 (PRODUCT-BUG verdict).
The test plan row text (part-37 L120, verbatim):

> "Per-event raw prompt files appear under `raw-prompts/` (or the documented
> sibling path); no raw prompt bytes leak into `events.jsonl`, `requests.jsonl`,
> `summary.json`, or any durable Markdown output."

The pre-fix `Export-Stage34ReplayRequests` inlined raw prompts into the
`request-{id}.json` file via `ConvertTo-Stage34ChatRequest -IncludeRawPrompts`
but never created the `raw-prompts/` sibling directory. The fix adds the
sibling directory creation and a per-event raw prompt file write to that
sibling path, while leaving the existing redaction (events.jsonl via
`Select-Object * -ExcludeProperty messages`, requests.jsonl metadata-only,
summary.json counts-only) untouched.

## File changed

`._design_docs/cache-handling-test-scripts/lib/stage34-request-renderer.ps1`

Diff stat (lines added / removed):

- Lines added: 13 (new directory-creation block before `$eventsPath` line,
  new per-event raw-prompt write block inside the foreach after the
  `Set-Content -LiteralPath $requestPath` line)
- Lines removed: 0
- Net file size: 4153 bytes -> 4825 bytes (+672 bytes)
- Net line count: 110 LF -> 123 LF (+13 lines)

Function touched: `Export-Stage34ReplayRequests` (was L78-L114; now L78-L127).
Other functions in the file (`Write-Stage34JsonLine`,
`Get-Stage34RenderedTokenInfo`, `ConvertTo-Stage34ChatRequest`) are unchanged.

`ConvertTo-Stage34ChatRequest` (was L40-L71) is intentionally untouched per
brief: the function inlines raw prompts into the `request-{id}.json` body when
`-IncludeRawPrompts` is set, and the test-plan exclusion list (events.jsonl,
requests.jsonl, summary.json, durable Markdown) does not include
`request-{id}.json`. Keeping the inline behavior preserves the existing
`request-{id}.json` shape for callers that depend on it.

## Patch shape

After the existing `New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null`:

```powershell
$rawPromptsDir = $null
if ($IncludeRawPrompts) {
    $rawPromptsDir = Join-Path $OutputDir "raw-prompts"
    New-Item -ItemType Directory -Force -Path $rawPromptsDir | Out-Null
}
```

Inside the `foreach ($event in $Events)` loop, immediately after the existing
`Set-Content -LiteralPath $requestPath -Encoding utf8NoBOM` call:

```powershell
if ($IncludeRawPrompts -and $event.messages -and $event.messages.Count -gt 0) {
    $rawPromptPath = Join-Path $rawPromptsDir ("request-{0}.json" -f $event.request_id)
    [pscustomobject]@{
        request_id = $event.request_id
        transcript_row = $event.transcript_row
        messages = $event.messages
    } | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $rawPromptPath -Encoding utf8NoBOM
}
```

Field name holding the raw messages: `$event.messages` (verified by reading
the existing call `Get-Stage34RenderedTokenInfo -Request $request -PlanMessages @($event.messages)`
on the line directly below the new raw-prompt block; same field is the input
the parser populates from each fixture row's `messages` array).

## Evidence

### Dry-run re-execution (TP-34-RN-02 row)

Command (preceded by a fresh output-dir allocation):

```pwsh
$prevOutput = '_test_output/stage34-TP-34-RR-02'
if (Test-Path $prevOutput) { Remove-Item $prevOutput -Recurse -Force }
pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 `
    -OutputDir $prevOutput `
    -Mode dry-run `
    -IncludeRawPrompts
```

Result:

- Exit code: 0
- summary.json `raw_prompt_capture: true`
- 6 transcript rows, 6 replay events, all captured (matches prior dry-run shape)

### New artifacts

| Path | Test-Path | Notes |
| --- | --- | --- |
| `_test_output\stage34-TP-34-RR-02\raw-prompts` | True | new sibling directory created by patch |
| `_test_output\stage34-TP-34-RR-02\raw-prompts\request-row-00001.json` | True | 224 B |
| `_test_output\stage34-TP-34-RR-02\raw-prompts\request-row-00002.json` | True | 232 B |
| `_test_output\stage34-TP-34-RR-02\raw-prompts\request-row-00003.json` | True | 232 B |
| `_test_output\stage34-TP-34-RR-02\raw-prompts\request-row-00004.json` | True | 234 B |
| `_test_output\stage34-TP-34-RR-02\raw-prompts\request-row-00005.json` | True | 236 B |
| `_test_output\stage34-TP-34-RR-02\raw-prompts\request-row-00006.json` | True | 232 B |
| `Get-ChildItem _test_output\stage34-TP-34-RR-02\raw-prompts).Count` | 6 | matches fixture row count |
| `_test_output\stage34-TP-34-RR-02\summary.json` | True | reports `raw_prompt_capture: true` |

Sample raw-prompt file content (`request-row-00001.json`, 224 B):

```json
{
  "request_id": "row-00001",
  "transcript_row": 1,
  "messages": [
    { "role": "system", "content": "manager agent" },
    { "role": "user", "content": "plan stage" }
  ]
}
```

Fixture source (`synthetic-agentic.jsonl` row 1): identical content. The raw
prompt bytes round-trip correctly.

### No-leak verification

| File | `role`/`content` raw bytes | Status |
| --- | --- | --- |
| `events.jsonl` | absent | PASS, no raw prompt bytes |
| `requests.jsonl` | absent | PASS (its contract is metadata-only) |
| `summary.json` | absent | PASS (its contract is counts-only) |
| durable Markdown output | absent | PASS, durable docs not touched |

The brief's literal substring check
`(Get-Content events.jsonl -Raw) -match 'messages'` returns `True` because the
events.jsonl row string contains the pre-existing field names
`messages_sha256` (hash field name) and the pre-existing enum value
`prompt_source: "captured_messages"`. These are NOT raw prompt bytes; they
are metadata that already existed in the pre-fix `events.jsonl` (file size
5991 B before fix = 5991 B after fix, row count 6 unchanged). The leak
contract is "no raw prompt bytes" (role/content payloads), which the strict
check `(events.jsonl -match '"role"')` and `(events.jsonl -match '"content"')`
both confirm as False.

`requests.jsonl` content is metadata-only (per its existing contract):
`request_id`, `transcript_row`, `blocked_reason`, `request_body_path`. The
`-match 'messages'` substring returns False on `requests.jsonl` because
neither the field names nor the values contain the substring.

`summary.json` content is counts-only:
`mode`, `transcript_path`, `transcript_rows`, `replay_events`,
`captured_events`, `reconstructed_events`, `blocked_events`,
`events_path`, `requests_path`, `expected_hits_path`, `raw_prompt_capture`.
No raw prompt bytes anywhere.

## Hygiene

| Check | Result |
| --- | --- |
| `git status --short` before fix | the file `stage34-request-renderer.ps1` was untracked (under `?? ._design_docs/cache-handling-test-scripts/lib/...`); patch landed on the untracked file |
| `git status --short` after fix | same untracked file with edit applied |
| `git diff --check -- ._design_docs/cache-handling-test-scripts/lib/stage34-request-renderer.ps1` | exit code 0 |
| Byte-level LF scan on the patched file | CR=0, LF=123 (was 110), last 3 bytes `10,125,10` (LF + `}` + LF, file ends with LF); no BOM; no trailing whitespace on patched lines |
| `Select-String -Path .../stage34-request-renderer.ps1 -Pattern 'raw-prompts'` | one hit at L85 (`$rawPromptsDir = Join-Path $OutputDir "raw-prompts"`), confirms the literal sibling-path string is present |
| Final line count | 123 lines (was 110); still under the 300-line cap with a 177-line buffer |
| Trailing-whitespace scan on the patched file | none |
| Non-ASCII scan on the patched file | none |

## Out of scope (per brief)

- Production C++ code (`tools/server/`, `src/`, `include/`, `common/`, `ggml/`)
  untouched.
- Test code, fixtures, or `replay-agentic-transcript.ps1` driver untouched.
- Test plan `part-37-stage34-real-agentic-transcript-replay.md` untouched.
- Stage 34 design doc untouched.
- Existing implementation parts 01..06 untouched (additive only).
- No commit or push performed.

## Handoff

State: implementation review pending (Architect bug-fix review gate).

Next owner: Architect for bug-fix review of the TP-34-RN-02 renderer patch.

Next gate: After Architect bug-fix review PASS, the test-results review row
TP-34-RN-02 reclassifies from FAIL-implementation-gap to PASS, and Stage 34
follows the same closure PARTIAL pattern as Stage 33 (1 PARTIAL + 9
wall-clock-limited BLOCKED, equivalent to Stage 33).
