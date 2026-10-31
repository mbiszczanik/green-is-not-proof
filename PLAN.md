# Green is not proof: demo kit and talk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the live Azure demo kit for the talk "Green is not proof" in this repository, then the Polish decks and handouts for the three deliveries (Kraków 2026-11-18, technical university 2026-11-25, Łódź 2026-12-02).

**Architecture:** PowerShell 7 scripts on Az PowerShell. Pure logic (masking, cost estimate, ownership diff, syntax-tree guard check) lives in `lib/` and is unit-tested offline with Pester; thin scripts in `scripts/` and `demos/` call Az and are proven by one live run per branch. Decks and handouts are produced outside the repository, in the speaker's private Drive folder `Technical/Green-is-not-proof`.

**Tech Stack:** PowerShell 7.6, Pester 5.5-5.99, PSScriptAnalyzer, Az PowerShell (Az.Accounts, Az.Resources, Az.Storage, Az.Monitor, Az.OperationalInsights, Az.Network, Az.Compute), Azure Retail Prices API, GitHub Actions, PowerPoint/Word.

**Spec:** issue #1 in this repository (talk core, variants, deliverables, acceptance criteria).

## Global Constraints

- Repository content in English; decks, speaker notes and the handout cheat sheet in Polish with everyday English industry terms.
- Title "Green is not proof"; subtitle "Pułapki weryfikacji w Azure i jak je wyłapać".
- Total demo budget EUR 20 (rehearsals, recordings, three deliveries); one run at most EUR 2, assuming a run lasts 2 hours.
- Every demo resource lives in one resource group `rg-gnp-<runId>` with tags `project = green-is-not-proof` and `runId = <runId>`; nothing persists between runs.
- No identifier in tracked files, commits, PR text or recordings: no e-mail address, tenant or subscription name or id, object id of a real environment, real person's name, local path with a user name. Placeholders: `<subscription-id>`, `<tenant>`.
- Output of every demo script masks the subscription id: `/subscriptions/<sub>/...`.
- No AI-tool attribution in files, commits or PR text.
- No deployment, teardown or setting change in the live subscription without the speaker's request in that session, preceded by a resource and cost table.
- Slides: body text at least 24 pt, code at least 18 pt, one idea per slide, at most 7 lines, nothing key in the bottom quarter, repository URL on the title slide.
- Pester exit code is decided explicitly in CI (`$Host.SetShouldExit(1); exit 1` on failure or on a null result), following SkyCraft's `lint.yml`.

## Review Focus

1. Teardown on a run whose setup failed halfway (no workspace, no diagnostic setting yet): teardown must still delete what exists and not report success on a resource group that remains. Test: Task 5, `Stop-DemoRun on partial run`.
2. Retail Prices API unreachable or returning no item for a SKU: the cost guard must stop setup, not treat a missing price as 0. Test: Task 3, `missing price stops the run`.
3. Subscription id appearing in a non-resource-id string (an error message, a URL): masking must catch any GUID that equals the current subscription id, not only the `/subscriptions/` prefix. Test: Task 2, `masks a bare subscription id`.
4. A dry-run guard written as an early `return` or a negated `if (-not $WhatIfPreference)`: the syntax-tree check must accept these as guarded, or the demo shows a false red. Test: Task 8, `accepts early return guard` and `accepts negated else guard`.
5. Ownership audit with zero resources returned (list call failed or wrong scope): it must stop with an error, not report "all owned". Test: Task 6, `empty inventory is an error`.

---

### Task 1: Repository scaffold, CI and public-content check

**Files:**
- Create: `tools/Test-PublicContent.ps1`, `tests/Test-PublicContent.Tests.ps1`, `.github/workflows/ci.yml`, `.githooks/pre-push`, `PSScriptAnalyzerSettings.psd1`, `.gitignore`
- Modify: `README.md` (one paragraph placeholder, filled in Task 10)

**Interfaces:**
- Produces: `tools/Test-PublicContent.ps1 -Path <string[]> [-DenyListPath <string>]` exits 1 and prints `file:line: <kind>` per hit; exits 0 with `public-content: clean (<n> files)`. Built-in Azure role/definition GUIDs are allowed through `tools/public-content-allow.txt`. The deny list (tenant and organisation names) is read from a local, untracked file (default `~/.config/green-is-not-proof/deny.txt`); if that file is missing the script prints a warning and still checks e-mails and GUIDs.

- [ ] **Step 1: Write failing tests** in `tests/Test-PublicContent.Tests.ps1`: `flags an e-mail address` (file with `a.b@example.org`, exit 1); `flags a GUID` (`1b2c3d4e-0000-4000-8000-123456789abc`, exit 1); `allows a listed built-in GUID` (`acdd72a7-3385-48ef-bd42-f606fba81ae7`, Reader role, exit 0); `flags a deny-list term` (deny file with `contoso`, text `Contoso tenant`, case-insensitive, exit 1); `reports clean on empty repo` (exit 0, output contains `clean`); `fails when a path does not exist` (exit 1, not 0).
- [ ] **Step 2: Run** `pwsh -c "Invoke-Pester ./tests -Output Detailed"`. Expected: FAIL, script not found.
- [ ] **Step 3: Implement** `tools/Test-PublicContent.ps1` (regex: e-mail `[\w.+-]+@[\w-]+\.[\w.-]+`, GUID `[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}`), `.githooks/pre-push` running it over `git ls-files`, CI job with Pester + PSScriptAnalyzer + public-content over tracked files and the explicit exit guard. `.gitignore`: `*.local.*`, `out/`, `recordings/raw/`.
- [ ] **Step 4: Run** tests; Expected: PASS (6). Run `pwsh ./tools/Test-PublicContent.ps1 -Path (git ls-files)`; Expected: `public-content: clean`.
- [ ] **Step 5: Commit** `ci: add public-content check, Pester and analyzer CI`. Push, open a draft PR with `Refs #1`, confirm the CI run is green and record its run id in the PR.

### Task 2: Run context and id masking

**Files:**
- Create: `lib/RunContext.ps1`, `lib/Mask.ps1`, `tests/RunContext.Tests.ps1`, `tests/Mask.Tests.ps1`

**Interfaces:**
- Produces: `New-DemoRunId([datetime]$Now = (Get-Date)) -> string` format `yyyyMMddHHmm`; `Get-DemoResourceGroupName([string]$RunId) -> string` = `rg-gnp-$RunId`; `Get-DemoTag([string]$RunId) -> hashtable` = `@{ project = 'green-is-not-proof'; runId = $RunId }`; `ConvertTo-MaskedText([string]$Text, [string]$SubscriptionId) -> string` replaces every occurrence of `$SubscriptionId` (case-insensitive) with `<sub>`; `Write-DemoOutput([object]$InputObject, [string]$SubscriptionId)` formats the object as table text and writes it masked.

- [ ] **Step 1: Write failing tests**: `run id from fixed date` (`2026-11-18 18:05` -> `202611181805`); `resource group name` (`rg-gnp-202611181805`); `tags carry project and runId`; `masks resource id` (`/subscriptions/1b2c...abc/resourceGroups/x` -> `/subscriptions/<sub>/resourceGroups/x`); `masks a bare subscription id` (inside an error message); `masks upper-case form`; `leaves other GUIDs` (a different GUID unchanged).
- [ ] **Step 2: Run** tests; Expected: FAIL.
- [ ] **Step 3: Implement** both files; `ConvertTo-MaskedText` uses `[regex]::Escape` with `IgnoreCase`.
- [ ] **Step 4: Run** tests; Expected: PASS (7).
- [ ] **Step 5: Commit** `feat: add run context and subscription id masking`.

### Task 3: Cost guard

**Files:**
- Create: `lib/CostGuard.ps1`, `config/demo-resources.psd1`, `tests/CostGuard.Tests.ps1`

**Interfaces:**
- Consumes: none.
- Produces: `config/demo-resources.psd1` lists the run's priced items as `@{ Name; ServiceName; ArmSkuName; MeterName; Quantity; Unit = 'Hour' }` (VM `Standard_B1s` plus its OS disk, public IP Standard, storage account LRS hot, Log Analytics pay-as-you-go per GB with Quantity 0.1). `Get-RetailPrice([hashtable]$Item, [string]$Region, [scriptblock]$Fetch = $DefaultFetch) -> decimal` (EUR, from `https://prices.azure.com/api/retail/prices?currencyCode='EUR'&$filter=...`, `type eq 'Consumption'`). `Get-DemoRunCostEstimate([hashtable[]]$Items, [string]$Region, [decimal]$Hours = 2, [scriptblock]$Fetch) -> pscustomobject @{ TotalEur; Lines; PriceDate }`. `Assert-DemoRunBudget([pscustomobject]$Estimate, [decimal]$LimitEur = 2)` throws `Run estimate <x> EUR exceeds limit <y> EUR`.

- [ ] **Step 1: Write failing tests** with a fake `$Fetch`: `sums hourly items over hours` (VM 0.01/h x 2 h + IP 0.005/h x 2 h = 0.03); `per-GB item uses quantity` ; `missing price stops the run` (fetch returns no item -> throws `No retail price for <Name>`); `fetch failure stops the run` (fetch throws -> rethrows, no estimate); `budget over limit throws`; `budget under limit passes`; `estimate carries price date` (today, `yyyy-MM-dd`).
- [ ] **Step 2: Run** tests; Expected: FAIL.
- [ ] **Step 3: Implement**; the default fetch follows `NextPageLink` until null.
- [ ] **Step 4: Run** tests; Expected: PASS (7). Run once live (read-only, no subscription needed): `pwsh -c ". ./lib/CostGuard.ps1; Get-DemoRunCostEstimate -Items (Import-PowerShellDataFile ./config/demo-resources.psd1).Items -Region swedencentral"`; Expected: a total under 2 EUR with a price date; paste the table into the PR.
- [ ] **Step 5: Commit** `feat: add retail-price cost guard`.

### Task 4: Setup script

**Files:**
- Create: `scripts/Start-DemoRun.ps1`, `config/demo-manifest.psd1`, `tests/Start-DemoRun.Tests.ps1`

**Interfaces:**
- Consumes: Task 2 (`New-DemoRunId`, `Get-DemoResourceGroupName`, `Get-DemoTag`, `Write-DemoOutput`), Task 3 (`Get-DemoRunCostEstimate`, `Assert-DemoRunBudget`).
- Produces: `scripts/Start-DemoRun.ps1 [-Location swedencentral] [-RunId <string>] -> writes out/run.json` with `@{ RunId; ResourceGroup; StorageAccountName; WorkspaceId; VnetName; RogueVmName; Location }`. Creates, in order: resource group with tags; Log Analytics workspace `log-gnp-<runId>`; storage account `stgnp<runId>` with a diagnostic setting `diag-to-log` on its blob service; VNet `vnet-gnp` with subnet `snet-app`; the code-declared resources listed in `config/demo-manifest.psd1`; and the rogue VM `vm-traffic` (`Standard_B1s`, no public IP, NIC in `snet-app`) carrying the same tags but absent from the manifest.

- [ ] **Step 1: Write failing tests** (all Az cmdlets mocked): `cost guard runs before any New-Az call` (assert call order); `over-budget estimate creates nothing` (`New-AzResourceGroup` invoked 0 times, exit 1); `every New-Az call carries the run tags`; `run.json holds raw ids while console output is masked`.
- [ ] **Step 2: Run** tests; Expected: FAIL.
- [ ] **Step 3: Implement**; `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, explicit `exit 1` with `$Host.SetShouldExit(1)` on any failure.
- [ ] **Step 4: Run** tests; Expected: PASS (4).
- [ ] **Step 5: Commit** `feat: add demo run setup`.

### Task 5: Teardown script

**Files:**
- Create: `lib/DiagnosticSettings.ps1`, `scripts/Stop-DemoRun.ps1`, `tests/DiagnosticSettings.Tests.ps1`, `tests/Stop-DemoRun.Tests.ps1`

**Interfaces:**
- Consumes: Task 2, `out/run.json` from Task 4.
- Produces: `Remove-DemoDiagnosticSetting([string]$ResourceId) -> int` (count removed; throws on list or remove failure); `scripts/Stop-DemoRun.ps1 [-RunId <string>]` removes diagnostic settings on every resource in the group that supports them, deletes the group, then queries `Get-AzResource -TagName runId -TagValue $RunId` and exits 1 if anything remains.

- [ ] **Step 1: Write failing tests**: `removes every setting whatever its name` (two settings, one hand-made name); `list failure throws and leaves resource` (`Remove-AzResourceGroup` not called); `remove failure throws`; `Stop-DemoRun on partial run` (no workspace, no setting: group still deleted, exit 0 when nothing remains); `leftover tagged resource fails` (post-check returns one item -> exit 1, item masked in output).
- [ ] **Step 2: Run** tests; Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** tests; Expected: PASS (5).
- [ ] **Step 5: Commit** `feat: add teardown that removes non-cascaded diagnostic settings`.

### Task 6: Demo 0, a tag is not proof of ownership

**Files:**
- Create: `lib/Ownership.ps1`, `demos/0-tag-is-not-ownership/Invoke-TagAudit.ps1`, `demos/0-tag-is-not-ownership/Invoke-OwnershipAudit.ps1`, `demos/0-tag-is-not-ownership/README.md`, `tests/Ownership.Tests.ps1`

**Interfaces:**
- Consumes: Task 2, `out/run.json`, `config/demo-manifest.psd1` (Task 4: `@{ Names = @(...) }`, every resource name the code creates, rogue VM excluded).
- Produces: `Find-UnownedResource([object[]]$Inventory, [string[]]$ExpectedName) -> object[]` (each item with `Name`, `ResourceType`, `Id`); throws `Empty inventory` when `$Inventory` is empty. `Invoke-TagAudit.ps1` lists resources with the run tags and prints `All <n> resources carry project tags: OK` (the green). `Invoke-OwnershipAudit.ps1` compares the group's inventory with names from `config/demo-manifest.psd1` and exits 1 listing `vm-traffic` and its NIC and OS disk.

- [ ] **Step 1: Write failing tests**: `flags a tagged resource absent from the manifest`; `owned resources are not flagged` (case-insensitive names); `child resources of a flagged VM are flagged` (NIC, disk named after it); `empty inventory is an error`.
- [ ] **Step 2: Run** tests; Expected: FAIL.
- [ ] **Step 3: Implement**; README gives the on-stage sequence (tag audit green, ownership audit red, the rule).
- [ ] **Step 4: Run** tests; Expected: PASS (4).
- [ ] **Step 5: Commit** `feat: add demo 0 ownership audit`.

### Task 7: Demo 1, deleted is not cleaned up

**Files:**
- Create: `demos/1-deleted-is-not-cleaned/Show-DiagnosticSettingLeftover.ps1`, `demos/1-deleted-is-not-cleaned/README.md`, `tests/Show-DiagnosticSettingLeftover.Tests.ps1`

**Interfaces:**
- Consumes: Task 2, Task 5 (`Remove-DemoDiagnosticSetting`), `out/run.json`.
- Produces: script with steps `-Step Show | Delete | Recreate | List | Clean`, each printing one masked line, so the speaker advances on stage. `List` prints the setting that re-attached to the recreated account.

- [ ] **Step 1: Write failing tests** (mocked): `Delete reports success`; `List after Recreate shows the old setting name`; `Clean removes it and List shows none`; `every step masks ids`.
- [ ] **Step 2: Run** tests; Expected: FAIL.
- [ ] **Step 3: Implement**; README states the expected live result and that it is confirmed in Task 11.
- [ ] **Step 4: Run** tests; Expected: PASS (4).
- [ ] **Step 5: Commit** `feat: add demo 1 diagnostic setting leftover`.

### Task 8: Demo 2, dry-run is not safe

**Files:**
- Create: `lib/DryRunGuard.ps1`, `demos/2-dry-run-is-not-safe/Deploy-Example.ps1`, `demos/2-dry-run-is-not-safe/Deploy-Example.Fixed.ps1`, `demos/2-dry-run-is-not-safe/DryRun.Tests.ps1`, `demos/2-dry-run-is-not-safe/README.md`, `tests/DryRunGuard.Tests.ps1`

**Interfaces:**
- Produces: `Find-UnguardedMutation([string]$Path, [string[]]$MutatingVerb = @('New','Set','Remove','Register','Update','Start','Stop','Add','Install')) -> object[]` with `Line`, `Command`. Uses `[System.Management.Automation.Language.Parser]::ParseFile`; a `*-Az*` command with a mutating verb is guarded when an ancestor `if` tests `$DryRun`/`$WhatIfPreference` and the call sits in the non-dry branch, or an earlier statement in the same script block is `if ($DryRun) { return }` (or `exit`). `Deploy-Example.ps1` has `-DryRun` guarding `New-AzResourceGroupDeployment` but calls `Register-AzResourceProvider` outside it; the fixed version guards both. Neither script is ever executed.

- [ ] **Step 1: Write failing tests**: `flags register outside guard` (example script -> 1 hit, `Register-AzResourceProvider`); `fixed script is clean`; `accepts early return guard`; `accepts negated else guard`; `ignores read verbs` (`Get-AzResource` outside guard -> 0 hits).
- [ ] **Step 2: Run** tests; Expected: FAIL.
- [ ] **Step 3: Implement**; `DryRun.Tests.ps1` is the on-stage test (red on the example, green on the fixed one).
- [ ] **Step 4: Run** tests; Expected: PASS (5). Run `Invoke-Pester ./demos/2-dry-run-is-not-safe`; Expected: 1 failed (example), 1 passed (fixed).
- [ ] **Step 5: Commit** `feat: add demo 2 syntax-tree dry-run check`. Exclude the on-stage suite from CI (its red is intended); CI runs `tests/` only.

### Task 9: Demo 3, a stubbed test proves only your assumption

**Files:**
- Create: `demos/3-stub-proves-assumption/Test-WorkspaceHealth.ps1`, `demos/3-stub-proves-assumption/Health.Stubbed.Tests.ps1`, `demos/3-stub-proves-assumption/Show-LiveProperty.ps1`, `demos/3-stub-proves-assumption/README.md`

**Interfaces:**
- Consumes: Task 2, `out/run.json`.
- Produces: `Test-WorkspaceHealth([object]$Workspace) -> bool` (strict: demands a property value chosen in Step 1); the stubbed test passes with a hand-written object; `Show-LiveProperty.ps1` prints the same property from the live resource (`$null`).

- [ ] **Step 1: Pick the property by a live read** during Task 11's first run (read-only: `Get-AzOperationalInsightsWorkspace`, `Get-AzStorageAccount`, `Get-AzDiagnosticSetting`): a property a plausible health check would demand that the live object returns empty or absent. Record the command and its output (masked) in the README.
- [ ] **Step 2: Write** `Health.Stubbed.Tests.ps1` with the stub object; run it; Expected: PASS (the false green).
- [ ] **Step 3: Implement** `Test-WorkspaceHealth` and `Show-LiveProperty.ps1`; add a corrected `Test-WorkspaceHealth -Mode Lenient` that fails only on explicit `Failed`/`Deleting` states.
- [ ] **Step 4: Run** the stubbed suite (PASS) and `Show-LiveProperty.ps1` against a live run (property empty); paste both outputs in the PR.
- [ ] **Step 5: Commit** `feat: add demo 3 stub versus live property`.

### Task 10: README and English cheat sheet

**Files:**
- Modify: `README.md`
- Create: `docs/cheat-sheet.md`

- [ ] **Step 1: Write** README: what the talk is, prerequisites (PowerShell 7.6, Az modules from Task 11 Step 1, a test subscription), `Start-DemoRun` / demos 0-3 / `Stop-DemoRun` sequence, cost table from Task 3 with its price date, link to SkyCraft (`https://github.com/mbiszczanik/skycraft`) for the full audit and dry-run gate, the cheat sheet link.
- [ ] **Step 2: Write** `docs/cheat-sheet.md`: four rules, each "X is a declaration; Y is proof" with one command: tag vs code-derived inventory; delete success vs post-delete listing of non-cascaded children; dry-run switch vs syntax-tree test; stubbed test vs one live read.
- [ ] **Step 3: Run** `pwsh ./tools/Test-PublicContent.ps1 -Path (git ls-files)` and `npx markdownlint-cli2 "**/*.md" "#.worktrees"`; Expected: clean, 0 errors.
- [ ] **Step 4: Commit** `docs: add README and cheat sheet`.

### Task 11: Live verification on the branch (speaker approval required)

- [ ] **Step 1:** Install Az locally: `pwsh -c "Install-Module Az -Scope CurrentUser -Force"`; verify `Get-Module Az.Accounts -ListAvailable` returns a version.
- [ ] **Step 2:** Present to the speaker the resource table (every resource `Start-DemoRun` creates, with monthly and per-run price from Task 3 and its date, total) and ask approval for one run in the SkyCraft test subscription.
- [ ] **Step 3:** After approval: `Connect-AzAccount` by the speaker, then `./scripts/Start-DemoRun.ps1`, demos 0, 1, 3 live, demo 2 offline, `./scripts/Stop-DemoRun.ps1`. Expected: demo 0 audit red listing `vm-traffic`; demo 1 `List` shows the re-attached setting; teardown exit 0 and no `runId`-tagged resource left.
- [ ] **Step 4:** Record in the PR a `Live-verified:` line per demo with command, exit code, date (output masked). Mark the PR ready; `Closes #1` only if every acceptance criterion in #1 ran on this branch, else `Refs #1` with the owed items listed.
- [ ] **Step 5:** Delete `PLAN.md` in the PR's last commit; after merge, record remaining non-repo work (Tasks 12-16) as issues.

### Task 12: Backup recordings (by 2026-11-16)

- [ ] **Step 1:** In one approved run, record each live demo (0, 1, 3) and demo 2 at 1920x1080, terminal font at least 20 pt, browser zoom 125-150%, notifications off; AI agents prepare the shot list and the recording script per demo from the demo READMEs.
- [ ] **Step 2:** Check every frame for identifiers (Portal header, prompts, ids); record the check in `recordings/CHECKED.md` (file, date, result). Clean recordings go to the release assets of this repository; any doubt keeps the file in the private Drive folder only.
- [ ] **Step 3:** Copy all recordings to the presenting laptop's local disk; play each offline once.

### Task 13: Core and meetup deck plus speaker notes (by 2026-11-13)

- [ ] **Step 1:** Create `Green-is-not-proof-Meetup.pptx` in the private Drive folder from the style of the speaker's most recent Polish deck (Azure Verified Modules, PL, 2025-10-22). Sequence: title (with repo URL and QR) -> opener demo 0 -> one "O mnie" slide -> thesis and agenda -> stories 1-3 (each: zielone / naprawdę / jak wykryć / zasada) with two show-of-hands questions -> four rules -> QR codes (repo, feedback form) -> Q&A. About 30 slides for 45 min.
- [ ] **Step 2:** Story 3 names SkyCraft and states that its labs and tests were AI-written and a human Portal pass caught the drift; numbers only from the source notes, rechecked at build time.
- [ ] **Step 3:** Write `Green-is-not-proof-Opis.docx` (Polish): abstract for organisers, timing table, speaker notes per slide, fallback instructions per demo.
- [ ] **Step 4:** Speaker rehearses with a timer; adjust to 37 minutes plus 8 minutes Q&A.

### Task 14: Lecture deck, polls and quiz (by 2026-11-22)

- [ ] **Step 1:** `Green-is-not-proof-Wyklad.pptx`: block 1 reuses slides from the speaker's earlier decks "Azure Intro v2" and "Wirtualizacja" (cloud, virtualisation, regions, resource hierarchy, what a deployment is) in four ~10-minute chunks, each ending in a poll question; block 2 is the meetup core with a vote before each demo and the indicator-lamp versus measurement analogy.
- [ ] **Step 2:** `Green-is-not-proof-Pytania.docx`: 4 poll questions for block 1, one vote per demo in block 2, a 6-question closing quiz with answers; tool-agnostic.
- [ ] **Step 3:** Feedback form (Google Forms in the speaker's account) and its QR on the closing slide.

### Task 15: Polish cheat sheet and day-of checklist (by 2026-11-16)

- [ ] **Step 1:** `Green-is-not-proof-Sciaga.pdf`: one A4 page, the four rules in Polish with one command each, repo QR.
- [ ] **Step 2:** `Checklista-prelegenta.docx`: AV test 15 min before; `Start-DemoRun` about 1 h before (VM boot time) after connecting the account off-screen; recordings on local disk; notifications off; `Stop-DemoRun` right after the session with its exit code checked.

### Task 16: After Kraków and the lecture, Łódź revisions (by 2026-11-30)

- [ ] **Step 1:** Note timing, questions asked and demo issues after 2026-11-18 and 2026-11-25 in the issue tracking the Łódź delivery.
- [ ] **Step 2:** Update the meetup deck and notes; re-run Task 11 Step 3 if any demo script changed.
