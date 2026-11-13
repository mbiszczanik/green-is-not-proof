# Exercise, demo 6: find why it is green

Run `pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1 -Demo 6` (it needs the Bicep CLI). The pack lints
`demos/6-lint-warns-gate-passes/Sample.bicep` through two gates. Open the template first.

1. The bare gate prints PASS. Which line of the linter output would you have expected to stop it, and which line of
   the template causes it?
2. What does the bare gate read, and what does it not read?
3. What does the fixed gate read in addition? Run `./demos/6-lint-warns-gate-passes/Invoke-Gate.ps1 -Gate Fixed
   -Template Clean` and explain why that result matters for trusting the fixed gate.
4. Name one reason a team might not want the fixed gate.

Write your answers down, then compare them with [the answer key](../answers/demo-6.md).
