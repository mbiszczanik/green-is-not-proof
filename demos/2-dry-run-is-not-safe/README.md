# Demo 2: dry-run is not safe

A script with a `-DryRun` switch looks safe to try. But the switch only guards the calls its author
remembered to put behind it. One call outside the guard changes real state on every "dry" run.

## Predict, run, reveal, fix, rule

### Predict

`Deploy-Example.ps1` has a `-DryRun` switch and guards its deployment call. Will a syntax-tree test over its calls find
an Az call that sits outside the guard?

### Run

```powershell
Invoke-Pester ./demos/2-dry-run-is-not-safe -Output Detailed
```

The test for `Deploy-Example.Fixed.ps1` is green. Without `-CI` the command exits 0 even with a red test.

### Reveal

The test for `Deploy-Example.ps1` is red and names line 18, `Register-AzResourceProvider`, which sits above the guard
and changes real state on every "dry" run. Observed 2026-11-04.

### Fix

`Deploy-Example.Fixed.ps1` moves the registration into the non-dry branch, and its test is green.

### Rule

A dry-run switch is a declaration, so follow a dry run with a look at the write operations in the Activity Log (this
demo shows only the fast syntax-tree pre-check).

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| `-DryRun` switch | nothing: it reports the author's intent | which calls actually sit behind it |
| Syntax-tree test (this demo) | that no listed Az call of a non-read-only verb sits outside a recognised guard in this file | that the script is safe: it sees only the calls and conditions it recognises, and never runs the script |
| Dry run, then the Activity Log (not shown on stage) | what that one run wrote under that input | what other inputs or branches would do |

The analyser finds specific calls and conditions; it does not by itself show the safety of a whole script.

## Tool versions and timing

- The suite first prints a `Tool versions:` line for PowerShell and Pester (from its `BeforeAll`, so it shows with
  `-Output Detailed`). A tool whose version differs from the one the result was observed with gets a `WARNING:` line
  naming both versions. No run in the log records a version for these two, so today they are printed under
  `Not compared` (`config/demo-tools.psd1` holds the observed versions).
- Expected duration: not timed yet. The suite is two tests that parse two short files, offline.
- Warm-up: none is known.

## Results

**Observed 2026-11-04** (code at `31fc36f`): the on-stage command gave `Tests Passed: 1, Failed: 1`; the red test is
`Deploy-Example.ps1 has no unguarded mutation` with `line 18: Register-AzResourceProvider`, the green one is
`Deploy-Example.Fixed.ps1`. The process exit code was 0 without `-CI` and 1 with `-CI`.

**Observed 2026-11-08**, the newest run (local part of the block of run `202611081831`, code at `0571f52`, see
[docs/live-run-log.md](../../docs/live-run-log.md)): `Tests Passed: 1, Failed: 1`; process exit 1 with `-CI`, 0
without. That block does not name the tests, so the test names above stay cited from 2026-11-04.

Offline, no Azure call. **Observed 2026-11-03** (code at `1992109`, recorded in PR #2): red on `Deploy-Example.ps1`,
green on `Deploy-Example.Fixed.ps1`. **Observed 2026-11-03** in the demo subscription, each script run alone with
`-DryRun` under an account that can write: `Deploy-Example.ps1` left one write operation in the Activity Log
(`Microsoft.Insights/register/action`, two entries of one correlation id); `Deploy-Example.Fixed.ps1` left none.
**Observed 2026-11-04** under a Reader-only identity (managed identity on the run's VM, same operations by REST,
not the script itself): the write returned 403 `AuthorizationFailed` and left no Activity Log entry. Under Reader the
refusal is the protection; the log check is for identities that can write.

## On stage

1. Show `Deploy-Example.ps1`: `New-AzResourceGroupDeployment` is guarded, and `Register-AzResourceProvider`
   sits above the guard.
2. Run the on-stage suite:

   ```powershell
   Invoke-Pester ./demos/2-dry-run-is-not-safe -Output Detailed
   ```

   One red: `Deploy-Example.ps1 has no unguarded mutation`, with the failure naming the line and
   `Register-AzResourceProvider`. One green: `Deploy-Example.Fixed.ps1`, where the registration moved into the
   non-dry branch. Without `-CI` the command exits 0 even with the red test, so the red is read from the output, not
   from an exit code; do not call this run a gate.
3. State the limit: the green means the analyser found no unguarded call it recognises in that file. It does not
   mean the script is safe.

The suite lives here, not in `./tests`, so CI does not run it. Its red is intended.

## Why not just run it?

Running the script to see what happens is the unsafe step: deployment cmdlets can mutate. The check parses the
script (`lib/DryRunGuard.ps1`, `Find-UnguardedMutation`) and never executes it, so it needs no Azure access. Both
example scripts are never executed, only parsed.

## What counts as guarded

A call to `<Verb>-Az*` is guarded when it sits in the non-dry branch
of an `if` on `$DryRun` or `$WhatIfPreference` (the `else`, or the body of `if (-not $DryRun)`), or follows an
early `if ($DryRun) { ...; return }` (`exit` and `break` count too). Anything else is reported.

Every `<Verb>-Az*` call counts as mutating unless its verb is on the read-only allow list of `Find-UnguardedMutation`
in `lib/DryRunGuard.ps1`: Get, Test, Find, Search, Resolve, Measure, Show, Select, Compare, Wait. An unknown verb
(`Copy-AzStorageBlob`, `ConvertTo-AzVMManagedDisk`, `Undo-AzKeyVaultSecretRemoval`) is reported, not trusted.

## What it does not settle

Only the exact conditions `$DryRun`, `$WhatIfPreference` and their `-not` / `!` forms count as a guard. Any other
condition (`-and`, `-or`, comparisons, other variables) is unknown and treated as unguarded on purpose, so the
check fails red when unsure. `ShouldProcess` and `-WhatIf` are not recognised, and a dynamic call such as
`& $cmd` is reported as `<dynamic>`. Calls that are not Az PowerShell cmdlets are not detected at all: az CLI calls and
raw REST calls (`Invoke-RestMethod`, `Invoke-WebRequest`) pass unreported.

## Going further

SkyCraft's full gate: <https://github.com/mbiszczanik/skycraft>, `tests/DryRun-Pester-Gate.Tests.ps1`.
