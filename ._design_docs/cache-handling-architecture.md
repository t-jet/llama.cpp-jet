# Software architecture: hybrid prompt cache for `llama-server`

Status: current implementation baseline through Stage 39 closure; open
requirements gaps are listed in Part 6

Date: 2026-07-19

Primary requirements: [cache-handling-requirements.md](cache-handling-requirements.md)

## Purpose

This software architecture document (SAD) describes the hybrid prompt cache as
it exists in the repository. It replaces the earlier target-state narrative and
the stage-by-stage architecture additions. A reader should not need development
stage documents to understand the deployed design.

The document uses a C5 extension of the C4 model:

1. C1: system context and architecture drivers.
2. C2: runtime containers and deployment boundaries.
3. C3: components, data ownership, and static structure.
4. C4: code mapping and runtime behavior.
5. C5: decisions, quality controls, delivery, and operations.

## Architecture summary

Hybrid cache is an opt-in `llama-server` cache controller. It keeps reusable
prompt state in a shared branch forest, stores exact-state and checkpoint
payloads separately from branch metadata, and manages target and optional draft
state as one validated pair. Payload bytes can reside in RAM, move to a local
cold store, or be evicted while branch metadata remains available.

Cache mutations run synchronously under one recursive controller mutex. Restore
planning captures immutable state under that mutex, applies it to the live llama
contexts outside the mutex, then finalizes bookkeeping under the mutex. Any
validation or apply failure falls back to recomputation without claiming a hit.

Compatibility namespaces contain stable runtime inputs. Prompt-local tokens,
boundaries, and checksums validate candidates after lookup. Exact restore works
across supported completion routes. Strict-prefix restore is limited to safe chat
boundaries; unsafe candidates are rejected and recomputed.

## Contents

- [Part 1: C1 context and drivers](cache-handling-architecture/part-01-context-and-drivers.md)
- [Part 2: C2 containers and deployment](cache-handling-architecture/part-02-containers-and-deployment.md)
- [Part 3: C3 components and data](cache-handling-architecture/part-03-components-and-data.md)
- [Part 4: C4 runtime behavior](cache-handling-architecture/part-04-runtime-behavior.md)
- [Part 5: C4 code and interfaces](cache-handling-architecture/part-05-code-and-interfaces.md)
- [Part 6: C5 quality, security, and delivery](cache-handling-architecture/part-06-quality-security-and-delivery.md)
- [Part 7: C5 architecture decisions](cache-handling-architecture/part-07-architecture-decisions.md)

## Conformance rule

Production code is the authority for current behavior. Requirements define the
intended contract. If either changes, this SAD and the document index must be
updated in the same change. Historical stage records remain useful evidence, but
they do not extend or override this document.
