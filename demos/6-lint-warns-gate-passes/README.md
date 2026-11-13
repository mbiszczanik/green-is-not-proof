# Demo 6: a gate that reads only the exit code

Module C, first demo (issue #10). The Bicep linter prints a warning and still exits 0, so a gate that reads only the
process exit code passes a template the linter complained about. The demo runs the linter twice, through two gates, on
the same template.

Runs locally, no Azure access. Needs the Bicep CLI: `bicep`, or `az bicep` (the script uses the first one it finds,
and stops with exit 1 if it finds neither, so a missing linter is never a pass).

## Predict, run, reveal, fix, rule

### Predict

The Bicep linter prints a warning for `Sample.bicep`. Will a gate that reads only the linter's exit code pass or fail the
template?

### Run

```powershell
./demos/6-lint-warns-gate-passes/Invoke-Gate.ps1 -Gate Bare -Template Sample
```

Green: `Process exit code: 0` and `Bare gate: PASS`.

### Reveal

The output above the verdict holds the warning (`no-unused-params`) and `The gate would PASS although the output shows
a diagnostic.` A Warning does not change the linter's exit code.

### Fix

The fixed gate reads the output as well: `Invoke-Gate.ps1 -Gate Fixed -Template Sample` prints `Fixed gate: FAIL` and exits
1, and on `-Template Clean` both gates pass.

### Rule

An exit code is a declaration by the tool, so also read what the tool printed and fail on a diagnostic you care about.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| Bare gate: linter exit code is 0 | that the linter run itself did not fail | that the template has no diagnostics: a Warning does not change the exit code (observed, see Results) |
| Fixed gate: exit code 0 and no `Warning` or `Error` line in the output | that the linter printed no diagnostic on this template, with this configuration | that the template is correct or safe; it checks the linter's rules only |

## Origin

The Bicep documentation says, for the linter levels: `Warning` "Violations appear as Warnings in command-line build
output, but they don't cause the build to fail", and `Error` "cause the build to fail" (Bicep linter settings page,
ms.date 2026-06-15). It states no exit code number. This repository's own CI hit the same thing: its Bicep step reads
the diagnostics, not the exit code (`docs/self-audit.md`, "The Bicep linter exits 0 on warnings").

## On stage

```powershell
./demos/6-lint-warns-gate-passes/Invoke-Gate.ps1 -Gate Bare -Template Sample
./demos/6-lint-warns-gate-passes/Invoke-Gate.ps1 -Gate Fixed -Template Sample
```

Expected output of the first (exit code 0):

```text
.\Sample.bicep(3,7) : Warning no-unused-params: Parameter "legacyName" is declared but never used. [...]

Process exit code: 0
Warning or Error lines in the output: 1
Bare gate: PASS
The gate would PASS although the output shows a diagnostic.
```

The second prints the same diagnostic, then `Fixed gate: FAIL`, and exits 1. Run both with `-Template Clean` to show
that the fixed gate is not simply always red: both gates pass and neither prints the extra line.

State what it settles: for this template and this linter version, exit code 0 and a visible warning coexist. It does
not show how common this is, and a gate that treats warnings as failures may be stricter than a team wants.

Local paths in the linter output are printed as `.`, so a recording shows no user name.

## Tool versions and timing

- Each run first prints a `Tool versions:` line for PowerShell and the Bicep CLI, then an empty line; the expected
  output above follows it. The Bicep CLI is asked the way the linter is found: `bicep`, else `az bicep`. The result was
  observed with Bicep CLI 0.38.5 (2026-11-04); on any other version the run prints
  `WARNING: Bicep CLI is <version>; this demo's result was observed with Bicep CLI 0.38.5.` No run records the
  PowerShell version of this demo, so PowerShell is printed under `Not compared`. `config/demo-tools.psd1` holds the
  observed versions.
- Expected duration: not timed yet. Each run starts the Bicep CLI twice, once for its version and once for the lint.
- Warm-up: none is known for the `bicep` route. The `az bicep` route was not run through the demo scripts (see the
  log), so its start-up time is unknown.

## Results

- **Observed 2026-11-04** (Bicep CLI 0.38.5, run locally, see [docs/live-run-log.md](../../docs/live-run-log.md)):
  `Bare` on `Sample` exit 0 with `The gate would PASS although the output shows a diagnostic.`; `Fixed` on `Sample`
  exit 1; both gates exit 0 on `Clean`.
- **Observed 2026-11-08**, the newest run (local part of the block of run `202611081831`, code at `0571f52`): the same
  four exit codes, 0, 1, 0, 0. That block does not record the printed lines or the Bicep CLI version.
- Run it again before each delivery and add a dated block to the log.

## Tests

`tests/LintGateDemo.Tests.ps1` runs in CI. It checks the program's logic with fixed input: the two gates on each exit
code and output, the az output format, masking of local paths, and that a missing linter throws. The tests that call
the real linter are skipped when neither `bicep` nor `az` is installed. With the Fixed gate changed to ignore the
output, three of the 16 tests turn red.
