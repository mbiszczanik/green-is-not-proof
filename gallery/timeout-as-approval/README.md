# Gallery 8: a timeout read as approval

A script waits for an approval: it looks for an answer file every 200 ms for at most 2 seconds. Nobody answers, the
time limit passes, the loop ends, and the script prints "Proceeding with the change" and the process exits 0.

The rule: the end of a wait is not an answer, so after the loop check which of the two ended it and exit non-zero
when it was the time limit.

Expected duration: under one minute; each variant waits 2 seconds. It runs locally with PowerShell 7, makes no Azure
call, uses no network and costs nothing. The answer file is looked for under the temp folder and is never created.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | waits for the answer file until the time limit, then proceeds without looking at why the loop ended |
| `after.ps1` | the same loop; when no answer file is there after it, prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/timeout-as-approval/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/timeout-as-approval/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Approval wait finished. Proceeding with the change.` and ends with `0`; the second prints
a `[FAIL]` line that says no answer arrived within 2 seconds and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The last line of `before.ps1` ("Approval wait finished") | that the loop ended | whether an answer or the time limit ended it |
| The process exit code of `after.ps1` | that a wait without an answer reaches the caller as a failure | that an answer file, when present, was written by someone allowed to approve |

## Tests

`tests/Gallery.TimeoutApproval.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both
exit codes, the success line of `before.ps1`, that `after.ps1` prints the failure and no success line, and that both
wait for the same file with the same limit and loop. If the before variant ever exits non-zero, the test fails, so
this demo cannot silently turn into a second "after".
