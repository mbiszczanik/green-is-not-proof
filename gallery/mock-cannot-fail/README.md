# Gallery 7: a mock that can never fail

A Pester test checks a function that reads a deployment's state, and the mock behind it answers `Succeeded` for
every input. The function has a defect (it never compares the state), but with that mock no input can make the test
red, so the run prints "All tests passed" and the process exits 0.

The rule: a mock that only answers success tests nothing about failure, so give it a canary input that answers the
failure and keep a test that must go red when the code ignores it.

Expected duration: under one minute. It runs locally with PowerShell 7 and Pester 5.5 or newer, makes no Azure call,
uses no network and costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | runs one test of `Test-Deployment` with a mock that returns `Succeeded` for every name |
| `after.ps1` | the same function and test, a mock that returns `Failed` for the name `canary-failed`, and a canary test that expects `False` for it |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/mock-cannot-fail/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/mock-cannot-fail/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Tests passed: 1, failed: 0`, then `All tests passed.` and ends with `0`; the second
prints `Tests passed: 1, failed: 1`, then `[FAIL] is false for the canary, a deployment that failed` and ends with
`1`.

The red in `after.ps1` is the point: the function under test is the same defective one in both files, and only the
canary shows it. Fixing the function (compare the state with `Succeeded`) would turn `after.ps1` green; this demo
stops at the red.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that the function returns true when the mock says `Succeeded` | what the function does for any other state |
| The canary test of `after.ps1` | that this function accepts a deployment whose state is `Failed` | what the real service returns; the mock is still what the author believes |

## Tests

`tests/Gallery.MockCannotFail.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both
exit codes, the count line and the success line of `before.ps1`, that `after.ps1` names the canary test as failed and
prints no success line, and that both hold the same function under test. If the before variant ever exits non-zero,
the test fails, so this demo cannot silently turn into a second "after".
