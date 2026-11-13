# Gallery 5: a comparator that accepts a missing value

A check compares `$actual -le $limit` where `$actual` is `$null` because the value was never read. PowerShell
treats `$null` as 0 in that comparison, so it evaluates true, the check prints "Check passed" and the process exits 0.

The rule: a comparison with a missing value is not a pass, so test for the missing value first and fail when it is
absent.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | reads a key that is not there (`$null`) and compares it with `-le`; the check passes |
| `after.ps1` | the same comparison, preceded by a test for `$null` that prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/comparator-accepts-missing/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/comparator-accepts-missing/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Check passed: latency is within the limit of 200 ms.` and ends with `0`; the second
prints a `[FAIL]` line that says the value was missing and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that the comparison evaluated true | that a latency was measured |
| The process exit code of `after.ps1` | that a missing value reaches the caller as a failure | that a value which is present is correct |

## Tests

`tests/Gallery.MissingValue.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `before.ps1` shows no failure, that `after.ps1` prints the failure and
no success line, and that both make the same comparison on the same value. If the before variant ever reports the
failure, the test fails, so this demo cannot silently turn into a second "after".
