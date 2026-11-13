# Gallery 4: a test run that discovers zero tests and reports success

A runner looks for test files in a folder that holds none, discovers zero, prints "All discovered tests passed" and
the process exits 0. Nothing failed because nothing ran.

The rule: a run that discovered zero tests has proved nothing, so treat zero discovered tests as a failure and exit
non-zero.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | looks for `*.Tests.ps1` in an empty folder under the temp folder, finds none, prints success and exits 0 |
| `after.ps1` | the same discovery; zero files found is a failure, so it prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/zero-tests-pass/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/zero-tests-pass/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Discovered 0 test files.` and `All discovered tests passed.` and ends with `0`; the
second prints the same first line, then a `[FAIL]` line, and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that the runner reached its end | that any test ran |
| The process exit code of `after.ps1` | that an empty discovery reaches the caller as a failure | that the discovered tests are the right ones; a count above zero says only that something was found |

## Tests

`tests/Gallery.ZeroTests.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `before.ps1` shows no failure, that `after.ps1` prints the failure and
no success line, and that both run the same discovery. If the before variant ever reports the failure, the test
fails, so this demo cannot silently turn into a second "after".
