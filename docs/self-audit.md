# Self-audit: declarations in this repository

A review of the demo kit on 2026-11-03 applied the talk's question to the repository itself: what would this
check show if it did not work? Each entry says what the green said, what the independent evidence showed, and the
fix. Fixes landed in the pull requests for issues #3 and #4.

## Demo 0: the "code-derived" inventory was hand-written

- Green: the ownership audit compared the group with "what the code declares" and flagged the rogue VM.
- Evidence: the expected names came from `config/demo-manifest.psd1`, a list someone typed. It was a declaration
  of the same kind as the tag it was meant to beat.
- Fix: the declared resources deploy from `infra/declared.bicep` as one deployment, and the audit reads that
  deployment's operations, a record Azure writes. A missing or failed record makes the audit exit 1.

## Demo 0: "a VM the code never created" was created by the code

- Green: the story said the VM came from outside the code.
- Evidence: `Start-DemoRun.ps1` created it, together with the declared resources.
- Fix: `scripts/New-RogueResource.ps1` creates it after setup, outside the deployment.

## Teardown ended on a tag query and claimed proof

- Green: `Stop-DemoRun.ps1` printed "Nothing tagged runId=... remains"; its help said it "proves nothing tagged with
  its run id remains".
- Evidence: a tag query is the declaration rule 1 warns about, and a diagnostic setting removal was trusted on the
  remove call's return.
- Fix: teardown lists diagnostic settings again after removing them and exits 1 if any remain. Its last line says
  what it checked and what it did not (untagged resources outside the group).

## The rules called a pre-check "proof"

- Green: "a syntax-tree test over every call is proof"; "one live read is proof".
- Evidence: a syntax-tree test shows where calls sit, not that nothing changed; neither rule named an independent
  source.
- Fix: every rule names its stronger check and what it does not settle. The dry-run check is a run followed
  by the write operations in the Activity Log; the syntax-tree test is a fast pre-check that
  finds specific calls and does not show a whole script is safe.

## Demo 3 accepted a missing state as success

- Green: the Lenient mode of the health check returned true for any workspace whose state was not `Failed` or
  `Deleting`.
- Evidence: a workspace object with no `ProvisioningState` at all passed.
- Fix: the Lenient mode is removed. Missing or blank state, a missing property, a null workspace or any state other
  than `Succeeded` returns false, and tests cover each.

## Demo 3's README contradicted itself

- Green: "Confirmed by a live read on 2026-11-03".
- Evidence: two paragraphs later, "this is reasoning, not a live observation".
- Fix: the stale sentence is gone.

## The dry-run gate failed open on unknown verbs

- Green: the gate reported no unguarded mutation.
- Evidence: it matched a list of mutating verbs, so `Copy-AzStorageBlob`, `ConvertTo-AzVMManagedDisk` and
  `Undo-AzKeyVaultSecretRemoval` passed unreported outside the guard.
- Fix: every `<Verb>-Az*` call counts as mutating unless its verb is on a read-only allow list. Tests for the
  three misses fail against the old gate and pass against the new one.

## The deny list was checked only on one machine

- Green: CI's public-content check passed.
- Evidence: the tenant and organisation deny list was an untracked local file read by an opt-in pre-push hook. CI
  never had it, so it checked e-mail addresses and GUIDs only.
- Fix: CI reads the list from a repository secret and fails without it, except on fork pull requests, where it says
  the list was not checked.

## The line split depended on invisible characters

- Green: the public-content check passed on every file.
- Evidence: its split pattern held literal CR and LF characters. Stripped of the CR, the pattern is an invalid
  regex and the check fails on every file.
- Fix: the pattern is `'\r?\n'`, `.gitattributes` pins LF for scripts and Markdown, and a test runs the check from
  LF-only and CRLF copies of itself.

## Configuration without a run

- Green: `.markdownlint-cli2.jsonc` suggested Markdown was linted.
- Evidence: nothing ran it.
- Fix: CI runs a pinned markdownlint-cli2. PSScriptAnalyzer, unpinned before, is pinned too.

## The Bicep linter exits 0 on warnings

- Green: `az bicep lint` exit 0.
- Evidence: on a template with an unused parameter it printed `Warning no-unused-params` and still exited 0.
- Fix: the CI step reads the diagnostics, not the exit code.

## The cost guard protected only the start

- Green: "Cost guard passed".
- Evidence: it prices a run before setup; nothing limits a run nobody tears down.
- Fix: the rogue VM gets a free auto-shutdown schedule 3 hours ahead, and the README suggests a budget alert on the
  test subscription. The generated SSH key is deleted after a clean teardown.

## The CI gate accepted skipped tests

- Green: the Pester gate accepted the suite.
- Evidence: the gate rejected failed, not-run and zero tests but never read the skipped count. CI installed only
  Pester, so the real-rule tests of demo 7 were skipped and CI stayed green. A test that checked "module not
  installed" was itself skipped whenever the module was installed.
- Fix: the gate prints the skipped count and fails on a skipped test that is not on `tools/ci-skip-allow.txt` with a
  reason. CI installs PSRule, PSRule.Rules.Azure and the Bicep CLI so those tests run. The "not installed" test no
  longer depends on the module being absent. Tests run a suite with one skipped, unlisted test through the gate and
  expect exit 1. A run in which every test is skipped and allowlisted is rejected too (`no test was evaluated`).

## Still open

The reworked setup, demo 0, demo 1, demo 3 and the teardown read-back ran live once on 2026-11-03 (see
[live-run-log.md](live-run-log.md)). The gate demo that replaces demo 3 on stage (demo 4) and the module A demo
(demo 5) were added afterwards. The rule 3 Activity Log check was observed afterwards (write-capable
account) and the Reader-only refusal was observed on 2026-11-04 (403, no log entry). Still open and tracked in #3
and #4: the backup recordings.
