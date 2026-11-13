# Gallery 9: a Reader-only 403 or an empty result read as success

A check lists resources through a stub that returns an empty list, which is what a read denied to a Reader-only
identity looks like once the error is swallowed. It finds no non-compliant resource, prints "Check passed" and the
process exits 0, although it saw nothing.

The rule: "nothing failed" is not "everything passed", so fail when the list is empty and say the read returned
nothing.

Expected duration: under one minute. It runs locally with PowerShell 7, makes no Azure call, uses no network and
costs nothing.

## Files

| File | What it is |
| --- | --- |
| `before.ps1` | filters an empty list from a stub for non-compliant items, finds none and reports success |
| `after.ps1` | the same stub and filter, preceded by a test for an empty list that prints the failure and exits 1 |

## Run it

```powershell
pwsh -NoProfile -File ./gallery/empty-result-is-success/before.ps1; $LASTEXITCODE
pwsh -NoProfile -File ./gallery/empty-result-is-success/after.ps1; $LASTEXITCODE
```

Expected: the first prints `Check passed: no non-compliant resources found.` and ends with `0`; the second prints a
`[FAIL]` line that says the read returned nothing and ends with `1`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The success line of `before.ps1` | that no item in the list was non-compliant | that the list held any item |
| The process exit code of `after.ps1` | that an empty read reaches the caller as a failure | that a non-empty list is complete; a partial read can still hide a resource |

## Tests

`tests/Gallery.EmptyResult.Tests.ps1` runs in CI. It starts both variants in child processes and asserts both exit
codes, the success line of `before.ps1`, that `before.ps1` shows no failure, that `after.ps1` prints the failure and
no success line, and that both use the same stub and the same filter. If the before variant ever reports the
failure, the test fails, so this demo cannot silently turn into a second "after".
