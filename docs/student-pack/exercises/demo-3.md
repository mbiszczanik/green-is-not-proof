# Exercise, demo 3: find why it is green

Run `pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1 -Demo 3`, then open
`demos/3-stub-proves-assumption/Test-WorkspaceHealth.ps1` and `Health.Stubbed.Tests.ps1`. The pack runs the stub half
offline. The live half needs Azure, so the pack feeds the check an object shaped like the live read the README
records: `ProvisioningState` is `Succeeded` and `PrivateLinkScopedResources` is empty.

1. What does the hand-written stub in `Health.Stubbed.Tests.ps1` assume about what Azure returns?
2. Could the stubbed test ever turn red because of what Azure really returns? Why or why not?
3. The second pack step prints `Strict health: False` for a provisioned workspace. What is different from the stub?
4. What one extra check settles the assumption, and what would it still not settle?

Write your answers down, then compare them with [the answer key](../answers/demo-3.md).
