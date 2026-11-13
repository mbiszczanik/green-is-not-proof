# Answer key

Read this after you have written your own answers to the [exercises](exercises.md). Each answer restates what the
demo README records; the README of each demo has the dated observations and the limits.

## Demo 2: dry-run is not safe

1. `Register-AzResourceProvider` runs on every start, with or without the switch. Only
   `New-AzResourceGroupDeployment` sits in the `else` branch of `if ($DryRun)`.
2. Line 18, `Register-AzResourceProvider`. The call sits above the guard: the switch only guards the calls its author
   put behind it.
3. The registration moved into the non-dry branch, so the test finds no call outside the guard.
4. The test reports Az PowerShell cmdlets only. An `az` CLI call or a raw REST call (`Invoke-RestMethod`) passes
   unreported, and a green means "no unguarded call it recognises", not "the script is safe".

The rule: a dry-run switch is a declaration. The stronger check is a dry run followed by a look at the write
operations in the Activity Log; that check needs Azure and is not part of the pack.

## Demo 3: a stubbed test checks only your assumption

1. From the test itself: a hand-written stub with `ProvisioningState` `Succeeded` and the demanded property filled in.
2. The real service would have to return that property with content for the workspace. The stub states what the
   author believes the API returns; the test cannot check that belief.
3. The recorded live read returned the property empty, so the strict check reported `False` for a workspace whose
   state was `Succeeded`. For that workspace the assumption behind the stub did not hold.
4. One live read of the real resource (`Show-LiveProperty.ps1`, needs Azure). It tells you what the service returned
   for that workspace, in that configuration, at that moment, and nothing about other workspaces.

The rule: a stubbed test is a declaration of what you believe the API returns. The stubbed test still checks the
program's logic; the live read checks the assumption.

## Demo 4: a gate you never saw red

1. `Test-Lab.Silent.ps1` prints `[FAIL]` and never sets an exit code, so the process ends with 0. A gate that reads
   only the exit code sees a pass.
2. On PowerShell 7.6.9 the process exits 0 although the script calls `exit 1`: the exit code is lost when a script
   that starts with `#Requires -Modules` runs under `pwsh -File`. On another PowerShell version the result may
   differ; the run prints a `WARNING:` line in that case, and then your observation is the one that counts.
3. It calls `$Host.SetShouldExit($code)` before `exit`, and it counts an unreadable state as a failure.
4. An input that must fail, here the empty state. The gate must go red. One failing input is a probe: it shows the
   gate can go red, not that it goes red for every defect.

The rule: a green gate is a declaration until you have seen it go red.

## Demo 6: a gate that reads only the exit code

1. Only the process exit code of the linter.
2. 0. A `Warning` is printed and does not change the exit code.
3. The output: it fails when a `Warning` or `Error` diagnostic line is printed.
4. It shows that the fixed gate is not simply always red: on a template without diagnostics both gates pass.

The rule: an exit code is a declaration by the tool. The stronger check also reads what the tool printed.

## Demo 7: a gate that passes when nothing was evaluated

1. Zero: the output says `Rules processed: 0`.
2. No. It sets TLS 1.0 and allows public blob access.
3. Bicep file expansion (`AZURE_BICEP_FILE_EXPANSION`) is off, so no rule targets the file. PSRule prints a warning
   that the object was not processed, evaluates nothing and exits 0.
4. The summary line: it needs at least one rule processed and none errored. With the `Configured` pipeline 21 rules
   run and 8 fail, so both gates exit 1 and the template is rejected for the right reason (that run needs the Bicep
   CLI).

The rule: an exit code of 0 is a declaration that nothing failed, not evidence that anything ran.
