# Gallery 7: a mock that can never fail

A Pester test replaces its dependency with a mock that answers `Healthy` for every input and asserts only the good
case. The function under test ignores what the dependency says, but the test cannot tell, so Pester reports all
tests passed and the process exits 0.

The rule: a mock that cannot return a failure cannot prove the code handles one, so give the mock a bad input and
add a canary test that must go red when the code is wrong.

Expected duration: under one minute. It runs locally with PowerShell 7 and Pester 5, makes no Azure call, uses no
network and costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | runs a Pester test in which the mock of `Get-BackupState` returns `Healthy` whatever it is asked; the test passes |
| `after.ps1` | the same test and code with a mock that returns `Failed` for `vault-corrupt`, plus a canary test for that input; the canary is red, so it prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/mock-cannot-fail/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/mock-cannot-fail/after.ps1; $LASTEXITCODE
```

Expected: the first prints `All tests passed: 1 passed.` and ends with `0`; the second prints a `[FAIL]` line that
names the canary test and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that the assertions held against the mock | that the code reads the dependency's answer |
| The red canary of `after.ps1` | that this test can fail and that the code under test has a defect | that a green canary would prove the code correct; it proves only that this input is handled |

## Tests

`tests/Gallery.MockCannotFail.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `before.ps1` shows no failure and has no failing mock, that `after.ps1`
prints the failure that names the canary and no success line, and that both run the same code under test. If the
before variant ever reports the failure, the test fails, so this demo cannot silently turn into a second "after".
