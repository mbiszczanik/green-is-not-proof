# Answer key, demo 4

1. Exit code 0: the script never sets one. A pipeline that reads only the exit code concludes the validation passed,
   although the output shows two failures ("The gate would PASS although the output shows a failure").
2. `Counted` starts with `#Requires -Modules Pester`. Observed on PowerShell 7.6.9: under `pwsh -File` the exit code
   of such a script is lost, so it exits 0 although it called `exit 1`. The demo README records the behaviour as
   observed and does not document why the host drops the code. `Fixed` calls `$Host.SetShouldExit($code)` before
   `exit`, which keeps the code.
3. Run the gate against an input that must fail, and read the exit code from the process itself (here with
   `pwsh -File`, as `Invoke-Gate.ps1` does). A gate you never saw red is a declaration.
4. No. One failing input is a probe, not coverage: it shows the gate can go red for that input, on this PowerShell
   version, with these scripts.

The rule: a green gate is a declaration until you have seen it go red. The stronger check is the process exit code,
read from the process itself, and a run of the gate against an input that must fail.
