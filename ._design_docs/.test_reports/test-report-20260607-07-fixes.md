# Test report 20260607-07 fixes (MTP+jinja rework)

Source: part-22 rework (R1 + R2)
Date: 2026-06-07
Owner: Developer
Status: Ready for Architect re-review

## Scope

Two blocking findings from
[part-22-stage12-mtp-jinja-test-plan-review](../cache-handling-test-plan/part-22-stage12-mtp-jinja-test-plan-review.md)
(R1, R2) are closed. R3, R4, R5 remain non-blocking and are
out of this gate. No design change. No product code change.
Closure PASS state is preserved.

## R1 fix (V2 jinja extraction helper)

part-21a section 2 named a `llama-server --print-chat-template`
fallback that does not exist in this build. Replaced with a
new lib helper.

New file:

- `._design_docs/cache-handling-test-scripts/lib/Read-GgufChatTemplate.ps1`
  (151 lines, CRLF, ASCII only)

Functions exposed by the helper:

- `Read-GgufChatTemplate -GgufPath <path>`: invokes
  `python gguf-py/gguf/scripts/gguf_dump.py --json --no-tensors
  <gguf>`, parses the JSON, and returns the
  `metadata.tokenizer.chat_template.value` string per
  `gguf-py/gguf/constants.py:270` (Tokenizer.CHAT_TEMPLATE).
- `Resolve-MtpJinjaPath -MtpVariant <n> -JinjaVariant <s>
  -ModelPath <p> -SourceRoot <r>`: resolves the absolute
  chat_template[_new].jinja path per MtpVariant (0 returns
  `$null`).
- `Merge-MtpJinjaFlag -Flags <arr> -JinjaPath <p>`: appends
  `--chat-template-file <p>` to a server flags array when the
  file is present on disk.

Docs updated:

- `._design_docs/cache-handling-test-plan/part-21a-stage12-mtp-jinja-execution.md`
  section 2: removed the bad `--print-chat-template`
  fallback, replaced step 1 with a call to the new helper,
  recorded the field path, and noted that the same file
  exposes `Resolve-MtpJinjaPath` and `Merge-MtpJinjaFlag`.
- `._design_docs/cache-handling-test-plan/part-19-stage12-test-automation.md`
  section 2.1: appended a new row for the helper in the lib
  inventory table.

Verification: `Test-Path
._design_docs/cache-handling-test-scripts/lib/Read-GgufChatTemplate.ps1`
returns `True`.

## R2 fix (driver params for 19 base drivers)

All 19 base drivers (8 stress + 8 bench + 3 long-run) gained
two new `param()` entries:

- `[int]    $MtpVariant     = 0`
  (0 = no MTP, 1 = V1, 2 = V2, 3 = V3)
- `[ValidateSet('original','marked')] [string] $JinjaVariant = 'original'`

Plus the same helper dot-source + jinja path resolution +
BLOCKED check + flag augmentation block:

- Helper dot-source: `. (Join-Path $libDir 'Read-GgufChatTemplate.ps1')`
- Resolution: `$jinjaPath = Resolve-MtpJinjaPath ...`
- BLOCKED check: emits a `BLOCKED: jinja file missing at <path>`
  Write-Host line when `MtpVariant -gt 0 -and MtpVariant -ne 2`
  and the resolved jinja file is absent on disk (V2 is
  exempt because the V2 extraction step creates the file).
- Augmentation: `$serverFlags = Merge-MtpJinjaFlag -Flags
  $serverFlags -JinjaPath $jinjaPath` (or `$flags` for
  static-flag drivers, or both `$hybridFlags` and
  `$legacyFlags` for dual-mode bench drivers).

Files patched (19 drivers):

- stress: s01, s02, s03, s04, s05, s06, s07, s08 (8)
- bench: b01, b02, b03, b04, b05, b06, b07, b08 (8)
- longrun: l01, l02, l03 (3)

Per-driver augmentation placement:

- s01, s03, s04, s06, s07, s08: static `$serverFlags` block,
  augmentation right after the definition (one call).
- s02: `$serverFlags` rebuilt per slot inside `foreach`,
  augmentation inside the loop (one call per slot).
- s05: `$serverFlags = $p.args` per profile inside
  `foreach`, augmentation right after the assignment
  (one call per profile).
- b01: two static arrays, augmentation for both
  `$hybridFlags` and `$legacyFlags`.
- b02, b05, b08: single static `$flags`, augmentation
  right after the definition.
- b03, b04, b06: two static arrays, augmentation for
  both `$hybridFlags` and `$legacyFlags`.
- b07: `$flags` rebuilt per profile inside `foreach`,
  augmentation right after the assignment and
  `--model-draft` add.
- l01, l02, l03: single static `$flags`, augmentation
  right after the definition.

## Evidence

### Parser tokenize (all 20 modified scripts)

`pwsh -NoProfile -File
._design_docs/.test_reports/verify-tokenize-20260607-07.ps1`
ran the `[System.Management.Automation.Language.Parser]::ParseFile`
API on the 19 base drivers and the new helper. Result:

```text
total=20 pass=20 fail=0
exit=0
```

Per-file errors all `0`. Exit code `0`.

### git diff --check (all 22 touched files)

`git diff --check -- <path>` was run scoped on all 22
touched files. Summary by rc:

- rc=0 (clean): 15 files
- rc=2 (CRLF artifact): 7 files (s01, s02, s05, s07, s08, l01, l03)

The 7 rc=2 files are CRLF on the Windows worktree and
their tracked siblings are also CRLF. The literal `\r`
before `\n` on every CRLF line triggers the default
`trailing-space` rule. Byte-level scan
`[regex]::Matches($content, '[ \t]+(?=\r?$)')` returned
`0` real trailing-whitespace matches across all 22 files.
Sibling files in the same directory are CRLF, so line
endings are preserved. Per the developer improvement
memory, "Preserve local line endings" applies; the
scoped rc=2 is reported verbatim and paired with the
zero real-trailing-whitespace byte scan.

`tw_total=0` across all 22 files.

`part-19-stage12-test-automation.md` is LF (0 CRLF, 318
bare LF) which matches its tracked blob; the other 21
files are CRLF and match their tracked siblings.

### Helper file path verification

`Test-Path
._design_docs/cache-handling-test-scripts/lib/Read-GgufChatTemplate.ps1`
returned `True`. File is 151 lines, CRLF, ASCII only.

### Touched files (22 total)

| Kind | Count | Files |
| --- | --- | --- |
| New helper | 1 | `lib/Read-GgufChatTemplate.ps1` |
| Stress drivers | 8 | s01-s08 |
| Bench drivers | 8 | b01-b08 |
| Longrun drivers | 3 | l01-l03 |
| Test-plan doc | 1 | `part-21a-stage12-mtp-jinja-execution.md` |
| Test-automation doc | 1 | `part-19-stage12-test-automation.md` |

## Handoff

R1 and R2 are closed. Driver contract for `-MtpVariant` and
`-JinjaVariant` is now enforced at the param-block level
(ValidateSet on JinjaVariant) and at the file-presence
level (BLOCKED check for MtpVariant in {1, 3}). V2 remains
permissive because the V2 extraction step writes the file
on demand (per part-21a section 2).

R3 (V3 lmstudio source path hygiene), R4 (JSON parser
naming), and R5 (pause/resume markers) remain non-blocking
and are tracked in part-22 section 6.

Ready for Architect re-review and Manager approval.
Next gate: QA execution of the four V1/V2/V3/non-MTP
sessions per part-21 section 2.
