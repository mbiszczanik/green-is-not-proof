# Contributor rules

Rules for everyone who changes this repository. Purpose and demo steps are in [README.md](README.md).

## Layout

- `scripts/`: demo setup, rogue resource and teardown (PowerShell, they touch Azure).
- `lib/`: functions the scripts share.
- `tools/`: CI helpers, the public-content check and its allowlists.
- `tests/`: Pester suites, offline. The suites under `demos/` are shown live and excluded from CI on purpose.
- `infra/`: the declared Bicep deployment.
- `docs/`: cheat sheet, self-audit, talk evidence and the dated live run log.

## Check before you push

- `mise run check:fast`: seconds, no credentials, no Azure call (PSScriptAnalyzer and the public-content check).
- `mise run check`: the offline lane CI runs (Pester, PSScriptAnalyzer, Bicep lint, markdownlint, public content).
- Needs PowerShell 7.6, Pester 5.5 to 5.99, PSScriptAnalyzer 1.25.0, PSRule 2.9.0, PSRule.Rules.Azure 1.47.0, the Bicep CLI 0.38.5 and Node.js. Without PSRule or Bicep the real-rule tests skip and CI fails on an unlisted skip.
- Run PowerShell as `pwsh -NoProfile -File <script>` and read the process exit code. Run Pester with `-CI`.
- Enable the pre-push hook once per clone: `git config core.hooksPath .githooks`.

## Conventions

- A check that cannot fail is not evidence. A new check shall be shown to fail on a bad input before it is trusted.
- Report a result only with the command and its exit code. A live Azure run is recorded in `docs/live-run-log.md` with the date.
- A skipped test shall be listed with a reason in `tools/ci-skip-allow.txt`.
- Never run the demo scripts against a subscription other than the one named for the demos. They refuse to start otherwise.
- Public repository: no real person, e-mail address, tenant or organisation name, subscription or resource id, local path with a user name, venue or exact event date in any file, commit or PR text. Use roles or placeholders. `tools/Test-PublicContent.ps1` enforces part of this.
- Keep comments short: the non-obvious fact only.
- Work on a branch and merge through a pull request; CI shall be green first.
