# Exercise, demo 4: find why it is green

Run `pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1 -Demo 4`. Each validator under
`demos/4-gate-never-red/` checks the fake lab state in `state-empty.json`, which holds nothing, so every check should
fail.

1. `Test-Lab.Silent.ps1` prints `[FAIL]` twice. What exit code does the process report, and what does a pipeline
   that reads only the exit code conclude?
2. `Test-Lab.Counted.ps1` counts the failures and calls `exit 1`, yet the process exits 0. Look at its first line and
   at `Test-Lab.Fixed.ps1`: what is different?
3. How would you check that a gate can go red at all?
4. The fixed validator exits 1 on the empty state. Does that show every defect would turn the gate red?

Write your answers down, then compare them with [the answer key](../answers/demo-4.md).
