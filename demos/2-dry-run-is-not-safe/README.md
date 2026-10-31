# Demo 2: dry-run is not safe

A script with a `-DryRun` switch looks safe to try. But the switch only guards the calls its author
remembered to put behind it. One call outside the guard changes real state on every "dry" run.

The rule: a dry-run switch is a declaration; a syntax-tree test over every call is proof.

## On stage

1. Show `Deploy-Example.ps1`: `New-AzResourceGroupDeployment` is guarded, and `Register-AzResourceProvider`
   sits above the guard.
2. Run the on-stage suite:

   ```powershell
   Invoke-Pester ./demos/2-dry-run-is-not-safe -Output Detailed
   ```

   One red: `Deploy-Example.ps1 has no unguarded mutation`, with the failure naming the line and
   `Register-AzResourceProvider`. One green: `Deploy-Example.Fixed.ps1`, where the registration moved into the
   non-dry branch.

The suite lives here, not in `./tests`, so CI does not run it. Its red is intended.

## Why not just run it?

Running the script to see what happens is the unsafe step: deployment cmdlets can mutate. The check parses the
script (`lib/DryRunGuard.ps1`, `Find-UnguardedMutation`) and never executes it, so it needs no Azure access. Both
example scripts are never executed, only parsed.

## What counts as guarded

A call to `<Verb>-Az*` is guarded when it sits in the non-dry branch
of an `if` on `$DryRun` or `$WhatIfPreference` (the `else`, or the body of `if (-not $DryRun)`), or follows an
early `if ($DryRun) { ...; return }` (`exit` and `break` count too). Anything else is reported.

The verbs counted as mutating are the default of `Find-UnguardedMutation` in `lib/DryRunGuard.ps1`: New, Set, Remove,
Register, Update, Start, Stop, Add, Install, Restart, Invoke, Grant, Revoke, Enable, Disable, Publish, Move, Import,
Restore, Reset, Rename, Clear, Save, Submit, Suspend, Resume, Unregister, Sync, Backup, Mount, Dismount, Approve, Deny.

## What it does not prove

Only the exact conditions `$DryRun`, `$WhatIfPreference` and their `-not` / `!` forms count as a guard. Any other
condition (`-and`, `-or`, comparisons, other variables) is unknown and treated as unguarded on purpose, so the
check fails red when unsure. `ShouldProcess` and `-WhatIf` are not recognised, and a dynamic call such as
`& $cmd` is reported as `<dynamic>`.

## Going further

SkyCraft's full gate: <https://github.com/mbiszczanik/skycraft>, `tests/DryRun-Pester-Gate.Tests.ps1`.
