# green-is-not-proof

A green check in Azure is a declaration, not evidence.

Here you get runnable PowerShell demos that show a check passing while the thing it checks is broken, the
independent read that catches each one, and a one-page [cheat sheet](docs/cheat-sheet.md).

## Talk

- Title: "Green is not proof" (Polish subtitle: "Pułapki weryfikacji w Azure i jak je wyłapać")
- Language: Polish, with everyday English industry terms
- Audiences: community meetups of engineers and developers; a university guest lecture for engineering students
- Write-up: TODO(author): link to the blog article

The repository applies the talk to itself: [docs/self-audit.md](docs/self-audit.md) lists the checks in this
repository that were declarations, and what the independent evidence showed.

Author: Marcin Biszczanik, Cloud and Platform Consultant. [mbiszczanik.dev](https://mbiszczanik.dev) ·
[GitHub](https://github.com/mbiszczanik)

## The question and the four rules

Before trusting any green, ask: **What would this show if it did not work?** Evidence is what you read back from a
source independent of the thing being checked.

1. A tag is a declaration. Evidence: the group's full inventory compared with the deployment record.
2. A successful delete is a declaration. Evidence: listing the non-cascaded child resources, read back after the
   delete.
3. A dry-run switch is a declaration. Evidence: a dry run under a Reader-only identity, with zero write operations
   in the Activity Log. The syntax-tree test is a fast pre-check, not evidence that nothing mutated.
4. A stubbed test is a declaration. Evidence: the same assertion against one live read of the real resource.

Each rule has a command in the [cheat sheet](docs/cheat-sheet.md).

## Status

Demos 1 and 3 and the teardown ran live once on 2026-11-03 (swedencentral, one run, teardown exit 0, nothing
left). Setup and demo 0 were reworked since (a Bicep deployment and a separate rogue-VM script) and have not run
live in their new form. Demo 2 is offline by design. The backup recordings are still to be made.

## Prerequisites

- PowerShell 7.6
- The Bicep CLI on PATH (`New-AzResourceGroupDeployment` compiles `infra/declared.bicep` with it)
- Pester 5.5 to 5.x
- The Az PowerShell modules: Az.Accounts, Az.Resources, Az.Storage, Az.Monitor, Az.OperationalInsights,
  Az.Network, Az.Compute
- A test subscription in which you may create resources
- `Connect-AzAccount` done before running (do it off-screen when presenting)

## Run a demo session

One-time local setup, once per clone and machine:

1. Name the demo subscription: set the environment variable `GNP_SUBSCRIPTION_ID`, or put the id on the first
   line of `~/.config/green-is-not-proof/subscription.txt`. Setup, demos and teardown refuse to run when
   the current Azure subscription is a different one (`Set-AzContext` first).
2. Create `~/.config/green-is-not-proof/deny.txt` with the tenant and organisation names that must never appear in
   the repository, one per line. The public-content check reads it; the file is never committed. CI reads the same
   list from the repository secret `GNP_DENY_LIST` (see Tests and CI).
3. Enable the pre-push check: `git config core.hooksPath .githooks`.

Then, from the repository root:

```powershell
pwsh -NoProfile -File ./scripts/Start-DemoRun.ps1 -Location swedencentral; $LASTEXITCODE
```

This checks the subscription, runs the cost guard (which prices every item of the run, the rogue VM included),
creates one resource group, deploys the declared resources from `infra/declared.bicep` as one deployment and writes
`out/run.json`. It refuses to start while an `out/run.json` from an earlier run exists: tear that run down first.

Then create demo 0's rogue VM outside the declared deployment:

```powershell
pwsh -NoProfile -File ./scripts/New-RogueResource.ps1; $LASTEXITCODE
```

Then run the demos in order. Each has its own README with the on-stage steps:

1. [Demo 0: a tag is not proof of ownership](demos/0-tag-is-not-ownership/README.md)
2. [Demo 1: deleted is not cleaned up](demos/1-deleted-is-not-cleaned/README.md)
3. [Demo 2: dry-run is not safe](demos/2-dry-run-is-not-safe/README.md)
4. [Demo 3: a stubbed test proves only your assumption](demos/3-stub-proves-assumption/README.md)

Tear everything down and read back what is left:

```powershell
pwsh -NoProfile -File ./scripts/Stop-DemoRun.ps1; $LASTEXITCODE
```

Process exit code: 0 on success, 1 on failure (run them with `pwsh -File` as above so the code is real).
`Stop-DemoRun.ps1` lists the diagnostic settings again after removing them, checks the group is gone and queries
resources tagged with the run id. Its last line says what it checked and what it did not (untagged resources outside
the group). A non-zero exit code means something is left: read the output before leaving the room. Pass `-RunId` to tear
down a run whose `out/run.json` is gone.

Creating the VNet makes Azure create a free Network Watcher in `NetworkWatcherRG`, outside the run's group.
Teardown leaves it on purpose: it is shared, and nothing in it is tagged with the run id.

## Cost

The cost guard in `lib/CostGuard.ps1` prices the run from the Azure Retail Prices API before anything is
created, and refuses to continue above the per-run limit of 2 EUR. Its live estimate on 2026-11-03 for
`swedencentral` and 2 hours:

| Item | Approx. EUR |
| --- | --- |
| VM Standard_B2ts_v2 | 0.02 |
| OS disk E4 | 0.01 |
| Storage | 0.00 |
| Log Analytics, 0.1 GB | 0.27 |
| VM auto-shutdown schedule | no charge |
| Total | 0.29376 |

Standard_B1s had a capacity restriction in `swedencentral` and `northeurope` on 2026-11-03, and
`Standard_B2ats_v2` failed allocation, so the rogue VM is a `Standard_B2ts_v2`. Change the size in
`scripts/New-RogueResource.ps1` and `config/demo-resources.psd1` together if it is restricted too.

The Log Analytics figure ignores the free 5 GB tier on purpose (conservative). Prices change; the guard reads them again on every run.

The guard protects the start, not a forgotten teardown. `New-RogueResource.ps1` gives the VM an auto-shutdown
schedule 3 hours ahead (UTC), which stops the compute charge; the disk, storage and workspace keep billing until
teardown. For a hard ceiling, set a budget alert on the test subscription once.

## Tests and CI

```powershell
Invoke-Pester ./tests -Output Detailed
```

CI runs `./tests`, PSScriptAnalyzer (pinned), the Bicep linter (failing on warnings), markdownlint-cli2 (pinned) and
the public-content check. The suites under `demos/` are excluded on purpose: the on-stage suites of demos 2 and 3
are shown live, and demo 2 is meant to fail red.

The public-content check in CI needs the repository secret `GNP_DENY_LIST`: the tenant and organisation names, one
per line, as in the local `deny.txt`. Without it, CI fails on pushes and same-repository pull requests; on a pull
request from a fork, which gets no secrets, it prints that the deny list was not checked.

The pre-push hook (`git config core.hooksPath .githooks`) checks the working tree and every commit being pushed; CI checks pull request commits too.

## Safety

- Nothing is deleted outside the run's resource group.
- Teardown stops on any lookup error instead of guessing that something is gone, stops before deleting
  anything if demo 1 left the run's storage account missing (its diagnostic setting may survive), and stops if a
  diagnostic setting is still listed after its removal.
- Output masks the subscription id, e-mail addresses and any GUID not on `tools/public-content-allow.txt`.
- `out/run.json` holds raw ids and is gitignored.

## More

The full ownership audit and dry-run gate live in [SkyCraft](https://github.com/mbiszczanik/skycraft).

## License

MIT, see [LICENSE](LICENSE).
