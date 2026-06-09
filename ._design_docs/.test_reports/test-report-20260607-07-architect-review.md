# Stage 12 MTP + jinja fix review (R1 + R2)

- Review ID: stage12-mtp-jinja-fix-review-20260607
- Date: 2026-06-08
- Reviewer: Architect
- Source fixes: ._design_docs/.test_reports/test-report-20260607-07-fixes.md
- Prior REWORK: part-22 (2026-06-08, 2 blocking, 3 non-blocking)

## 1. R1 verification

Target: replace bad `llama-server --print-chat-template` fallback in
part-21a section 2 with an implementable path; expose shared helper.

Helper file:
- Path: ._design_docs/cache-handling-test-scripts/lib/Read-GgufChatTemplate.ps1
- Test-Path: True
- Functions exposed:
  - `Read-GgufChatTemplate -GgufPath <p>`: invokes
    `python gguf-py/gguf/scripts/gguf_dump.py --json --no-tensors <gguf>`,
    parses JSON, returns `metadata.tokenizer.chat_template.value`.
  - `Resolve-MtpJinjaPath -MtpVariant -JinjaVariant -ModelPath -SourceRoot`:
    returns absolute chat_template[_new].jinja path or `$null` when
    MtpVariant=0.
  - `Merge-MtpJinjaFlag -Flags -JinjaPath`: appends
    `--chat-template-file <p>` to a server flag array when file present.
- Field path verified at `gguf-py/gguf/constants.py:270`:
  `CHAT_TEMPLATE = "tokenizer.chat_template"`. JSON access path
  `$obj.metadata.'tokenizer.chat_template'.value` matches
  `dump_metadata_json` else-branch (verified by source-rooted resolver
  in helper: `$sourceRoot = Resolve-Path ".../.." /..`).
- No `--print-chat-template` literal anywhere in helper, drivers, or
  part-21a. Falls back to `chat_template_new.jinja` / `chat_template.jinja`
  by variant+path.

part-21a section 2 updated:
- Section 2 no longer names `--print-chat-template`. It cites the helper,
  lists the JSON walk, and references `gguf-py/gguf/constants.py:270`.
- Section 4 still declares the same param contract.
- part-19 section 2.1 lib-inventory table now lists 6 helpers
  (was 5); the new row is `lib/Read-GgufChatTemplate.ps1` with the
  purpose string covering Read/Resolve/Merge per part-21a sec 2 and
  part-19 sec 7.1.

R1 status: CLOSED.

## 2. R2 verification

Target: 19 base drivers gain `[int] $MtpVariant = 0` and
`[ValidateSet('original','marked')] [string] $JinjaVariant = 'original'`
params, dot-source the helper, resolve jinja path, BLOCKED-check, and
append the chat-template-file flag via the helper.

Six markers checked per driver (MtpVariant, JinjaVariant, DotSrc,
Resolve, Blocked, Merge). The literal `--chat-template-file` lives
inside the helper (correctly); drivers call Merge-MtpJinjaFlag to
perform the append.

| Group | Total | AllOK | Bad |
| --- | --- | --- | --- |
| stress (s01-s08) | 8 | 8 | 0 |
| bench  (b01-b08) | 8 | 8 | 0 |
| longrun (l01-l03) | 3 | 3 | 0 |
| drivers total    | 19 | 19 | 0 |

Spot checks (full param block + dot-source + Resolve + BLOCKED + Merge):

- stress/stress_s12_s01_budget_exhaustion.ps1: all 6 markers, single
  static `$serverFlags`, Merge call right after the array literal,
  param defaults `MtpVariant=0`, `JinjaVariant='original'`. Verified.
- bench/bench_s12_b01_exact_blob_hit_rate.ps1: all 6 markers, two
  static arrays (`$hybridFlags` and `$legacyFlags`), Merge call applied
  to both. Verified.
- longrun/longrun_s12_l01_6h_hybrid_stability.ps1: all 6 markers,
  single static `$flags`, Merge call right after the array literal.
  Verified.

BLOCKED message contract: `BLOCKED: jinja file missing at <path> ...`
(emitted via Write-Host; non-fatal by design per part-21a sec 4;
downstream QA reads evidence-summary.md).

R2 status: CLOSED.

## 3. Parser tokenize results

`[System.Management.Automation.Language.Parser]::ParseFile` on the
helper + 19 drivers (20 files):

- total=20 pass=20 fail=0 errTotal=0
- exit=0

R2 status: scripts parse clean.

## 4. Non-blocking items (R3, R4, R5) status

- R3 (V3 lmstudio source path hygiene, non-blocking, deferrable):
  Not regressed. Driver V3 first-copy step is downstream of the
  patched 19-driver contract; this fix did not touch V3 fixture
  resolution. Status: still non-blocking, still deferrable.
- R4 (V2 jinja extraction JSON parser): CLOSED by R1 fix. The new
  helper is the JSON parser; part-21a sec 2 names it as the
  driver-facing entry point. No further naming gap remains.
- R5 (V1/V3 session 25h pause/resume): Not regressed. Fix did not
  touch session scheduling or evidence-dir layout from part-21a
  sec 5. Status: still non-blocking; Manager may schedule when
  V1/V3 sessions approach the 25h wall-clock.

## 5. New issues introduced

None blocking. Two minor observations, recorded for follow-up
(durable-doc alignment, not gate blockers):

- O1. The new helper is a generic name; if more gguf metadata
  helpers appear later, the inventory table cell may need
  tightening. No action this gate.
- O2. part-21a sec 2 step 5 still says "Record the extraction
  event in the per-scenario evidence summary" but the per-driver
  augmentation is called once per driver, not per session. This
  is wording drift from the part-22 sec 4 "once per session"
  description, not a code defect. Recommend a one-line edit in
  a future doc-sweep; not required to advance the gate.

## 6. Verdict

PASS. R1 and R2 are closed. All 20 modified scripts parse clean.
R3, R4, R5 status is consistent with the prior REWORK
classification; R4 collapses into R1 closure. No new blocking
issues introduced.

## 7. Manager handoff

- Verdict: PASS
- Closed: R1 (V2 jinja extraction helper), R2 (19-driver param
  contract)
- Carried forward (non-blocking): R3 (V3 lmstudio path hygiene),
  R5 (V1/V3 pause/resume)
- Collapsed: R4 absorbed into R1 closure
- Required next actions:
  - Manager: approve and authorize QA execution of the four
    V1/V2/V3/non-MTP sessions per part-21 sec 2.
  - Developer: address O2 wording drift in part-21a sec 2 step 5
    in a future doc-sweep (not a gate item).
- git diff --check on this file: see chat for exit code.