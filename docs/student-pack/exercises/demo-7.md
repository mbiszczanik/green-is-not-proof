# Exercise, demo 7: find why it is green

Run `pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1 -Demo 7` (it needs the PSRule and PSRule.Rules.Azure
modules). `demos/7-unprocessed-object-passes/Storage.bicep` sets TLS 1.0 and public blob access, so a rule set for
Azure storage should object.

1. The bare gate passes. How many rules did PSRule evaluate, and where does the output say so?
2. Why did no rule run on the insecure template? Look at the `AZURE_BICEP_FILE_EXPANSION` option in `Invoke-PSRuleChild.ps1`.
3. What does the fixed gate read that the bare gate does not?
4. Setting `Execution.UnprocessedObject` to `Error` looks like an obvious fix. Read the Results section of the demo
   README: why does the demo not use it?

Write your answers down, then compare them with [the answer key](../answers/demo-7.md).
