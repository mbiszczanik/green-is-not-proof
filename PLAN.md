# Plan: P0 evidence wording, independent demo 0, teardown read-back

Refs #3, #4. Deleted in the PR's last commit.

- [x] Bicep template `infra/declared.bicep` for the declared resources; one deployment per run
- [x] `Start-DemoRun.ps1` deploys the template; no VM
- [x] `scripts/New-RogueResource.ps1` creates the rogue VM outside the deployment
- [x] Ownership audit reads the deployment record; fails when it cannot
- [x] Remove `config/demo-manifest.psd1`
- [x] Teardown: read diagnostic settings back after removal; honest final message and help text
- [x] Rule wording in README, cheat sheet, demo READMEs; question on the cheat sheet
- [x] Demo 3 README: remove the stale sentence, point to the gate demo
- [x] CI: Bicep lint fails on warnings
- [x] Tests, PSScriptAnalyzer, public-content check
