# Demo 4: a gate you never saw red

A validator prints `[FAIL]`, ends with "Validation complete" and the pipeline stays green. The talk's core uses this
demo (act 2): it runs locally with PowerShell 7, makes no Azure call and costs nothing.

The rule: a green gate is a declaration until you have seen it go red. The stronger check is the process exit code,
read from the process itself, and a run of the gate against an input that must fail.

## Why it is green

The script counts the failures and calls `exit 1`, yet the process exits 0. What is documented: the exit code is lost
when the script starts with `#Requires -Modules` and runs under `pwsh -File`, and `Test-Lab.Fixed.ps1` keeps it by
calling `$Host.SetShouldExit($code)` before `exit`. Observed on PowerShell 7.6.9 (2026-11-03, see
[docs/live-run-log.md](../../docs/live-run-log.md)); the origin is SkyCraft PR 109, linked below. Why the host drops the
code is observed, cause not documented here. The gate reads only the process exit code, so it shows green.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| The validator's last line ("Validation complete") | that the script reached its end | whether any check failed |
| The process exit code, read with `pwsh -File` | what an automation actually sees for this script, on this PowerShell version | whether the checks inside are the right ones |
| The validator against an empty or incomplete input | that the gate can go red for this input | that it goes red for every defect; one failing input is a probe, not coverage |

## Origin

All three behaviours were found in SkyCraft:

- A validator printed `[FAIL]` for each check and exited 0 ([#241](https://github.com/mbiszczanik/skycraft/issues/241),
  [#254](https://github.com/mbiszczanik/skycraft/issues/254)). The CI job of a repository showed `success` with
  `Tests Passed: 1632, Failed: 5` in its log ([#128](https://github.com/mbiszczanik/skycraft/issues/128)).
- A script counted failures and called `exit 1`, but PowerShell 7 dropped the code under `pwsh -File` because the
  script declared `#Requires -Modules` for a module it had to import
  ([PR 109](https://github.com/mbiszczanik/skycraft/pull/109)).

## Files

| File | What it is |
| --- | --- |
| `Test-Lab.Silent.ps1` | prints `[FAIL]`, never sets an exit code |
| `Test-Lab.Counted.ps1` | counts failures and calls `exit 1`, with a `#Requires -Modules Pester` line |
| `Test-Lab.Fixed.ps1` | the same, plus `$Host.SetShouldExit($code)` before `exit`; an unreadable state counts as a failure |
| `state-empty.json`, `state-ok.json` | the fake lab state each validator reads |
| `Invoke-Gate.ps1` | runs a validator in a child `pwsh -File` process and prints its exit code and the number of failure lines |

## On stage

Each run prints the tool versions, then the validator's output, then the process exit code and the number of `[FAIL]`
lines.

1. A validator that never sets an exit code:

   ```powershell
   ./demos/4-gate-never-red/Invoke-Gate.ps1 -Script Silent -State Empty
   ```

   Expected: two `[FAIL]` lines, `Process exit code: 0`, "The gate would PASS although the output shows a failure."
2. A validator that counts and calls `exit 1`:

   ```powershell
   ./demos/4-gate-never-red/Invoke-Gate.ps1 -Script Counted -State Empty
   ```

   Expected: "Validation complete: 2 failed." and still `Process exit code: 0`. The code is lost, not unset.
3. The fixed validator, first against the empty state, then against a complete one:

   ```powershell
   ./demos/4-gate-never-red/Invoke-Gate.ps1 -Script Fixed -State Empty
   ./demos/4-gate-never-red/Invoke-Gate.ps1 -Script Fixed -State Ok
   ```

   Expected: `Process exit code: 1` for the empty state, `0` for the complete one.
4. State what was shown: on this PowerShell version, these scripts, this input. The probe with an empty state is
   what makes the gate trustworthy. It does not show that every defect would turn the gate red.

## Tool versions and timing

- Each run first prints a `Tool versions:` line for PowerShell and Pester (the module the `#Requires` line of
  `Counted` and `Fixed` imports). The result of step 2 was observed with PowerShell 7.6.9 (2026-11-03, run
  `202611032044`); on any other version the run prints
  `WARNING: PowerShell is <version>; this demo's result was observed with PowerShell 7.6.9.` If that line shows,
  check step 2 before the stage: the lost exit code is behaviour of that PowerShell version. No run records a Pester
  version, so Pester is printed under `Not compared`. `config/demo-tools.psd1` holds the observed versions.
- Expected duration: not timed yet. Each run starts one child `pwsh` process and makes no network call.
- Warm-up: none is known.

## Tests

`tests/GateDemo.Tests.ps1` runs in CI. It checks that the two broken validators behave as described, that the fixed
one exits non-zero for an empty, partial, missing and unparseable state, and that it never exits 0 while its output
shows a failure. If the `Counted` test starts failing, PowerShell fixed the `#Requires` behaviour and the second step
of this demo needs a new story. These tests check the program's logic; the on-stage run is the live read.

## Results

Locally, no Azure involved. See [docs/live-run-log.md](../../docs/live-run-log.md) for the dated record.
