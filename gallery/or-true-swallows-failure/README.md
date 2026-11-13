# Gallery 3: a failing step followed by `|| $true`

A script runs a step that prints `[FAIL]` and exits 1, and the line ends with `|| $true`, the PowerShell form of the
workflow habit `|| true`. The right-hand side succeeds, so the script goes on, prints "Step complete" and the process
exits 0.

The rule: `|| true` does not make a step optional, it throws its result away, so remove it and exit non-zero when the
step fails.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | runs a step that exits 1, followed by `\|\| $true`; never reads the exit code |
| `after.ps1` | the same step without `\|\| $true`; reads `$LASTEXITCODE`, prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/or-true-swallows-failure/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/or-true-swallows-failure/after.ps1; $LASTEXITCODE
```

Expected: the first prints `[FAIL] deploy step`, then `True` (the value of the right-hand side), then
`Step complete: deploy step finished.` and ends with `0`; the second prints `[FAIL] deploy step`, then
`Deploy step failed with exit code 1.` and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The last line of `before.ps1` ("Step complete") | that the script reached its end | whether the step succeeded |
| The process exit code of `after.ps1` | that a non-zero exit code of this step reaches the caller | that the step reports every failure through its exit code |

## Tests

`tests/Gallery.OrTrue.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit codes,
the success line of `before.ps1`, that `after.ps1` prints the failure and no success line, and that both run the same
step apart from `|| $true`. If the before variant ever exits non-zero, the test fails, so this demo cannot silently
turn into a second "after".
