# Answer key, demo 6

1. The `Warning no-unused-params` line: `legacyName` is declared and never used in `Sample.bicep`. The linter prints it
   and still exits 0.
2. It reads only the linter's process exit code. It does not read what the linter printed. The Bicep documentation
   says warnings do not fail the build, and the pack shows exit code 0 next to one diagnostic line (observed with
   Bicep CLI 0.38.5).
3. It also fails on any `Warning` or `Error` line in the output. On `Clean.bicep` both gates pass and print no
   diagnostic, so the fixed gate is not simply always red.
4. It is stricter than the linter itself: a team that accepts some warnings would fail on them. It also checks only
   the linter's rules, so a pass does not mean the template is correct or safe.

The rule: an exit code is a declaration by the tool. The stronger check also reads what the tool printed, and fails
on a diagnostic it cares about.
