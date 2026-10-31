# green-is-not-proof

Live Azure demos and a cheat sheet for the talk "Green is not proof": a green check in Azure is a
declaration, not evidence. The talk is delivered in Polish at meetups and a university lecture in
November and December 2026. This repository holds the demo kit and the English cheat sheet.

## The four rules

1. A tag is a declaration; a code-derived inventory is proof.
2. A successful delete is a declaration; listing the non-cascaded children afterwards is proof.
3. A dry-run switch is a declaration; a syntax-tree test over every call is proof.
4. A stubbed test is a declaration; one live read is proof.

Each rule has a command and a sentence in the [cheat sheet](docs/cheat-sheet.md).

## Status

Live verification pending. The demos are unit-tested offline and the tests run in CI, but they have not
yet been run against Azure. Demo 3's property is a candidate to confirm in a live read. No live result is
recorded in this repository.

## Prerequisites

- PowerShell 7.6
- Pester 5.5 to 5.x
- The Az PowerShell modules: Az.Accounts, Az.Resources, Az.Storage, Az.Monitor, Az.OperationalInsights,
  Az.Network, Az.Compute
- A test subscription in which you may create resources
- `Connect-AzAccount` done before running (do it off-screen when presenting)

## Run a demo session

From the repository root:

```powershell
pwsh -NoProfile -File ./scripts/Start-DemoRun.ps1 -Location swedencentral; $LASTEXITCODE
```

This runs the cost guard, creates one resource group with the demo resources and writes `out/run.json`.
Then run the demos in order. Each has its own README with the on-stage steps:

1. [Demo 0: a tag is not proof of ownership](demos/0-tag-is-not-ownership/README.md)
2. [Demo 1: deleted is not cleaned up](demos/1-deleted-is-not-cleaned/README.md)
3. [Demo 2: dry-run is not safe](demos/2-dry-run-is-not-safe/README.md)
4. [Demo 3: a stubbed test proves only your assumption](demos/3-stub-proves-assumption/README.md)

Tear everything down and check that nothing remains:

```powershell
pwsh -NoProfile -File ./scripts/Stop-DemoRun.ps1; $LASTEXITCODE
```

Process exit code: 0 on success, 1 on failure (run them with `pwsh -File` as above so the code is real). After `Stop-DemoRun.ps1`, a non-zero exit code means
something is left in the subscription: read the output before leaving the room. Pass `-RunId` to tear
down a run whose `out/run.json` is gone.

## Cost

The cost guard in `lib/CostGuard.ps1` prices the run from the Azure Retail Prices API before anything is
created, and refuses to continue above the per-run limit of 2 EUR. Its live estimate on 2026-10-31 for
`swedencentral` and 2 hours:

| Item | Approx. EUR |
| --- | --- |
| VM Standard_B1s | 0.02 |
| OS disk E4 | 0.01 |
| Storage | 0.00 |
| Log Analytics, 0.1 GB | 0.26 |
| Total | 0.28794 |

The Log Analytics figure ignores the free 5 GB tier on purpose (conservative). Prices change; the guard reads them again on every run.

## Tests and CI

```powershell
Invoke-Pester ./tests -Output Detailed
```

CI runs `./tests`, PSScriptAnalyzer and the public-content check. The suites under `demos/` are excluded on
purpose: the on-stage suites of demos 2 and 3 are shown live, and demo 2 is meant to fail red.

Enable the pre-push public-content check with `git config core.hooksPath .githooks`.

## Safety

- Nothing is deleted outside the run's resource group.
- Teardown stops on any lookup error instead of guessing that something is gone.
- Output masks the subscription id. `out/run.json` holds raw ids and is gitignored.

## More

The full ownership audit and dry-run gate live in [SkyCraft](https://github.com/mbiszczanik/skycraft).

## License

MIT, see [LICENSE](LICENSE).
