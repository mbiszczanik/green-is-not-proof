# Gallery 5: a comparator that accepts a missing value

A check reads the number of failed items from a report and passes when it is at most 5. The report holds no such
value, so the check compares nothing with 5; in PowerShell `$null -le 5` is true, the check prints "Check passed" and
the process exits 0.

The rule: a comparison with a missing value is not a measurement, so check that the value is there before you compare
it and exit non-zero when it is not.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | reads `failedItems` from a report that has none and compares it with the limit using `-le` |
| `after.ps1` | the same check; a missing value is reported as a failure before the comparison, and the process exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/comparator-accepts-missing/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/comparator-accepts-missing/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Check passed: failed items within the limit of 5.` and ends with `0`; the second prints
a `[FAIL]` line that says `failedItems` is missing and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that the comparison returned true | that there was a value to compare |
| The process exit code of `after.ps1` | that a missing value reaches the caller as a failure | that a value that is present is correct, or that the report is fresh |

This demo shows PowerShell's `-le` only. Before you rely on any other comparator, such as a `LessOrEqual` condition,
find out how it treats a value that is absent.

## Tests

`tests/Gallery.MissingValue.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `after.ps1` prints the failure and no success line, and that both read
the same report and make the same comparison. If the before variant ever exits non-zero, the test fails, so this demo
cannot silently turn into a second "after".
