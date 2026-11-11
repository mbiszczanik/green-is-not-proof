# Plan: demo 7 corrected template and rule-to-resource test (#54)

Spec: issue #54. Rules: AGENTS.md. This file is deleted in the last commit of the branch.

## Steps

1. [x] Write `tests/StorageCanary.Tests.ps1` first, with the helper `Get-RuleEvidenceFailure` and its synthetic-record cases (missing record, wrong target name, wrong target type, wrong outcome, an `Error` record, empty result), and the evaluation wrapper `Invoke-RuleEvaluation` that takes the evaluator as a scriptblock. Cases for the wrapper, all with an injected evaluator and written before the wrapper exists: an evaluator that throws or reports "Bicep compilation hasn't completed within the timeout window" gives an infrastructure failure (message names the infrastructure, no assertion about the account); an evaluator that returns no records without error (expansion off) gives the missing-record failure, a different message from the infrastructure one. Run it and show these cases failing before the wrapper is written. The live cases fail because the template does not exist yet.
2. [x] Add `demos/7-unprocessed-object-passes/Storage.Fixed.bicep`. Run the live cases: insecure template fails `MinTLS` and `BlobPublicAccess` on `stdemoinsecure01`; fixed template passes both and has no `Fail` or `Error`.
3. [x] Add the live probe with Bicep expansion off: no record for the account, the helper reports the missing-record message.
4. [x] Wire the real evaluator (`Invoke-PSRule`, expansion on or off, errors and warnings collected) into the wrapper. Warm the compiler once in `BeforeAll`, separately from the timeout coverage of step 1 (the warm-up lowers the chance of the failure; it is not the test of it).
5. [x] README of demo 7: the two rules, the test as evidence, the note that `Invoke-Gate.ps1` does not name the resource.
6. [x] Run `pwsh -NoProfile -File tools/Invoke-Check.ps1 -Lane Full` and `tools/Test-PublicContent.ps1 -CommitRange origin/main..HEAD`; read the exit codes.
7. [ ] Codex adversarial review of the diff against `main`; answer each finding.
8. [ ] Open the pull request (`Refs #54`, `Closes #54` only if CI at the head shows the new tests evaluated and 0 skipped); delete this file in the last commit.

## Not in this plan

No live Azure call. No change to `Invoke-Gate.ps1`, `Invoke-PSRuleChild.ps1`, other tests, the allowlist or CI.
