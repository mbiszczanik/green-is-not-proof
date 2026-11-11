# Gallery 2: -ErrorAction SilentlyContinue hides a failure

A script calls `Get-Item` on a path that does not exist and passes `-ErrorAction SilentlyContinue`, so the error is
never shown. The script never checks the result, reaches its last line, prints "Step complete" and the process
exits 0.

The rule: `-ErrorAction SilentlyContinue` removes the message, not the failure, so use `-ErrorAction Stop` (or check
the result) and exit non-zero when the call fails.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | calls `Get-Item` on a missing path under the temp folder with `-ErrorAction SilentlyContinue`, never checks the result |
| `after.ps1` | the same call with `-ErrorAction Stop` inside `try`/`catch`; prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/erroraction-silentlycontinue/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/erroraction-silentlycontinue/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Step complete: input file checked.` and ends with `0`; the second prints a `[FAIL]` line
that names the missing path and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The last line of `before.ps1` ("Step complete") | that the script reached its end | whether `Get-Item` found the file |
| The process exit code of `after.ps1` | that this failure of this call reaches the caller | that every failure does; a call that still passes `-ErrorAction SilentlyContinue` stays hidden |

## Tests

`tests/Gallery.SilentlyContinue.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both
exit codes, the success line of `before.ps1`, that `before.ps1` shows no failure, that `after.ps1` prints the
failure and no success line, and that both make the same call apart from the `-ErrorAction` value. If the before
variant ever reports the failure, the test fails, so this demo cannot silently turn into a second "after".
