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
./demos/5-exists-is-not-healthy/Show-ExistenceVsState.ps1 -ExpectFailed
```

Expected output (exit code 0, because `-ExpectFailed` says a `Failed` state is the result this demo expects):

```text
Existence check: PASS (extension gnp-failing-script found)
State check:     FAIL (ProvisioningState: Failed)
One read of this extension, in this configuration, at this moment.
```

Then state what it settles: for this extension, now, "exists" and "works" disagree, and a validator that stops at the
first check would report success. It does not show how common this is.

## Exit codes

Without `-ExpectFailed` the script is a state check, and a failed state check is a failed script:

| Situation | Without `-ExpectFailed` | With `-ExpectFailed` |
| --- | --- | --- |
| Extension exists, state `Succeeded` | 0 | 1, "not Failed" |
| Extension exists, state `Failed` | 1 | 0 |
| Extension exists, any other or blank state | 1 | 1, "not Failed" |
| Extension not found (a ResourceNotFound answer naming the extension) | 1, "Run New-FailedExtension.ps1 first" | 1, same |
| The read could not run (no Azure context, no run file, a subscription, resource group or VM not found, any other read error) | 1, "The check did not run." | 1, "The check did not run." |

The plain run exits 1 for the extension this demo builds, so a pipeline that calls it is not a false green. The flag
only moves the question: with it, exit 0 means "the demo showed its point", never "the extension is healthy".
With `-ExpectFailed`, exit 0 means the expected failure was reproduced (the extension exists in state `Failed`), not that the
extension is healthy.

## Results

- **Observed 2026-11-11** (run `202611111504`, code at `c9a3e9f`): without `-ExpectFailed` exit 1, with it exit 0, both
  with the three lines above; before the extension existed both modes exit 1 with "Run New-FailedExtension.ps1 first".
  The Az error for a missing extension is `ResourceNotFound` (404) naming the extension path. See
  [docs/live-run-log.md](../../docs/live-run-log.md). Owed: a new backup recording of the on-stage run (#41).
- The two observed runs below predate the exit-code contract above: they ran the script as it was then (exit 0 for state
  `Failed`).
- **Observed 2026-11-08** (run `202611081831`, code at `0571f52`, a subscription with a policy that installs the Guest
  Configuration extension): `New-FailedExtension.ps1` exit 0 after 39 s and `Show-ExistenceVsState.ps1` exit 0 with the
  three lines above. In that subscription the ownership audit of demo 0 lists 6 rows after this step (VM, NIC, disk,
  schedule and two extensions: `AzurePolicyforLinux` from the policy and `gnp-failing-script`). See
  [docs/live-run-log.md](../../docs/live-run-log.md).
- **Observed 2026-11-03** (run `202611032044`, code at `c4b2d8b` plus this demo): `New-FailedExtension.ps1` exit 0 after
  37 s; `Show-ExistenceVsState.ps1` exit 0 with the three lines above. See
  [docs/live-run-log.md](../../docs/live-run-log.md).
- Also observed in that run: the tag audit still counted 7 resources (the extension carries no tag), while the ownership
  audit listed 5 rows including `Microsoft.Compute/virtualMachines/extensions`; teardown exit 0.
- Run it again before each delivery and add a dated block to the log.

## Tests

`tests/ExistsVsState.Tests.ps1` runs in CI with mocks. It checks the program's logic: the extension parameters, the
exit codes of both modes, a missing state never passing, a check that did not run (a subscription or resource group error is never
a missing extension), masking. `tests/ExistsVsState.Process.Tests.ps1` runs the real script under `pwsh -File` against a stub Az module and
asserts the process exit code. It does not replace the live read above.
