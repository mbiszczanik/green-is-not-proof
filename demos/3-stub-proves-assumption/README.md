# Demo 3: a stubbed test proves only your assumption

A strict health check passes its test, because the test feeds it a hand-written stub object with the
demanded property filled in. The real resource may never return that property.

The rule: a stubbed test is a declaration of what you believe the API returns; one live read is proof.

Candidate property: `PrivateLinkScopedResources`. To be confirmed by a live read (Task 11); if it is populated
live, swap it for one that is not.

I chose it from the documented `PSWorkspace` output type of `Get-AzOperationalInsightsWorkspace`
(<https://learn.microsoft.com/en-us/dotnet/api/microsoft.azure.commands.operationalinsights.models.psworkspace>).
It lists the private link scopes the workspace belongs to, so it only has content in that configuration. The
documentation does not say what a fresh workspace returns; this is reasoning, not a live observation.

## On stage

1. Show `Test-WorkspaceHealth.ps1`: Strict demands `ProvisioningState` `Succeeded` and a non-empty
   `PrivateLinkScopedResources`.
2. Run the stubbed suite, which is green:

   ```powershell
   Invoke-Pester ./demos/3-stub-proves-assumption -Output Detailed
   ```

3. Run the live read against the current run (needs `Connect-AzAccount` and a run from
   `scripts/Start-DemoRun.ps1`):

   ```powershell
   ./demos/3-stub-proves-assumption/Show-LiveProperty.ps1
   ```

   Expected if the candidate holds: `PrivateLinkScopedResources: (empty)` and `Strict health: False`, while
   `Lenient health: True`.
4. Show the fix: `Test-WorkspaceHealth -Mode Lenient` fails only on an explicit `Failed` or `Deleting` state.

The stubbed suite lives here, not in `./tests`. `tests/WorkspaceHealth.Tests.ps1` covers the function and the
live-read script with mocks and runs in CI.

## Origin

In SkyCraft, two health checks demanded fields the service never returns. Their tests passed on hand-written
objects; one live run showed the fields were empty.
