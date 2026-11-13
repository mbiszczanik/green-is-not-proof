# Gallery 4: a test run that discovers zero tests and reports success

A runner script looks for `*.Tests.ps1` files in a folder that holds none. No test fails, because no test runs, so
the runner prints "All tests passed" and the process exits 0.

The rule: zero failures is not a pass when zero tests ran, so count the tests that were discovered and exit non-zero
on zero.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing. Both variants create one empty folder, `gallery-zero-tests-pass-empty`, under the temp folder.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | discovers test files in an empty folder, counts failures only, prints the success line |
| `after.ps1` | the same runner; treats zero discovered tests as a failure, prints it and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/zero-tests-pass/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/zero-tests-pass/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Tests discovered: 0, failed: 0`, then `All tests passed.` and ends with `0`; the second
prints the same count line, then a `[FAIL]` line that says no test was discovered, and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The last line of `before.ps1` ("All tests passed") | that no test that ran failed | that any test ran |
| The process exit code of `after.ps1` | that a run with zero discovered tests reaches the caller as a failure | that the discovered tests are the ones you meant to run, or that none was skipped |

This repository's own CI gate applies the same rule: `tools/Invoke-CiPester.ps1` rejects a run with zero tests.

## Tests

`tests/Gallery.ZeroTests.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the count line of both, the success line of `before.ps1`, that `after.ps1` prints the failure and no success
line, and that both discover tests the same way. If the before variant ever exits non-zero, the test fails, so this
demo cannot silently turn into a second "after".
