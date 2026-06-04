# Stage 10 design: scope, surfaces, and prerequisites -- Part 1

Source: [../cache-handling-phase10-design.md](../cache-handling-phase10-design.md)

## Goal

Stage 10 turns the accepted hybrid-cache behavior from the earlier stages into a
production-ready feature. The stage does not add a new cache algorithm. It makes
the current hybrid mode observable, reviewable, benchmarkable, reproducible, and
documented for operators.

## Baseline carried forward

Stage 10 inherits these closed properties:

- exact full-state blobs remain a supported restore path
- hot payload LRU uses resident-byte accounting and protected-root priority
- payload descriptors are separate from payload bytes
- target and draft payloads move, restore, demote, promote, and evict as a pair
- cold payload I/O uses versioned descriptors, checksums, and async worker flow
- branch metadata can outlive payload bytes
- metadata-only nodes validate supplied prompt tokens before re-materialization
- equivalent validated branches deduplicate instead of creating duplicates
- checkpoints are first-class payloads for checkpoint-dependent workloads
- workload profile and target/draft overlay participate in namespace matching

Stage 10 must not weaken those contracts while adding diagnostics, hardening, or
benchmarks.

## Stage 10 work areas

| Area | Design requirement |
| --- | --- |
| Observability | Complete R61-R68 metrics and diagnostics across exact blobs, checkpoints, hot/cold transitions, payload eviction, branch pruning, protected roots, fallback, and restore failure paths. |
| Structured logs | Add structured failure, fallback, unsupported-configuration, and integrity events using bounded enum fields. |
| Security review | Record a focused OWASP Top 10 review for A01, A03, A04, A05, A08, and A09 against hybrid-cache surfaces. |
| Hardening | Normalize and constrain cold-store paths, validate descriptor integrity, sanitize request-provided cache markers and policy inputs, and reject unsafe configuration combinations. |
| Benchmarks | Define repeatable exact-blob hit, checkpoint hit, cold transition, and prompt-processing savings measurements. |
| Stress tests | Cover budget exhaustion, concurrent multi-slot access, large branch forests, cold I/O pressure, and fallback paths. |
| Determinism and coverage | Use injected clocks, fake stores, deterministic graph lookup, and coverage reporting to prove at least 80% hybrid path coverage. |
| Operator docs | Document CLI flags, budget tuning, workload profiles, metrics, diagnostics, security limits, and known exclusions. |

## Affected surfaces

Stage 10 affects existing surfaces only unless a later reviewed implementation
plan proves a narrow extension is required.

| Surface | Stage 10 contract |
| --- | --- |
| CLI and startup validation | Validate hybrid-mode flags, hot payload budget, branch metadata budget, cold path, cold budget if present, eviction policy, policy parameters, and unsupported combinations before accepting requests. |
| HTTP request metadata | Validate and sanitize any request-provided cache marker or protection input before it reaches cache policy. Unknown or unsafe marker fields fail explicitly or are ignored with a diagnostic according to the route contract. |
| Cache controller | Emit structured diagnostics for decisions and failures without exposing prompt text, marker text, payload bytes, file paths, or checksums. |
| Branch graph | Expose bounded metrics for node counts, branch pruning, validation mismatch, re-materialization, and large-forest stress behavior. |
| Payload descriptors | Re-check version, kind, pair state, size, checksum, residency, and owner before restore, promotion, demotion, or deletion. |
| Cold store | Enforce normalized root path, root containment, path-safe payload names, staging-file handling, integrity checks, and sanitized diagnostics. |
| Metrics endpoint | Expose complete hybrid metrics through the existing metrics mechanism; do not add a cache inspection endpoint. |
| Test harnesses | Use focused C++ tests, fake store backends, deterministic clocks, and public HTTP/task-flow probes where they are needed to prove external behavior. |
| Documentation | Update durable operator docs in the project documentation tree and keep design/implementation/test reports aligned. |

## Request marker validation

Protected roots remain driven by trusted server policy. If Stage 10 implementation
accepts any request-provided marker, route metadata, or protection hint, it must
use this contract:

1. Treat the value as untrusted input.
2. Limit size, encoding, allowed characters, and accepted enum values before it
   reaches branch lookup or eviction policy.
3. Convert accepted marker material to an internal normalized form that is safe
   for logs, metric labels, file names, and namespace data.
4. Reject or ignore unknown marker values with an explicit diagnostic.
5. Do not let request-provided markers override byte budgets, target/draft
   compatibility, namespace validation, or integrity checks.

No raw marker value may appear in metric labels or cold-store paths.

## Prerequisite checks for implementation planning

An implementation plan for Stage 10 may open only after review confirms:

- Stage 9 is closed in the implementation log and document index
- all Stage 10 affected surfaces are listed in the plan
- every observability addition maps to R61-R68 or a documented Stage 10 evidence
  need
- every hardening change has a failure-mode test or inspection step
- coverage and benchmark collection are defined before code work starts
- operator documentation changes are durable docs, not only test-report notes

## Design boundary

This part defines the Stage 10 design scope and affected surfaces. It does not
approve implementation planning or select exact file-level changes.
