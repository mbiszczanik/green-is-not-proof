# Gallery 8: a timeout read as approval

A script waits two seconds for an approval file that nobody creates. When the time limit passes the loop ends, and
the script carries on as if the answer were yes: it prints "change approved and applied" and the process exits 0.

The rule: a timeout is the absence of an answer, not a yes, so when the time limit passes without an answer, fail
and exit non-zero.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | waits two seconds for an approval file under the temp folder, gets no answer and proceeds anyway |
| `after.ps1` | the same loop; no answer at the time limit is a failure, so it prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/timeout-as-approval/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/timeout-as-approval/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Waited for approval (answered: False).` and `Step complete: change approved and applied.`
and ends with `0`; the second prints the first line, then a `[FAIL]` line, and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that the loop ended | that anyone approved |
| The process exit code of `after.ps1` | that a missing answer reaches the caller as a failure | that an answer which did arrive is the right one |

## Tests

`tests/Gallery.TimeoutApproval.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both
exit codes, the success line of `before.ps1`, that `before.ps1` shows no failure, that `after.ps1` prints the failure
and no success line, and that both run the same wait loop. If the before variant ever reports the failure, the test
fails, so this demo cannot silently turn into a second "after".
