# Gallery 6: a cached result read as if it were fresh

A check reads a result file that an earlier run wrote two days ago, sees `ok` and prints "Check passed". It never
looks at the file's timestamp, so the old result stands in for a run that did not happen today and the process exits 0.

The rule: a cached result proves something about the moment it was written, so compare its timestamp with a stated
limit and fail when it is older.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | writes `last-run.txt` under the temp folder with a timestamp two days old, reads it and reports success |
| `after.ps1` | the same file and the same check, preceded by a comparison of its age with a one hour limit; prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/stale-cached-result/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/stale-cached-result/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Check passed: the last run reported ok.` and ends with `0`; the second prints a `[FAIL]`
line that gives the age and the limit and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that the file says `ok` | when the check that wrote it ran |
| The process exit code of `after.ps1` | that a result older than the limit reaches the caller as a failure | that a fresh file holds a correct result; a recent timestamp says only that something wrote it recently |

## Tests

`tests/Gallery.StaleCache.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `before.ps1` shows no failure, that `after.ps1` prints the failure and
no success line, and that both write the same stale file and run the same status check. If the before variant ever
reports the failure, the test fails, so this demo cannot silently turn into a second "after".
