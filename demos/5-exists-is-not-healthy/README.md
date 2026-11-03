# Demo 5: existing is not working

Module A of the talk. A resource can exist, an existence check can pass, and Azure can still have marked the resource
`Failed`. The demo gives the run's VM a script extension that always fails, then reads it twice: once asking only
"is it there?", once asking "what state is it in?".

The rule: an existence check is a declaration that something is there. The stronger check reads its provisioning
state, and fails on anything but `Succeeded`.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| Existence (`Get-AzVMExtension` returns an object) | that the resource is registered under that name | whether it works |
| State (`ProvisioningState` is `Succeeded`) | what Azure reported for this extension when it last ran | whether the workload it set up is healthy now, or that other resources are fine |

The state check treats a missing or blank state as a failure; nothing missing is read as success.

## Origin

In SkyCraft, `Test-Lab.ps1` scripts confirmed that a resource existed and never read its `provisioningState`, so a
flow log that Azure had left `Failed` passed with 19 passed and 0 failed
([#371](https://github.com/mbiszczanik/skycraft/issues/371)). That case needs a policy that blocks a setting; this demo
reproduces the same shape with a resource that is cheap and fails by construction.

## Before the talk

Needs a run with the VM: `scripts/Start-DemoRun.ps1`, then `scripts/New-RogueResource.ps1`. Run demo 0 first: the
ownership audit lists the extension as well (it is not in the deployment record), which would add a row to demo 0.

```powershell
./demos/5-exists-is-not-healthy/New-FailedExtension.ps1
```

It adds the Linux `CustomScript` extension `gnp-failing-script` with the command `exit 1` and waits until Azure marks
it `Failed`. The error Azure returns is printed and expected. If the extension does not reach `Failed` within five
minutes, the script says so and exits 1. The extension costs nothing beyond the VM the run already prices, and goes
away with the resource group.

## On stage

```powershell
./demos/5-exists-is-not-healthy/Show-ExistenceVsState.ps1
```

Expected output (exit code 0):

```text
Existence check: PASS (extension gnp-failing-script found)
State check:     FAIL (ProvisioningState: Failed)
One read of this extension, in this configuration, at this moment.
```

Then state what it settles: for this extension, now, "exists" and "works" disagree, and a validator that stops at the
first check would report success. It does not show how common this is.

The script exits 1, saying so, when the extension is missing or its state is anything other than `Failed`, so the demo
never shows a pass it did not produce.

## Results

- **Observed 2026-11-03** (run `202611032044`, code at `c4b2d8b` plus this demo): `New-FailedExtension.ps1` exit 0 after
  37 s; `Show-ExistenceVsState.ps1` exit 0 with the three lines above. See
  [docs/live-run-log.md](../../docs/live-run-log.md).
- Also observed in that run: the tag audit still counted 7 resources (the extension carries no tag), while the ownership
  audit listed 5 rows including `Microsoft.Compute/virtualMachines/extensions`; teardown exit 0.
- Run it again before each delivery and add a dated block to the log.

## Tests

`tests/ExistsVsState.Tests.ps1` runs in CI with mocks. It checks the program's logic: the extension parameters, the
exit codes, a missing state never passing, masking. It does not replace the live read above.
