# Design document index

## Mandatory document size rules

When new documents are created or existing documents are modified, these rules are mandatory:

- IF document exceeds 300 lines THEN split it into smaller logically consistent part files.
- Create a subdirectory named after the document file (without the `.md` extension) to hold the parts.
- In the original document, keep the top-level heading and introductory sections up to the table of contents, then write the remaining content in the part files, putting references (links) to all these files to the main document.
- Each part file must not exceed 300 lines.
- Create as many parts as needed to cover the full content.

## How to use this index

Start with the entry document for a topic. If it links to part files, read those files in order. Generated part files are linked from their parent documents, not listed here.

This index should be updated whenever new documents are added or existing documents are modified. When adding a new document, add an entry to the appropriate section with a brief description and usage guidance. When modifying an existing document, update the description and usage guidance if necessary.

## Cache overview, requirements, and ideas

| Document | What is inside | Useful for |
| --- | --- | --- |
| [cache-handling-requirements.md](cache-handling-requirements.md) | Requirements, constraints, definitions, non-goals, and acceptance requirements for alternate hybrid cache mode. | Use this to check whether a cache design or implementation satisfies the agreed contract. |
| [cache-handling.md](cache-handling.md) | Overview of cache handling in llama-server, agentic workflow concerns, ADR notes, and feasibility notes. | Use this for cache behavior context and policy tradeoffs before reading detailed designs. |
| [cache-ideas.md](cache-ideas.md) | Short notes on cache optimization ideas and future directions. | Use this as a parking lot for early cache concepts. |
| [cache-requirements-qa.md](cache-requirements-qa.md) | Question-and-answer clarification for the cache requirements. | Use this when a requirement is ambiguous or needs an implementation-facing interpretation. |

## Cache architecture and design

| Document | What is inside | Useful for |
| --- | --- | --- |
| [cache-handling-architecture.md](cache-handling-architecture.md) | Architecture entry point for alternate hybrid cache mode, with links to detailed part files. | Use this to navigate architecture requirements, runtime semantics, ADRs, security, and traceability. |
| [cache-handling-phase1-design.md](cache-handling-phase1-design.md) | Phase 1 design entry point for alternate hybrid cache mode, with links to detailed part files. | Use this to understand the Phase 1 scope, component design, integration points, and testing strategy. |
| [cache-handling-phase2-design.md](cache-handling-phase2-design.md) | Phase 2 design entry point, with links to detailed part files. | Use this to understand Phase 2 gap closure, component design, data structures, and testing strategy. |
| [cache-handling-phase3-design.md](cache-handling-phase3-design.md) | Phase 3 design entry point for non-destructive exact blob cache, with links to detailed part files. Part 3 includes production integration addendum documenting save triggers and non-destructive load mechanism. | Use this to understand Stage 3 implementation: complete save/load functionality, non-destructive hits, usage tracking, multi-slot reuse, metrics, and actual production integration approach. |
| [cache-handling-phase4-design.md](cache-handling-phase4-design.md) | Closed Phase 4 design entry point for byte-accounted LRU eviction with protected-root retention priority, diagnostics, metrics, and requirement traceability. | Use this to review the accepted Stage 4 eviction policy behavior and design constraints. |

## Cache implementation, verification, and tests

| Document | What is inside | Useful for |
| --- | --- | --- |
| [cache-handling-phase-1-and-2-adjustments.md](cache-handling-phase-1-and-2-adjustments.md) | Adjustment plan entry point for phase 1 and 2 cache handling work, with links to detailed part files. | Use this to review required changes, updated scope, order of work, and open questions. |
| [cache-handling-phase1-implementation.md](cache-handling-phase1-implementation.md) | Phase 1 implementation log entry point, with links to detailed part files. | Use this to review what changed during Phase 1 and why. |
| [cache-handling-phase1-verification.md](cache-handling-phase1-verification.md) | Phase 1 verification report entry point, with links to detailed part files. | Use this to review verification evidence, limitations, and production readiness notes. |
| [cache-handling-phase2-implementation.md](cache-handling-phase2-implementation.md) | Phase 2 implementation log entry point, with links to detailed part files. | Use this to review integration work, validation evidence, and remaining notes for Phase 2. |
| [cache-handling-phase3-implementation.md](cache-handling-phase3-implementation.md) | Phase 3 implementation log entry point, with links to detailed part files. Part 15 documents production integration fixes (save triggers and non-destructive load). | Use this to review Phase 3 implementation steps, test results (92% pass rate), implementation review findings, and production integration corrections. Parts cover: implementation plan, steps 3.1-3.6, test coverage, final verification, sign-off, comprehensive implementation review with required corrections, and production integration fixes. |
| [cache-handling-phase4-implementation.md](cache-handling-phase4-implementation.md) | Closed Phase 4 implementation log entry point for byte-accounted LRU eviction with protected-root behavior, implementation review findings, review-fix evidence, implementation re-review verdict, H30-H39 QA evidence, and Stage 4 closure decision. | Use this to review Stage 4 changed files, tests, evidence, remaining non-blocking limitations, and closure state. |
| [cache-handling-phases-1-and-2-implementation-gaps.md](cache-handling-phases-1-and-2-implementation-gaps.md) | Implementation gap review entry point, with links to detailed part files. | Use this to track corrective actions and coverage work across phases 1 and 2. |
| [cache-handling-test-plan.md](cache-handling-test-plan.md) | Cache implementation test plan entry point, with links to detailed part files. Covers current Stage 4 LRU eviction policy, protected-root behavior, metrics, and reusable evidence rules. | Use this to find manual and scripted test cases for cache behavior and QA execution reporting. |

## Prompt compression

| Document | What is inside | Useful for |
| --- | --- | --- |
| [prompt-compression-implementation-plan.md](prompt-compression-implementation-plan.md) | Prompt compression planning entry point, with links to detailed part files. | Use this to review staged implementation work and open decisions. |
| [prompt-compression-implementation.md](prompt-compression-implementation.md) | Prompt cache and context checkpoint compression implementation entry point, with links to detailed part files. | Use this to review the proposed architecture and implementation details for compression. |

## Qwen fixes

| Document | What is inside | Useful for |
| --- | --- | --- |
| [fix-qwen-eval-2.md](fix-qwen-eval-2.md) | Patch notes entry point for the second Qwen evaluation fix, with links to detailed part files. | Use this to review upstream-relative symptoms and the second fix path. |
| [fix-qwen-eval.md](fix-qwen-eval.md) | Patch notes for the first Qwen evaluation fix. | Use this to understand the original symptoms, fix logic, and possible side effects. |
| [fix-qwen-summary.md](fix-qwen-summary.md) | Patch summary entry point for Qwen-related fixes, with links to detailed part files. | Use this for a consolidated Qwen fix summary and side-effect review. |

## Index and maintenance

| Document | What is inside | Useful for |
| --- | --- | --- |
| [document-index.md](document-index.md) | Categorized index of design documentation and mandatory document size rules. | Use this first when looking for the right design note or maintaining this document tree. |
| [project-documentation-index.md](project-documentation-index.md) | Categorized index of project markdown documents outside `._design_docs`. | Use this when looking for build, tool, example, backend, server, UI, or contributor documentation. |

