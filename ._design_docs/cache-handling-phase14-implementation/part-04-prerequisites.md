# Stage 14 prerequisites and host tooling

Source: [../cache-handling-phase14-implementation.md](../cache-handling-phase14-implementation.md)

## Status

Planning date: 2026-06-11
Plan state: drafted.
Implementation state: not started.
Pre-merge analysis state: not started.

## Prerequisites

The Stage 14 merge activity is gated on the prerequisites
below. A prerequisite that is not met is a blocker, not a
skip. The prerequisites inherit from
[../upstream-merge-guide.md](../upstream-merge-guide.md)
Part 1 section 1 and the Stage 14 design Part 1
"Prerequisites" list, with the Stage 14 host and tooling
specifics added.

| Prerequisite | Owner | Status (2026-06-11) | Source |
| --- | --- | --- | --- |
| Git available on PATH with merge command family support | Developer | must be PASS at cycle open | upstream-merge-guide Part 1 section 1 row 4 |
| Remote-tracking ref `origin/upstream_master` is present | Developer | PASS (SHA `db94854ff56549f62b84d2f31608259a9e5e0e9f`, last fetched 2026-06-04) | Design Part 1 "Upstream reference strategy" and D1 carry-forward. D4 resolved via Path C. |
| `origin` remote configured with read access for `upstream_master` | Developer | PASS (origin URL `https://github.com/t-jet/llama.cpp-jet.git`; `origin/upstream_master` is fetchable) | upstream-merge-guide Part 1 section 1 row 4. Open Manager decision D6 (jet-fork-vs-actual-upstream gap, accepted via Path C). |
| Local default branch checked out at a clean tree at cycle open | Developer | FAIL (working tree dirty: modifications to `cache-handling-architecture/part-05-...`, `document-index.md`, `self-improvement/assets/{architect,manager}.md`; untracked `cache-handling-phase14-design.md`) | upstream-merge-guide Part 4 section 11. Open Manager decision D5. |
| Local credentials allow push to the local default branch after the merge resolves cleanly | Developer | must be PASS at cycle open | upstream-merge-guide Part 1 section 1 row 4 |
| Host can run focused ctest, focused exporter coverage, k6, Stage 12 stress harness, and Stage 13 endpoint probe | Developer | must be PASS at cycle open | Design Part 1 "Host tooling and credential assumptions" |
| `build-cov` build directory present for T114 and T114a coverage run | Developer | PASS (directory present) | Stage 10 cap-fix closure 2026-06-07 |
| `build-cuda-stage13` build directory present for E13 endpoint probe | Developer | PASS (directory present) | Stage 13 closure 2026-06-10 |
| OpenCppCoverage on PATH for the focused exporter coverage script | Developer | must be PASS at cycle open | Stage 10 closure 2026-06-04 |
| k6 on PATH for the stress regression rerun | Developer | must be PASS at cycle open | Stage 10 closure 2026-06-04 |
| Model fixtures for Stage 12 stress regression reruns (S01..S08 and L01..L03) | Developer | must be PASS at cycle open (fixtures from Stage 12 closure inventory) | Stage 12 closure 2026-06-07 |
| MTP-capable GGUF fixture for H53/H54 public MTP reruns and T121 checkpoint probe | Developer | status inherited from Stage 13 closure (BLOCKED on missing MTP-capable GGUF) | Stage 13 closure 2026-06-10. Any rerun of T121 or the Stage 13 CUDA endpoint probe rows inherits the BLOCKED state unless the fixture is supplied. |
| Architect implementation-plan review of the Stage 14 plan | Architect | NOT STARTED | Next gate |
| Manager implementation-plan gate decision | Manager | NOT STARTED | Follows Architect review |

The Developer confirms the "must be PASS at cycle open"
prerequisites at Step 1 of the implementation plan. Any
prerequisite that is not met at Step 1 open is a blocker
for Step 1. The Developer does not start the pre-merge
analysis until every prerequisite above is either PASS
or has a Manager decision recorded in the pre-merge
report "Manager decisions requested" section.

## Why these are separate Developer gates, not Step 0 of the merge activity

The prerequisites above are Developer-owned gates that
run before Step 1 of the implementation plan. Each gate
has its own review and its own approval, but the gate does
not produce a cycle artifact. The placement rationale
matches the Stage 11 plan part-04 rationale:

- The merge activity is the integration event that
  re-syncs the fork with `origin/upstream_master`. The
  prerequisites are maintenance and verification gates
  that do not touch the upstream merge, the rework
  Stage N workflow, the regression rerun, or the merge
  log.
- The two activities have different owners: the merge
  activity is Developer-led with Architect review and
  Manager approval. Each prerequisite gate is Developer-
  led with a focused review (Architect sanity check for
  the script change, direct verification for the
  upstream reference and the clean tree).
- The two activities have different inputs: the merge
  activity reads the upstream ref and the file-glob
  groups. Each prerequisite gate reads a specific
  verification command set or a specific local state.
- The two activities have different outputs: the merge
  activity produces the pre-merge report, the merge log,
  and the test report. Each prerequisite gate produces
  a per-gate verdict recorded in the implementation log.
- The two activities have different gates: the merge
  activity is gated on the design and the implementation-
  plan review. Each prerequisite gate is gated on the
  focused review by the Developer and a quick Architect
  sanity check that the verification result is correct.

Placing the prerequisites as Step 0 of the merge activity
would pollute the merge activity with separate, smaller
work items and force every prerequisite to share the
implementation-plan review and the Manager implementation-
plan gate. Keeping each prerequisite as a separate
Developer gate that runs before Step 1 of the merge
activity preserves the separation and lets each gate
review the correct artifact.

## Upstream reference verification

Per the D1 carry-forward decision, the upstream reference
is the remote-tracking ref `origin/upstream_master`. The
Developer operates against `origin/upstream_master`
directly. No local `upstream_master` tracking branch is
required. The Developer verifies the remote ref tip is
current against the actual upstream `master` via `git
ls-remote https://github.com/ggml-org/llama.cpp.git master`
before the merge opens. The verification commands and
outputs are below. The Developer runs these commands at
Step 1 and records the output in the pre-merge report
"Upstream reference verification" section per
[../upstream-merge-guide.md](../upstream-merge-guide.md)
Part 1 section 2.

### Verification commands

| # | Command | Expected result |
| --- | --- | --- |
| 1 | (not applicable for Path C; no local `upstream_master` branch required) | The cycle operates against `origin/upstream_master` directly. |
| 2 | `git rev-parse origin/upstream_master` | A 40-char SHA. Returns `db94854ff56549f62b84d2f31608259a9e5e0e9f` on 2026-06-11. |
| 3 | `git log -1 --format='%H %ai %s' origin/upstream_master` | Subject and date of the remote ref tip. |
| 4 | `git ls-remote https://github.com/ggml-org/llama.cpp.git master` | The actual upstream `master` tip SHA. |
| 5 | `git merge-base LOCAL origin/upstream_master` | A 40-char SHA. The merge base is the fork point. |
| 6 | `git log --oneline LOCAL..origin/upstream_master` followed by `wc -l` | The total commit count in the range. |
| 7 | `GET .../compare/<local-tip>...master` | The ahead or behind count and the status. |
| 8 | `git remote -v` | The remote URL. Returns `https://github.com/t-jet/llama.cpp-jet.git` on 2026-06-11. |

D1 historical anchor SHA: `db94854ff56549f62b84d2f31608259a9e5e0e9f` (2026-06-04). Current tip may differ; refresh at Step 1 open. D12 records the live tip.

### Staleness check

The local `upstream_master` tracking branch is not used in
Path C. The cycle operates against `origin/upstream_master`
directly. No local branch is required and none is created.
D4 is resolved via Path C (2026-06-11).

The remote ref `origin/upstream_master` was last fetched
on 2026-06-04 per the D1 carry-forward. The Developer
runs `git fetch origin` at Step 1 to refresh the remote
ref before the verification. The gap between
`origin/upstream_master` and the actual upstream `master`
tip (ahead, behind, or diverged) is recorded in the
pre-merge report and, if material, in the merge log
"Known gaps" section per D1. The actual upstream tip is
queried via `git ls-remote https://github.com/ggml-org/
llama.cpp.git master` (verification command 4).

### Local reference state (2026-06-11)

- Current branch: `cache-optimization-caveman` (Developer
  is on a working branch, not the local default branch).
- Local integration branch: the local default branch
  (name to be confirmed at Step 1 from the local repo
  state; the design Part 1 leaves the concrete value to
  the implementation plan).
- Local tracking branch for upstream: not used. The cycle
  operates against `origin/upstream_master` directly at
  SHA `db94854ff56549f62b84d2f31608259a9e5e0e9f`.
- Local working tree contains uncommitted edits to
  `cache-handling-architecture/part-05-...`,
  `document-index.md`,
  `self-improvement/assets/{architect,manager}.md`, and
  an untracked design file
  `cache-handling-phase14-design.md`. The working tree is
  otherwise consistent with the local default branch.

## What each prerequisite does

The prerequisites are verification and maintenance gates.
The Developer runs each gate at Step 1 and records the
verdict in the pre-merge report "Working tree state" and
"Upstream reference verification" sections.

- Git on PATH: standard `git --version` check.
- Local `upstream_master` tracking branch: per D1. D4
  resolved via Path C; no local branch is required.
- `origin` remote configured: per
  [../upstream-merge-guide.md](../upstream-merge-guide.md)
  Part 1 section 2 row 7.
- Local default branch clean: per upstream-merge-guide
  Part 4 section 11 and open decision D5.
- Local credentials: standard `git push --dry-run` check.
- Host capabilities: standard which/where checks for
  ctest, OpenCppCoverage, k6, and the Stage 12 and Stage
  13 harness executables.
- `build-cov` directory: per Stage 10 cap-fix closure
  2026-06-07.
- `build-cuda-stage13` directory: per Stage 13 closure
  2026-06-10.
- OpenCppCoverage on PATH: per Stage 10 closure
  2026-06-04.
- k6 on PATH: per Stage 10 closure 2026-06-04.
- Model fixtures: per Stage 12 closure 2026-06-07
  fixture inventory.
- MTP-capable GGUF fixture: per Stage 13 closure
  2026-06-10 (BLOCKED on missing MTP-capable GGUF; T121
  rerun inherits the BLOCKED state unless the fixture is
  supplied).

## What each prerequisite does not do

- The prerequisites do not change the upstream merge, the
  rework Stage N workflow, the regression rerun, or the
  merge log.
- The prerequisites do not change the public CLI surface,
  the public Prometheus metric set, the bounded diagnostic
  field set, the MTMD placeholder path, the diagnostic-
  source namespace isolation rule, or the bounded
  `cache metadata:` format at task launch.
- The prerequisites do not change the prior-stage closure
  contracts. A prerequisite that would change a closure
  contract is itself a design change, not a Developer gate.
- The prerequisites do not authorize a commit, a push, a
  PR, or a cycle closure.

## Handoff state

The Developer confirms every prerequisite at Step 1 of
the implementation plan. Any prerequisite that is not met
at Step 1 open is a blocker for Step 1. The Developer
does not start the pre-merge analysis until every
prerequisite above is either PASS or has a Manager
decision recorded in the pre-merge report "Manager
decisions requested" section. The implementation gate,
the rework Stage N gates, the test-plan gate, and the QA
execution gate remain closed until the implementation-plan
review and the Manager implementation-plan gate both
pass.






