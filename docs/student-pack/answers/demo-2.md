# Answer key, demo 2

1. `Register-AzResourceProvider` (line 18). It sits above `if ($DryRun)`, so the switch never guards it and every
   "dry" run calls it. The switch only protects the calls its author remembered to put behind it.
2. The registration moved into the `else` branch, the non-dry branch, next to `New-AzResourceGroupDeployment`.
3. Running the script to see what happens is the unsafe step: deployment cmdlets can mutate. The test
   (`lib/DryRunGuard.ps1`, `Find-UnguardedMutation`) reads the syntax tree and never executes anything, so it needs
   no Azure access.
4. Any two of: calls that are not Az PowerShell cmdlets (`az` CLI calls, raw REST calls such as `Invoke-RestMethod`),
   dynamic calls such as `& $cmd` (reported as `<dynamic>`), and conditions it does not recognise (anything but
   `$DryRun`, `$WhatIfPreference` and their `-not` forms), which it treats as unguarded on purpose.

The rule: a dry-run switch is a declaration. The stronger check is a dry run followed by a look at the write
operations in the Activity Log; the syntax-tree test is only the fast pre-check.
