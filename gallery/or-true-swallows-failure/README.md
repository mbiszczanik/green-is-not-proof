# Gallery 3: a failing step followed by `|| $true`

A script runs a step that fails (exit code 1) and appends `|| $true`, the PowerShell form of the workflow `|| true`
pattern. The failure is swallowed, the script reaches its last line, prints "Step complete" and the process exits 0.

The rule: `|| $true` turns every failure of that step into success, so let the step fail the script, or check its
exit code and exit non-zero.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | runs a child `pwsh` step that exits 1, followed by `\|\| $true`; never checks the exit code |
| `after.ps1` | the same step without `\|\| $true`; reads `$LASTEXITCODE`, prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/or-true-swallows-failure/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/or-true-swallows-failure/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Step complete: build finished.` and ends with `0`; the second prints a `[FAIL]` line
and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The last line of `before.ps1` ("Step complete") | that the script reached its end | whether the step succeeded |
| The process exit code of `after.ps1` | that this failure of this step reaches the caller | that every step is covered; any step that still ends in `\|\| $true` stays hidden |

## Tests

`tests/Gallery.OrTrue.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `before.ps1` shows no failure, that `after.ps1` prints the failure and
no success line, and that both run the same step apart from `|| $true`. If the before variant ever reports the
failure, the test fails, so this demo cannot silently turn into a second "after".
