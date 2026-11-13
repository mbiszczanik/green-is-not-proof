# Exercise, demo 2: find why it is green

Run `pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1 -Demo 2` from the repository root, then open
`demos/2-dry-run-is-not-safe/Deploy-Example.ps1`. The script has a `-DryRun` switch. Nobody runs the script: the test
only parses it.

1. A user runs `./Deploy-Example.ps1 -DryRun`. Which call still changes real state, and why?
2. The pack printed a green result for `Deploy-Example.Fixed.ps1`. What changed in that file?
3. Why does the test parse the script instead of running it with `-DryRun`?
4. The green test does not prove the script is safe. Name two kinds of call it cannot see.

Write your answers down, then compare them with [the answer key](../answers/demo-2.md).
