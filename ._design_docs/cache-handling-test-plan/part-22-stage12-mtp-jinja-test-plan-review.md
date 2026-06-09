# Stage 12 MTP + jinja test plan review (rework)

- Review ID: part-22-stage12-mtp-jinja-test-plan-review
- Date: 2026-06-08
- Reviewer: Architect
- Sources: part-21, part-21a; cross-checked part-18,
  part-18a, part-19, cache-handling-architecture/part-02
  (Adopted Jinja Boundary Interface), part-10,
  part-07 D12, gguf-py/gguf/scripts/gguf_dump.py

## 1. REWORK findings addressed

1. Wall-clock infeasibility. RESOLVED. part-21
   section 2 splits 152 rows across 4 sessions,
   38 rows per session, 1 report per session, stress
   at full 30-min. Per V1/V3: 480m stress + 17h
   long-run full = ~25h. Per V2/non-MTP: 480m
   stress + 6m long-run + 16m bench = ~8h. Bounded
   per session. Prompt "19h per session" overestimated
   by treating all 38 rows as 30-min; correct bound
   uses per-class budgets.
2. V2 jinja extraction. PARTIALLY RESOLVED. Primary
   path (gguf-py gguf_dump.py --json) is
   implementable: gguf-py/gguf/constants.py:270
   defines Tokenizer.CHAT_TEMPLATE and
   gguf_dump.py dump_metadata_json emits the value
   field. Fallback is INCORRECT (see R1).
3. Input marking rules. RESOLVED. part-21a section
   3 lists 8 concrete rules: template_markup
   namespace, cache_mark macro, cache_boundary=1
   feature spec, <|template_markup:v1:...|> header,
   6 marker kinds (system_*, message_*, tool_call_*,
   tool_response_*, media_*, generation_prompt_*),
   byte-for-byte fallback. Each maps to a step in
   architecture part-02 "How to Adapt a Test Jinja
   Template" (steps 1-10).
4. MTP gate. RESOLVED. part-07 Manager D12 flips
   part-10 item A from REMAINS-BLOCKER to
   CAN-DESIGN-OUT. part-18a section 11 records MTP
   rows as live under part-21. H53/H54 status moves
   from BLOCKED-by-cap-fix to live. Closure PASS
   preserved.
5. Driver parameter contract. PARTIALLY RESOLVED.
   part-19 section 7.1 documents -MtpVariant,
   -JinjaVariant, and auto-resolved jinja_path,
   same parameter set across all 19 base drivers,
   no driver-specific variant logic. But the 19
   base driver .ps1 files do not yet declare these
   parameters (see R2).
6. V1 and V3 fixture paths. RESOLVED. V1 lives at
   ._test_models\Qwen3.5-4B-MTP-GGUF\ (canonical
   local; in part-18a section 12). V3 lives at
   ._test_models\Qwen3.6-27B-MTP-GGUF\; driver
   copies from user-side lmstudio on first V3
   sub-run. Canonical local is the only runtime
   source; two-copy divergence removed.
7. Cross-reference break. RESOLVED. part-21
   section 3 now reads "Full row list in part-18a
   section 8" (long-run details, not the
   cross-reference section in part-18).

## 2. Input marking rule consistency

Architecture part-02 Adopted Jinja Boundary Interface
and part-21a section 3 align on every rule:
template_markup namespace, cache_mark macro,
cache_boundary=1 feature spec, the
<|template_markup:v1:...|> header as first rendered
bytes, the 6 marker kinds, and the byte-for-byte
equivalence when emit_cache_boundaries is unset.
part-21a step 10 round trip matches architecture
part-02 step 9 (flags unset, compare bytes) and
step 10 (flag true, verify header, strip, compare).

## 3. V2 jinja extraction implementability

Primary path is implementable. gguf-py gguf_dump.py
--json emits tokenizer.chat_template as a top-level
metadata key with a string value. Driver invokes
`python gguf-py/gguf/scripts/gguf_dump.py --json
<gguf>` and parses JSON for the metadata key
tokenizer.chat_template value field. Field path
matches gguf-py/gguf/constants.py:270 and the
dump_metadata_json else branch at contents().

Fallback path is NOT implementable in this build. No
--print-chat-template CLI flag exists. Searched
common/arg.cpp, tools/server/server.cpp,
server-chat.cpp, server-common.cpp. Closest existing
flag is `--chat-template <value>` which sets the
template, not prints it. See gap R1.

## 4. Multi-session plan validity

4 sessions, 1 test report per session, 38 rows per
session, fresh YYYYMMDD-NN suffix, evidence dir
under ._design_docs/.test_reports/mtp-jinja-run-
YYYYMMDD-NN/. Per-row wall-clock per session is
class-specific: stress 30 min, bench 1 min, long-run
full in V1/V3 and 1 min in V2/non-MTP. V2 jinja
extraction runs once per session, not per sub-run.
BLOCKED rule for missing jinja file applies in all
four sessions. Plan is internally consistent and
bounded per session.

## 5. MTP gate lift consistency

Gate lift is consistent. part-07 D12 flips part-10
item A from REMAINS-BLOCKER to CAN-DESIGN-OUT.
part-18a section 11 records the lift: MTP rows live
under part-21, H53/H54 moved to live. part-21
section 3 names V1, V2, V3 with --spec-type
draft-mtp (V1/V3) and --model-draft (V2). Closure
PASS preserved.

## 6. Remaining gaps and risks

- R1 [BLOCKING]. llama-server --print-chat-template
  fallback named in part-21a section 2 does not
  exist in this build. Remove the fallback sentence
  or replace with an implementable path (start the
  server briefly and read templated chat output via
  the chat completion endpoint, or use the model
  description API). If a V2 future session needs a
  fresh checkout and the gguf-py path is unavailable,
  the fallback is the only documented option and it
  does not work.
- R2 [BLOCKING]. The 19 base driver .ps1 files do
  not declare -MtpVariant or -JinjaVariant. part-19
  section 7.1 documents them, but a recursive grep
  across ._design_docs/cache-handling-test-scripts/
  for both names returns zero hits. The fail-fast
  contract in part-21a section 4 cannot be enforced
  because drivers will silently accept any string
  positionally. Developer pre-session patch, not a
  Manager gate issue.
- R3 [NON-BLOCKING]. V3 first-time copy from
  lmstudio requires the driver to read a user-side
  path. Canonical local copy is the runtime source,
  but the copy step is a driver side effect. part-19
  section 10.1 env-hygiene rule already covers
  LLAMA_CACHE_TEST_MODEL absolute paths; the same
  rule should apply to the lmstudio source path
  constant. Surface in part-19 if not already.
- R4 [NON-BLOCKING]. part-21a section 2 step 1
  names the extraction tool but no JSON parser. The
  driver must parse JSON and walk to the metadata
  key tokenizer.chat_template value field. Specify
  the parser (for example, ConvertFrom-Json) in the
  driver or in part-19 lib inventory. Optional: add
  a small lib helper named e.g.
  Read-GgufChatTemplate.ps1.
- R5 [NON-BLOCKING]. Wall-clock per V1/V3 session
  (~25h) is heavy. The plan should declare whether
  a session can pause and resume, and where the
  resume marker is. Per-scenario evidence dir
  layout supports pause and resume at row
  boundaries if the driver tracks completed rows
  in the session evidence summary.

## 7. Verdict

REWORK. Two blocking findings: R1 (V2 jinja
extraction fallback path is not implementable in
this build) and R2 (19 base driver scripts do not
yet accept -MtpVariant and -JinjaVariant). Once R1
and R2 are closed by Developer (or part-21a text
is updated to remove the bad fallback and the
driver patch is recorded in part-19), re-review by
Architect. R3, R4, R5 do not block the next gate.

## 8. Manager handoff

- Verdict: REWORK (2 blocking, 3 non-blocking)
- Required rework items:
  - R1: replace --print-chat-template fallback in
    part-21a section 2 with an implementable path
    (or remove it). Confirm with Developer.
  - R2: Developer patch to add -MtpVariant and
    -JinjaVariant to all 19 base driver .ps1 files.
    part-19 section 7.1 documents the contract; the
    code change is the missing piece. Re-run the
    dry-run path with the new parameters once
    patched.
  - R3: part-19 section 10.1 (or new subsection) for
    the lmstudio source path used by V3 first-time
    copy.
  - R4: part-21a section 2 step 1 to name the JSON
    parser and the field path (metadata key
    tokenizer.chat_template, value field). Optional
    small lib helper.
  - R5: part-21a section 5 (or part-19) to declare
    pause and resume behavior and the resume
    marker.
- Cosmetic: none beyond the above.
- Next gate: Developer closes R1 and R2, then
  Architect re-review, Manager approval, QA
  execution. git diff --check: see chat for exit
  code.
