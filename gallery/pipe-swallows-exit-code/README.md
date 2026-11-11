# Gallery 1: exit code swallowed by a pipe

A script runs a command that fails and sends its output through a pipe into `Tee-Object` to keep a copy.
`Tee-Object` succeeds, the script reaches its last line, and the process exits 0 although the output shows `[FAIL]`.

The rule: a pipe passes on output, not the exit code, so read `$LASTEXITCODE` right after the pipeline and exit
with it.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | runs an inner command that exits 1, pipes it into `Tee-Object`, never reads the exit code |
| `after.ps1` | the same inner command and pipe, then reads `$LASTEXITCODE` and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/pipe-swallows-exit-code/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/pipe-swallows-exit-code/after.ps1; $LASTEXITCODE
```

Expected: both print `[FAIL] inner check`; the first ends with `0`, the second with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The last line of `before.ps1` ("Step complete") | that the script reached its end | whether the inner command failed |
| The process exit code of `after.ps1` | that this failure of this inner command reaches the caller | that every failure does; a command that fails and still exits 0 stays hidden |

## Tests

`tests/Gallery.PipeExit.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, that both show the failure line and that both run the same inner command. If the before variant ever
reports the failure, the test fails, so this demo cannot silently turn into a second "after".
