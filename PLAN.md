# Plan: demo 7 corrected template and rule-to-resource test (#54)

Spec: issue #54. Rules: AGENTS.md. This file is deleted in the last commit of the branch.

## Steps

1. [ ] Write `tests/StorageCanary.Tests.ps1` first, with the helper `Get-RuleEvidenceFailure` and its synthetic-record cases (missing record, wrong target name, wrong target type, wrong outcome, an `Error` record, empty result). Run it: the synthetic cases pass, the live cases fail because the template does not exist yet.
2. [ ] Add `demos/7-unprocessed-object-passes/Storage.Fixed.bicep`. Run the live cases: insecure template fails `MinTLS` and `BlobPublicAccess` on `stdemoinsecure01`; fixed template passes both and has no `Fail` or `Error`.
3. [ ] Add the live probe with Bicep expansion off: no record for the account, the helper reports the missing-record message.
4. [ ] Bicep compile timeout path: a record-less or timed-out evaluation fails with the infrastructure message, not an assertion about the account. Warm the compiler once in `BeforeAll`.
5. [ ] README of demo 7: the two rules, the test as evidence, the note that `Invoke-Gate.ps1` does not name the resource.
6. [ ] Run `pwsh -NoProfile -File tools/Invoke-Check.ps1 -Lane Full` and `tools/Test-PublicContent.ps1 -CommitRange origin/main..HEAD`; read the exit codes.
7. [ ] Codex adversarial review of the diff against `main`; answer each finding.
8. [ ] Open the pull request (`Refs #54`, `Closes #54` only if CI at the head shows the new tests evaluated and 0 skipped); delete this file in the last commit.

## Not in this plan

No live Azure call. No change to `Invoke-Gate.ps1`, `Invoke-PSRuleChild.ps1`, other tests, the allowlist or CI.
