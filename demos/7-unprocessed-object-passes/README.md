# Demo 7: a gate that passes when nothing was evaluated

Module C, second demo (issue #10). `Assert-PSRule` exits 0 when no rule targeted the input: PSRule prints a warning,
evaluates nothing and reports success. A gate that reads only the exit code passes a template that was never checked.
The demo runs the same insecure template through the same gate twice, with and without the setting that makes PSRule
read the Bicep file.

Runs locally, no Azure access. Needs PowerShell 7, the `PSRule` and `PSRule.Rules.Azure` modules and, for the
`Configured` pipeline, the Bicep CLI. A missing module stops the demo with exit 1, so a missing tool is never a pass.

## Five steps

### 1. Predict

The template has TLS 1.0 and public blob access, and a gate runs `Assert-PSRule` on it. Does the gate fail?

### 2. Run

`./demos/7-unprocessed-object-passes/Invoke-Gate.ps1 -Gate Bare -Pipeline Misconfigured` prints
`Process exit code: 0` and `Bare gate: PASS`.

### 3. Reveal

The same output says `Rules processed: 0`: with Bicep expansion off no rule targeted the file, and PSRule printed a
warning and reported success.

### 4. Fix

`-Gate Fixed -Pipeline Misconfigured` also reads the number of rules evaluated: it prints `Fixed gate: FAIL` and
exits 1. With `-Pipeline Configured` 21 rules run, 8 fail and both gates exit 1.

### 5. Rule

An exit code of 0 is a declaration that nothing failed, not evidence that anything ran; the stronger check also reads
how many rules were evaluated and fails on zero.

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

Local paths in the output are printed as `.`, so a recording shows no user name.

## Tool versions and timing

- Each run first prints a `Tool versions:` line for PowerShell, PSRule, PSRule.Rules.Azure and the Bicep CLI, then an
  empty line; the expected output above follows it. For a module it is the highest installed version, the one the
  child process imports. For the Bicep CLI it is the one `PSRULE_AZURE_BICEP_PATH` names when that variable is set,
  else `bicep` on the path, else `az bicep`.
- The result was observed with PowerShell 7.6.9, PSRule 2.9.0, PSRule.Rules.Azure 1.47.0 and Bicep CLI 0.38.5
  (2026-11-05). For each tool on another version the run prints a line such as
  `WARNING: PSRule is <version>; this demo's result was observed with PSRule 2.9.0.` A tool that is not found gets a
  warning too. `config/demo-tools.psd1` holds the observed versions.
- Expected duration: not timed yet. The `Configured` pipeline compiles the Bicep file and is the slower one.
- Warm-up: run the `Configured` pipeline once before the stage. The first run after a cold start hit PSRule's compile
  timeout on the author's machine (see Results), which makes the gate fail for a different reason; the next run
  completed normally.

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
- **Observed 2026-11-08**, the newest run (local part of the block of run `202611081831`, code at `0571f52`): `Bare`
  on `Misconfigured` exit 0 with `Rules evaluated: 0`; `Fixed` on `Misconfigured` exit 1; `Fixed` on `Configured` exit
  1 with `Rules processed: 21, failed: 8`. That block does not record the module versions.
- Run it again before each delivery and add a dated block to the log.

## Which rule judged which resource

The output of `Invoke-Gate.ps1` names the failed rules and counts them; it does not name the resource a rule failed
on (its one `WARN` line names the file). `tests/StorageCanary.Tests.ps1` ties the two rules this demo is about to the
account: with Bicep expansion on, PSRule returns a record for `Azure.Storage.MinTLS` (AZR-000200) and
`Azure.Storage.BlobPublicAccess` (AZR-000198) with target `stdemoinsecure01` of type `Microsoft.Storage/storageAccounts`
and outcome `Fail`, and the same two rules on `Storage.Fixed.bicep` (account `stdemosecure01`) with outcome `Pass`.
`Storage.Fixed.bicep` passes the whole ruleset, so it also sets tags, zone redundancy, shared key access off, a firewall
default of deny and soft delete; only `minimumTlsVersion` and `allowBlobPublicAccess` correspond to the two named rules,
and the other six failures of the insecure template come from the other settings. A missing record, another target,
another outcome, an `Error` record, an empty result and a Bicep compilation timeout each fail the test, the timeout
as an infrastructure failure and not as a statement about the account; so does any evaluation error except one message
that PSRule 2.9.0 itself reports on a run that returns all 21 records (a missing variable in `PSRule.psm1`, seen
outside the tests too). Static analysis of a template: it does not read any state from Azure.

## Tests

`tests/StorageCanary.Tests.ps1` runs in CI with the real rules; it is skipped, and the CI gate rejects the skip, when
`PSRule.Rules.Azure` is not installed.

`tests/UnprocessedGateDemo.Tests.ps1` runs in CI. It checks the program's logic with fixed input: the summary
parser, the two gates on each exit code and summary, masking of local paths, and that a missing module exits 1. The
tests that call the real rules are skipped when `PSRule.Rules.Azure` is not installed. CI installs PSRule, the rule
module and the Bicep CLI (pinned to the versions under Results), so they run there, and the CI gate fails on any skipped
test that is not on the allowlist `tools/ci-skip-allow.txt`.
