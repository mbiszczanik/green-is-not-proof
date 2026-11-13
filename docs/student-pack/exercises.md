# Exercises: find why it is green

Run the pack first (see [README.md](README.md)), then work through one demo at a time. Each exercise asks the same
thing in the end: what did the green check actually read, and what would it have shown if the thing were broken?
Write your answer down before you open the [key](answers.md).

## Demo 2: dry-run is not safe

Files: `demos/2-dry-run-is-not-safe/Deploy-Example.ps1` and `Deploy-Example.Fixed.ps1`. Read them; do not run them.

1. The script has a `-DryRun` switch. Which of its calls still run when the switch is set?
2. The pack shows one red test for this script. Which line does the failure name, and why does the switch not cover it?
3. What is different in `Deploy-Example.Fixed.ps1`?
4. The test only parses the script. Name one kind of call it would not report.

## Demo 3: a stubbed test checks only your assumption

Files: `demos/3-stub-proves-assumption/Health.Stubbed.Tests.ps1` and `Test-WorkspaceHealth.ps1`.

1. The suite is green. Where does the object that the health check receives come from?
2. What would have to be true about Azure for this green to mean "a provisioned workspace passes the check"?
3. The pack prints the result of a live read that it did not run. What does that result say about the stub?
4. Which single read would settle the question, and what would it still not tell you?

## Demo 4: a gate you never saw red

Files: `demos/4-gate-never-red/Test-Lab.Silent.ps1`, `Test-Lab.Counted.ps1` and `Test-Lab.Fixed.ps1`.

1. In the green step the validator prints two `[FAIL]` lines and the process exits 0. Why is the exit code 0?
2. `Test-Lab.Counted.ps1` counts the failures and calls `exit 1`. Run it through the gate and read the exit code:

   ```powershell
   pwsh -NoProfile -File ./demos/4-gate-never-red/Invoke-Gate.ps1 -Script Counted -State Empty; $LASTEXITCODE
   ```

   What did you get, and which line of the script is involved?
3. What does `Test-Lab.Fixed.ps1` do differently?
4. Before you trust a gate, which input would you run it against, and what must happen?

## Demo 6: a gate that reads only the exit code

Files: `demos/6-lint-warns-gate-passes/Invoke-Gate.ps1`, `Sample.bicep` and `Clean.bicep`.

1. In the green step the linter prints a warning and the gate passes. What does the bare gate read?
2. Which exit code does the linter give for a template with a warning?
3. What does the fixed gate read in addition?
4. Run both gates with `-Template Clean`. Why is that run part of the demonstration?

## Demo 7: a gate that passes when nothing was evaluated

Files: `demos/7-unprocessed-object-passes/Invoke-Gate.ps1` and `Storage.bicep`.

1. In the green step, how many rules were evaluated?
2. Read `Storage.bicep`. Would you expect a security rule set to accept it?
3. The pipeline is called `Misconfigured`. What is missing, and what does PSRule do with the file because of it?
4. What does the fixed gate read in addition to the exit code?
