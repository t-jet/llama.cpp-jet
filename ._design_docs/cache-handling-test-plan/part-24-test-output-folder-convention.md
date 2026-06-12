# Cache handling test plan - Part 24: test output folder convention

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Purpose

This part records the folder convention that separates durable test
reports (tracked in git) from non-durable test outputs (local only).
The convention is enforced by the `.gitignore` of
[../.test_reports/.gitignore](../.test_reports/.gitignore) and by the
absence of any tracking in [../../_test_output/](../../_test_output/).

## Rationale

Test reports are durable artifacts. They record the verdict, the
evidence, and the handoff for a given test run, and they are
referenced from later test reports, design docs, and closure
records. They belong in version control.

Logs, build outputs, ctest output, coverage reports, k6 results,
pytest output, scripts, and benchmark or stress harness artifacts
are non-durable. They are useful for the engineer running the test
and for reproducing failures, but they are large, they contain
timestamps and machine-specific paths, and they are not needed
after the report is written. They belong outside version control.

The two categories are kept in different folders so a `.gitignore`
whitelist can enforce the rule.

## Folder rules

- [../.test_reports/](../.test_reports/)
  - Tracked in git.
  - Contains only Markdown files.
  - Allowed names: `test-report-YYYYMMDD-NN.md`, `pre-merge-report-YYYYMMDD-NN.md`, `merge-log-YYYYMMDD-NN.md`, and their `-developer-review.md`, `-architect-review.md`, `-fixes.md`, `-part02-testfix.md` variants.
  - The `.gitignore` whitelists those names. Any other file or folder is ignored even if it lands in this directory.
- [../../_test_output/](../../_test_output/)
  - Not tracked in git. The folder's `.gitignore` is `**/*`.
  - Holds logs, build outputs, ctest outputs, coverage reports, k6 logs, pytest logs, scripts, k6 results, benchmark outputs, stress harness outputs, MTP and jinja run outputs, and per-test subfolders such as `S12-S01-...`, `bench-s12-b01-...`, `coverage-run-...`, `test-report-YYYYMMDD-NN-artifacts/`.
  - Safe to delete when no longer needed. Subfolders can be removed independently.

## Rule

- Markdown report produced by a test run: write to `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` and commit.
- Anything else produced by a test run: write to `._test_output/` (or a subfolder such as `._test_output/<test-run-id>/`) and do not commit.
- A test run is identified by a date stamp `YYYYMMDD` and a sequence number `NN`. The same ID is used as the report filename and as the `._test_output/<id>/` subfolder name when the run creates one.

## Examples

- A clean build with ctest output: write `llama-server.exe` and `ctest-runner.exe` build logs to `._test_output/build-cov-20260612-01/`. The ctest log goes to the same folder. The report goes to `._design_docs/.test_reports/test-report-20260612-01.md`.
- A coverage run: write the Cobertura XML, the per-file table, and the run script to `._test_output/coverage-run-20260612-01/`. The summary table can be quoted in the report; the raw XML is not committed.
- A k6 stress run: write `k6-results.json`, the k6 stdout log, and the bench driver script to `._test_output/bench-s12-b01-20260612-01/`. The bench verdict and the relevant metric values go into the report.
- A focused unit test rerun: write the ctest log and the focused test binary output to `._test_output/test-cache-controller-20260612-01/`. The verdict row goes into the parent report.
- A per-test artifact subfolder next to a report: when a test report has supporting artifacts (script snapshots, intermediate XML, raw log excerpts), place them in `._test_output/test-report-YYYYMMDD-NN-artifacts/` rather than `._design_docs/.test_reports/`.

## Move procedure

If a subfolder, a log file, or a build artifact accidentally lands in
[../.test_reports/](../.test_reports/), the file is ignored by git
because the `.gitignore` whitelist does not match. It still occupies
space on disk and confuses the next maintainer. Move it out:

```powershell
# Example: a subfolder landed in .test_reports
$src = '._design_docs/.test_reports/coverage-run-20260611-03'
$dst = '._test_output/coverage-run-20260611-03'
Move-Item -Path $src -Destination $dst -Force
```

After the move, the destination is not tracked because
[../../_test_output/](../../_test_output/) is fully ignored. The
source is no longer present, so the next `git status` is clean. If a
Markdown report was placed in a subfolder rather than at the top of
[../.test_reports/](../.test_reports/), move it to the top level and
rename it to `test-report-YYYYMMDD-NN.md` (or one of the other
allowed names).

## Enforcement

A pre-commit hook or CI lint can run:

```powershell
$extra = Get-ChildItem ._design_docs/.test_reports -File |
    Where-Object { $_.Name -notmatch '\.md$' -and $_.Name -ne '.gitignore' }
if ($extra.Count -gt 0) {
    Write-Error "Non-Markdown files in .test_reports/: $($extra.Name -join ', ')"
    exit 1
}
```

A non-empty `$extra` fails the check. The same check is useful as a
manual sweep:

```powershell
# Manual sweep across the whole repo
$violations = git status --porcelain -- ._design_docs/.test_reports |
    Where-Object { $_ -notmatch '\.md$' }
```

## Related docs

- The entry doc section [Test output folder convention](../cache-handling-test-plan.md#test-output-folder-convention) is the short reference.
- The `.gitignore` at [../.test_reports/.gitignore](../.test_reports/.gitignore) is the machine-checkable rule.
- [./part-07-test-report-quality-and-templates.md](./part-07-test-report-quality-and-templates.md) covers report content and bug report format.
