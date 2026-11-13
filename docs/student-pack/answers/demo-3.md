# Answer key, demo 3

1. That the workspace returns `PrivateLinkScopedResources` with content. The stub is what the author believes
   `Get-AzOperationalInsightsWorkspace` returns, written by hand.
2. No. The test never calls Azure, so it checks the program's logic for the object the author wrote, and stays green
   whatever the service returns.
3. The property is empty, as in the live read recorded in the README (observed 2026-11-03 and 2026-11-08). With an
   empty property and a `Succeeded` state, the strict check reports a provisioned workspace as unhealthy. The pack's
   object is constructed to have that shape; it is not a live read.
4. One live read of the real resource (`Show-LiveProperty.ps1`, which needs Azure), then building the check and the
   stub from what it returned. It settles what the service returned for that workspace, in that configuration, at
   that moment. It does not settle other workspaces, regions or API versions.

The rule: a stubbed test is a declaration of what you believe the API returns. The stronger check is the same
assertion against one live read of the real resource. The stubbed test still guards the logic.
