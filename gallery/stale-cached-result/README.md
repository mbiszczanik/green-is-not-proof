# Gallery 6: a cached result read as if it were fresh

A check reads a result file and reports what the file says. The file was written two days ago by an earlier run and
says "passed", so the check prints "Check passed" and the process exits 0, whatever happened since.

The rule: a result without its date is a memory, not a check, so compare the age of a stored result with a stated
limit and exit non-zero when it is older.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing. Both variants write one small file, `gallery-stale-cached-result/result.json`, under the temp folder
and set its timestamp two days back; that file stands in for the earlier run.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | reads the status from the two-day-old result file and reports it |
| `after.ps1` | the same check; compares the file's age with a limit of 24 hours first, prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/stale-cached-result/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/stale-cached-result/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Check passed: the result file says passed.` and ends with `0`; the second prints a
`[FAIL]` line that gives the age of the file (48 hours) and the limit (24 hours) and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | what the stored file says | when that was true, or whether it is true now |
| The process exit code of `after.ps1` | that a result older than the limit reaches the caller as a failure | that a fresh file is correct, or that the file's timestamp was not changed by a copy or a restore |

## Tests

`tests/Gallery.StaleCache.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `after.ps1` prints the failure with the age and no success line, and
that both read the same file and make the same status check. If the before variant ever exits non-zero, the test
fails, so this demo cannot silently turn into a second "after".
