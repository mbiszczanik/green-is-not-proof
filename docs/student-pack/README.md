# Offline student pack

Five demos of "Green is not proof" run without an Azure subscription: demos 2, 4, 6 and 7, and the stub half of
demo 3. One command runs them all and prints, for each demo, the green result and the reveal. Then the
[exercises](exercises.md) ask you to find why each one is green. The [answer key](answers.md) is a separate file: read
it after you have written your own answer.

## What you need

| Prerequisite | Needed by | Without it |
| --- | --- | --- |
| PowerShell 7 | every demo | nothing runs |
| Pester 5.5 or newer | demos 2, 3 and 4 | those demos are not run |
| The Bicep CLI (`bicep`, or `az bicep`) | demo 6 | demo 6 is not run |
| The modules `PSRule` and `PSRule.Rules.Azure` | demo 7 | demo 7 is not run |

No Azure account, no sign-in and no network call are needed to run the pack; installing a missing prerequisite is the
only step that needs the network.

## Run it

From the repository root:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1; $LASTEXITCODE
```

For each demo the pack prints a `Green` step and a `Reveal` step with the output and the exit code of each command,
and then one result line:

| Line | Meaning |
| --- | --- |
| `OK: demo N showed its green and its reveal.` | every step ended with the exit code and the line the demo README states |
| `NOT RUN: demo N needs X, which is missing.` | a prerequisite is missing; the other demos still run |
| `FAILED: demo N: ...` | a step ended with another exit code, did not print the expected line, or could not start |

The exit code is 0 only when all five demos are `OK`. A demo that was not run is not a pass, so one missing
prerequisite makes the whole command exit 1 and the summary names it.

## What the pack does not show

- Demo 2 has no command for its green: the green is the `-DryRun` switch itself, and the script is never executed.
- The reveal of demo 3 is a live read from Azure. The pack does not run it; it prints the result recorded in the
  demo README.
- Demo 4 runs the `Silent` and the `Fixed` validator. The `Counted` validator depends on the PowerShell version; run
  it yourself in exercise 4.
- Demos 0, 1 and 5 need Azure and are not part of the pack.
- A green pack means the demos behaved as their READMEs state on your machine, with your tool versions. Each demo
  prints those versions and a `WARNING:` line when one differs from the version its result was observed with.
