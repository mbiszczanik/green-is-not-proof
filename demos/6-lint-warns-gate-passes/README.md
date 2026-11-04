# Demo 6: a gate that reads only the exit code

Module C candidate 1 (issue #10). The Bicep linter prints a warning and still exits 0, so a gate that reads only the
process exit code passes a template the linter complained about. The demo runs the linter twice, through two gates, on
the same template.

The rule: an exit code is a declaration by the tool. The stronger check also reads what the tool printed, and fails on
a diagnostic it cares about.

Runs locally, no Azure access. Needs the Bicep CLI: `bicep`, or `az bicep` (the script uses the first one it finds,
and stops with exit 1 if it finds neither, so a missing linter is never a pass).

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

## Results

- **Observed 2026-11-04** (Bicep CLI 0.38.5, run locally, see [docs/live-run-log.md](../../docs/live-run-log.md)):
  `Bare` on `Sample` exit 0 with `The gate would PASS although the output shows a diagnostic.`; `Fixed` on `Sample`
  exit 1; both gates exit 0 on `Clean`.
- Run it again before each delivery and add a dated block to the log.

## Tests

`tests/LintGateDemo.Tests.ps1` runs in CI. It checks the program's logic with fixed input: the two gates on each exit
code and output, the az output format, masking of local paths, and that a missing linter throws. The tests that call
the real linter are skipped when neither `bicep` nor `az` is installed. With the Fixed gate changed to ignore the
output, three of the 16 tests turn red.
