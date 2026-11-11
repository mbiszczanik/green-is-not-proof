# Demo 7: a gate that passes when nothing was evaluated

Module C, second demo (issue #10). `Assert-PSRule` exits 0 when no rule targeted the input: PSRule prints a warning,
evaluates nothing and reports success. A gate that reads only the exit code passes a template that was never checked.
The demo runs the same insecure template through the same gate twice, with and without the setting that makes PSRule
read the Bicep file.

The rule: an exit code of 0 is a declaration that nothing failed, not evidence that anything ran. The stronger check
also reads how many rules were evaluated, and fails on zero.

Runs locally, no Azure access. Needs PowerShell 7, the `PSRule` and `PSRule.Rules.Azure` modules and, for the
`Configured` pipeline, the Bicep CLI. A missing module stops the demo with exit 1, so a missing tool is never a pass.

## What each check settles

| Check | Settles | Does not settle |
| --- | --- | --- |
| Bare gate: `Assert-PSRule` exit code is 0 | that no rule that ran reported a failure | that any rule ran: zero rules evaluated also exits 0 (observed, see Results) |
| Fixed gate: exit code 0 and the printed summary shows at least one rule processed and none errored | that rules were evaluated on this input and none failed | that the rules are the right ones, or that the template is secure; it checks the PSRule Azure rule set only |

## Origin

The PSRule options page says, for `Execution.UnprocessedObject`: "By defaut, a warning is generated, however this
behaviour can be modified by this option", default `Warn` (checked on 2026-11-04, recorded in #10; that check found no exit
code on the page). The demo shows what the exit code is, in the configuration below.

## On stage

```powershell
./demos/7-unprocessed-object-passes/Invoke-Gate.ps1 -Gate Bare -Pipeline Misconfigured
./demos/7-unprocessed-object-passes/Invoke-Gate.ps1 -Gate Fixed -Pipeline Misconfigured
```

`Misconfigured` leaves `AZURE_BICEP_FILE_EXPANSION` off, the kind of slip a pipeline file can hold unnoticed. The
template, `Storage.bicep`, has TLS 1.0 and public blob access. Expected output of the first (exit code 0):

```text
    [WARN] Target object './Storage.bicep' has not been processed because no matching rules were found.
Rules processed: 0, failed: 0, errored: 0

Process exit code: 0
Rules evaluated: 0
Bare gate: PASS
The gate would PASS although no rule was evaluated.
```

The second prints the same warning, then `Fixed gate: FAIL`, and exits 1. Run both with `-Pipeline Configured` to show
that the check is not always red: with expansion on, PSRule evaluates 21 rules, 8 fail, and both gates exit 1 on the
same template, so the template is rejected for the right reason.

State what it settles: for this template, these module versions and this option, exit 0 and zero evaluated rules
coexist. It does not show how common this is in real pipelines.

Warm the Bicep compiler once before the stage (run the `Configured` pipeline once): the first run after a cold start
hit PSRule's compile timeout on the author's machine (see Results), which makes the gate fail for a different reason.

Local paths in the output are printed as `.`, so a recording shows no user name.

## Results

- **Observed 2026-11-05** (PSRule 2.9.0, PSRule.Rules.Azure 1.47.0, Bicep CLI 0.38.5, PowerShell 7.6.9, run locally,
  see [docs/live-run-log.md](../../docs/live-run-log.md)): `Bare` on `Misconfigured` exit 0 with `Rules evaluated: 0` and
  `The gate would PASS although no rule was evaluated.`; `Fixed` on `Misconfigured` exit 1; `Fixed` on `Configured`
  exit 1 with 21 rules processed and 8 failed.
- **Observed 2026-11-05**, a limit of the obvious fix: with `Execution.UnprocessedObject` set to `Error`, a run on a
  Bicep file with expansion on stopped with `has not been processed` and 0 rules processed, process exit 1, on a
  template that had no resources. One observation: the option made the unexpanded file object itself an error, so
  this demo does not use it.
- **Observed 2026-11-05**, a stage risk: on the first `Configured` run after a cold start PSRule printed
  `Bicep compilation hasn't completed within the timeout window` and the gate failed with exit 1 and 0 rules
  processed; the next run completed normally.
- Run it again before each delivery and add a dated block to the log.

## Tests

`tests/UnprocessedGateDemo.Tests.ps1` runs in CI. It checks the program's logic with fixed input: the summary
parser, the two gates on each exit code and summary, masking of local paths, and that a missing module exits 1. The
tests that call the real rules are skipped when `PSRule.Rules.Azure` is not installed. CI installs PSRule, the rule
module and the Bicep CLI (pinned to the versions under Results), so they run there, and the CI gate fails on any skipped
test that is not on the allowlist `tools/ci-skip-allow.txt`.
