# Offline student pack

Five of the demos run without an Azure subscription. One command runs them and prints, for each demo, the green
result, the reveal (why green is not proof) and the fix. Each demo has an exercise and an answer key.

## Run it

From the repository root, with PowerShell 7:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-OfflinePack.ps1; $LASTEXITCODE
```

Run some demos with `-Demo 4` or `-Demo 2,4` (ids 2, 3, 4, 6, 7). The pack makes no Azure call and creates nothing.

| Demo | What it shows | Needs |
| --- | --- | --- |
| 2 | a `-DryRun` switch that guards only some calls | Pester |
| 3 (stub half) | a stubbed test that checks only its own assumption | Pester |
| 4 | a validator prints `[FAIL]` and the process exits 0 | Pester |
| 6 | the Bicep linter warns, the exit code stays 0 | Bicep CLI |
| 7 | PSRule evaluates zero rules, the exit code stays 0 | PSRule, PSRule.Rules.Azure |

Demos 0, 1 and 5 and the live half of demo 3 need an Azure subscription and are not in the pack.

## Exit codes

- 0: every selected demo passed. A demo passes only when each command exits with the code the demo documents and
  prints the lines the pack expects, so a demo that stops showing its point fails.
- 1: a demo failed (the pack names it), or a demo was not run because a prerequisite is missing (the pack names the
  tool, skips only that demo and says `NOT RUN`). A run in which nothing was selected also exits 1.

## Exercises

1. Run the pack and read the green result and the reveal it prints for a demo.
2. Open that demo's exercise and answer the questions before you look at the answers.
3. Compare with the answer key. The answer keys are separate files so you can keep them closed.

| Demo | Exercise | Answer key |
| --- | --- | --- |
| 2 | [exercises/demo-2.md](exercises/demo-2.md) | [answers/demo-2.md](answers/demo-2.md) |
| 3 | [exercises/demo-3.md](exercises/demo-3.md) | [answers/demo-3.md](answers/demo-3.md) |
| 4 | [exercises/demo-4.md](exercises/demo-4.md) | [answers/demo-4.md](answers/demo-4.md) |
| 6 | [exercises/demo-6.md](exercises/demo-6.md) | [answers/demo-6.md](answers/demo-6.md) |
| 7 | [exercises/demo-7.md](exercises/demo-7.md) | [answers/demo-7.md](answers/demo-7.md) |

Each demo's own README, under `demos/`, has the full on-stage steps and what each check settles and does not settle.
