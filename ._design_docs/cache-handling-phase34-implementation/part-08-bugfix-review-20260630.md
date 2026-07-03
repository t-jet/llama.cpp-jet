# Stage 34 TP-34-RN-02 renderer fix - bug-fix review (Architect)

Status: bug-fix review PASS
Date: 2026-06-30
Stage: 34
Owner: Architect
Branch: work-branch
Subject: TP-34-RN-02 renderer fix in `stage34-request-renderer.ps1`
Evidence source: [part-07 renderer fix](part-07-renderer-fix-20260630.md)
Next gate: QA rerun of TP-34-RN-02

## Skill load

Architect gate 8.4: self-improvement skill + `assets/architect.md` memory,
architect skill, and caveman skill (ultra for internal thinking, full for
chat) all read before any tool use. Skill loads and memory scan complete.

## Verdict

VERDICT: PASS

All eight required checks pass. Patch lands at L78-L127 of
`Export-Stage34ReplayRequests`, adds the `raw-prompts/` sibling directory
and per-event raw prompt files, and leaves the events/requests/summary
redaction contracts intact.

## Per-check verdict

| Check | Decision rule | Result | Citations |
| --- | --- | --- | --- |
| Test plan conformance | part-37 L120 PASS signal verbatim | PASS | [part-37 L120](cache-handling-test-plan/part-37-stage34-real-agentic-transcript-replay.md#L120) |
| Sibling directory | raw-prompts present, count=6 | PASS | renderer L84-L88 |
| Per-event file content | round-trip fixture messages | PASS | renderer L94-L103 |
| No leakage | no role/content in events/requests/summary | PASS | evidence part-07 §No-leak verification |
| Source correctness | only Export-Stage34ReplayRequests touched, +13 lines | PASS | renderer L78-L127 |
| Hygiene | LF-only, no BOM, no trailing whitespace, git diff --check exit 0 | PASS | byte scan below |
| Implementation log | pre/post diff, dry-run, hygiene | PASS | evidence part-07 §Patch shape, §Hygiene |
| Stage tracker | row 34 additively extended | PASS | stage-tracker.md L60 |

## New checks run

Source snippets from pwsh on `D:\source\llama.cpp-jet`.

### 1. Sibling directory existence and count

````pwsh
Test-Path _test_output\stage34-TP-34-RR-02\raw-prompts  --> True
(Get-ChildItem _test_output\stage34-TP-34-RR-02\raw-prompts).Count  --> 6
````

Six files: `request-row-00001.json` .. `request-row-00006.json`, matching
the six fixture rows.

### 2. summary.json raw_prompt_capture flag

````pwsh
$summary.raw_prompt_capture  --> True
````

### 3. events.jsonl no-leak substring checks

````pwsh
events -match '"role"'    --> False
events -match '"content"' --> False
events bytes=5991 lines=6 (pre-fix 5991 bytes; evidence part-07 §No-leak)
````

Substring `messages` returns True because each row contains the pre-existing
`messages_sha256` field name and enum value `prompt_source: "captured_messages"`.
Not raw prompt bytes. Evidence part-07 flags this regex artefact.

### 4. requests.jsonl metadata-only contract

````pwsh
requests -match 'messages' --> False
length=1044 (request_id, transcript_row, blocked_reason, request_body_path)
````

### 5. Per-event file round-trip

````pwsh
Get-Content raw-prompts\request-row-00001.json | ConvertFrom-Json
````

Parses. messages array contains:

- { role: "system", content: "manager agent" }
- { role: "user", content: "plan stage" }

Fixture row 1 (`synthetic-agentic.jsonl`) contains the identical messages
array. Round-trip exact.

### 6. Source-correctness byte scan (renderer)

````pwsh
[System.IO.File]::ReadAllBytes(...stage34-request-renderer.ps1)
CR=0  LF=123  bytes=4825
first3 = 53 65 74   (= "Set", no UTF-8 BOM)
last3  = 0a 7d 0a   (= LF + "}" + LF, clean LF wrap)
trailing_whitespace=0
````

Line count 123 (was 110 per evidence; +13 lines). Matches the L78-L114 to
L78-L127 net +13 lines claim from evidence part-07 §Patch shape.

### 7. Select-String on patch marker

````pwsh
Select-String -Path ...stage34-request-renderer.ps1 -Pattern 'raw-prompts'
85: $rawPromptsDir = Join-Path $OutputDir "raw-prompts"
````

Single occurrence inside `Export-Stage34ReplayRequests` body. Other
functions (`Write-Stage34JsonLine`, `Get-Stage34RenderedTokenInfo`,
`ConvertTo-Stage34ChatRequest`) carry no `raw-prompts` string. Their bodies
match the unchanged baseline described in evidence part-07 §Out of scope.

### 8. git diff --check

````pwsh
git diff --check -- ._design_docs/cache-handling-test-scripts/lib/stage34-request-renderer.ps1
exit=0
````

File remains untracked (`??` in `git status --short`). No staged change to
scan, so clean by construction.

### 9. Implementation log completeness

Evidence part-07 contains, with content:

- Pre/post diff (lines added 13, removed 0, net +672 bytes; 110 -> 123 LF)
- Dry-run output (exit 0, summary.raw_prompt_capture=true, 6 rows)
- Hygiene table (CR=0, LF=123, last3, BOM, trailing whitespace, non-ASCII,
  final line count, Select-String hit at L85)

### 10. Stage tracker additive update

Stage-tracker.md row 34 implementation-log cell lists part-04, part-05,
part-06, AND part-07. Status: "OPEN 2026-06-30 (Bug-fix iter 1 in progress)".
Latest test report cell unchanged. Manager gate decision: "pending bug-fix
review". Stage-tracker Stage 33 row and prior decisions verbatim preserved.

## Non-blocking findings

- Brief regex `(events.jsonl -match '[\{\[]')` cannot be False for JSONL.
  Meaningful sub-checks (`role`, `content`) both pass; evidence part-07
  documents the regex artefact explicitly under No-leak verification.
- `ConvertTo-Stage34ChatRequest` (renderer L40-L71) still holds the inline
  raw-prompt-into-body path for `request-{id}.json`. Test plan exclusion
  list names `events.jsonl`, `requests.jsonl`, `summary.json`, and durable
  Markdown; it does not name `request-{id}.json`. Per evidence part-07
  §Patch shape, this is intentional and required to preserve the existing
  request-body shape for downstream callers.
- Renderer source remains untracked. `git diff --check` exits clean by
  absence of staged change. A separate user-directed commit decision applies
  per AGENTS.md; not in scope for this review.

## Handoff

State: bug-fix review PASS.

Next owner: Manager.

Next gate: QA rerun of TP-34-RN-02 with the patched renderer. On PASS, the
TP-34-RN-02 row reclassifies from FAIL-implementation-gap. Stage 34 closure
PARTIAL follows the Stage 33 pattern (1 PARTIAL + 9 wall-clock-limited
BLOCKED) if other rows remain BLOCKED-by-wall-clock.
