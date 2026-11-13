# Answer key, demo 7

1. None: the line `Rules processed: 0, failed: 0, errored: 0`. PSRule printed a warning that the target object was
   not processed because no matching rules were found, and still exited 0.
2. The `Misconfigured` pipeline sets `AZURE_BICEP_FILE_EXPANSION` off, so PSRule sees a file object, not a storage account,
   and no rule targets it. With expansion on (the `Configured` pipeline, which needs the Bicep CLI and is not in the
   pack) PSRule evaluated 21 rules and 8 failed, observed 2026-11-05.
3. The printed summary: it fails when there is no summary line, when zero rules were processed or when any rule
   errored, so "nothing was evaluated" is no longer a pass.
4. One observation recorded in the demo README: with the option set to `Error`, a run with expansion on stopped at
   `has not been processed` with 0 rules processed and exit 1, on a template that had no resources, so the option made
   the unexpanded file object itself an error. It does not show how the option behaves in every pipeline.

The rule: an exit code of 0 is a declaration that nothing failed, not evidence that anything ran. The stronger check
also reads how many rules were evaluated, and fails on zero.
