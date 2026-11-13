# Gallery 9: an empty result read as success

A check lists storage accounts and fails when one of them allows HTTP. The list comes back empty (a stub stands in
for a read the caller may not make), so no account fails, the check prints "Check passed" and the process exits 0.

The rule: "nothing failed" over an empty list means nothing was checked, so count what the read returned and exit
non-zero on zero unless an empty result is what you expect.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing. A function in each script that returns an empty list stands in for the read.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | filters the empty list for accounts that allow HTTP, finds none and prints the success line |
| `after.ps1` | the same check; an empty list is reported as a failure before the filter, and the process exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/empty-result-is-success/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/empty-result-is-success/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Check passed: no storage account allows HTTP.` and ends with `0`; the second prints a
`[FAIL]` line that says the read returned nothing and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that no item in the list failed | that the list held any item |
| The process exit code of `after.ps1` | that an empty result reaches the caller as a failure | why the result was empty: no access, a wrong scope, or truly no accounts |

This demo uses a stub and makes no claim about what Azure returns to a caller without access. One observation is in
the cheat sheet (rule 3): under a Reader-only identity a write was refused with 403. A refused call that raises an
error is the easier case; the empty list without an error is the one this demo is about.

## Tests

`tests/Gallery.EmptyResult.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `after.ps1` prints the failure and no success line, and that both make
the same read and the same filter. If the before variant ever exits non-zero, the test fails, so this demo cannot
silently turn into a second "after".
