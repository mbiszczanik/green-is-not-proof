# Demo 3: a stubbed test checks only your assumption

A strict health check passes its test, because the test feeds it a hand-written stub object with the
demanded property filled in. The real resource may not return that property.

Off stage: the talk's core uses [demo 4, the gate demo](../4-gate-never-red/README.md) instead (see issue #3). This demo
stays as reference material.

The rule: a stubbed test is a declaration of what you believe the API returns. The stronger check is the same
assertion against one live read of the real resource.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| Stubbed Pester suite | the program's logic, given the object you wrote | what the real service returns |
| Live read (`Show-LiveProperty.ps1`) | what the service returned for this workspace, in this configuration, at this moment | what it returns for another configuration, region or API version |

Both stay useful: the tests keep guarding the logic, the live read checks the assumption behind the stub.

## Why this property

The strict check demands `PrivateLinkScopedResources`. It was chosen before any live read, from the documented
`PSWorkspace` output type of `Get-AzOperationalInsightsWorkspace`
(<https://learn.microsoft.com/en-us/dotnet/api/microsoft.azure.commands.operationalinsights.models.psworkspace>):
it lists the private link scopes the workspace belongs to, so it can only have content in that configuration. A
check author who read that page could plausibly treat "has a private link scope" as part of "healthy". The
documentation does not say what a workspace outside a scope returns.

This is a constructed example of the mechanism, not a claim that real health checks demand this property. The real
case is in SkyCraft: two health checks demanded fields the service did not return, their tests passed on
hand-written objects, and one live run showed the fields were empty.

## Tool versions and timing

- The stubbed suite first prints a `Tool versions:` line for PowerShell and Pester, the live read one for PowerShell,
  Az.Accounts and Az.OperationalInsights. A tool whose version differs from the one the result was observed with gets
  a `WARNING:` line naming both versions. No run in the log records a version for these tools, so today they are
  printed under `Not compared` (`config/demo-tools.psd1` holds the observed versions).
- Expected duration: not timed yet. The suite is one offline test; the live read is one Azure call.
- Warm-up: none is known.

## Results

- **Observed 2026-11-03**, on a workspace from the earlier setup (code at `1992109`, recorded in PR #2): the property
  was empty, so strict health was `False`.
- **Observed 2026-11-03**, current setup (workspace deployed from `infra/declared.bicep`, run `202611031935`, code at
  `15907c2`, exit 0): `PrivateLinkScopedResources: (empty)`, `ProvisioningState: Succeeded`, `Strict health: False`.
- **Observed 2026-11-08**, the newest full run (run `202611081831`, code at `0571f52`, exit 0): the same three lines.
  See [docs/live-run-log.md](../../docs/live-run-log.md). Run it again before each delivery.

## On stage

1. Show `Test-WorkspaceHealth.ps1`: it passes only with `ProvisioningState` `Succeeded` and a non-empty
   `PrivateLinkScopedResources`. A missing state, a missing property or any other state returns `False`; nothing
   missing is read as success.
2. Run the stubbed suite, which is green:

   ```powershell
   Invoke-Pester ./demos/3-stub-proves-assumption -Output Detailed
   ```

   It confirms the logic for the stub you wrote.
3. Run the live read against the current run (needs `Connect-AzAccount` and a run from
   `scripts/Start-DemoRun.ps1`):

   ```powershell
   ./demos/3-stub-proves-assumption/Show-LiveProperty.ps1
   ```

   Expected output (shape):

   ```text
   PrivateLinkScopedResources: (empty)
   ProvisioningState: Succeeded
   Strict health: False
   One read of this workspace, in this configuration, at this moment.
   ```

4. State what it settles: for this workspace the assumption behind the stub did not hold, so the check as
   written would report an unhealthy workspace that is provisioned. It does not settle whether other workspaces
   differ. The remedy is the rule itself: build the check from what a live read returns, and keep the stub as a
   copy of that response.

`tests/WorkspaceHealth.Tests.ps1` covers the function and the live-read script with mocks and runs in CI. Those
mocks check the program's logic; they do not replace step 3.
