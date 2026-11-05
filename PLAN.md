# Demo kit burndown to D

Deadline: by D-5, every open item in this repository is closed with evidence or parked with a recorded decision, the demo kit has had one full run on current `main`, and the backup recordings (due D-2) have passed the identifier check. Check that can fail: `gh issue list --state open` at D-5 lists only issues that carry a comment with a reason and a class. Module C has its own deadline, D+12. D is the first delivery of the talk; its date stays out of this public repository.

Source: `gh issue list --state open` on the day the plan was written, D-14 (4 issues: #1, #3, #4, #10; 0 open pull requests). Statuses were checked against `origin/main` at `bc8561c`; re-read each issue before acting.

Unit of a block: one run that collects every gap, one pull request for the gaps of the first class, one confirming run. A new gap found by a confirming run is filed, not fixed in the same block.

Ownership check: another session edited #1 on the day the plan was written (it added the section "AI role per story" and changed an open question). The talk's decks and notes live in a private repository worked on by another session. Nine merged feature branches still exist as local worktrees and remote branches. Ask which session owns #1 before editing it.

First class of gap = blocks the presenter at D-5. Second = blocks only the maintainer's tooling. Third = blocks nobody yet.

## Exit criteria per issue

- When an issue's work is merged and every live item of it ran on the pull request branch, the pull request shall close it (`Closes #N`) with command, exit code and date.
- If a live item is still owed, then the pull request shall use `Refs #N`, and the issue shall stay open until a dated run closes it by hand.
- If an issue cannot be verified before D-5, then it shall carry a comment with the reason and its class.
- If a confirming run finds a new gap, then the executor shall file it as an issue and shall not fix it in the same block.
- While a block runs, the executor shall fix only first-class gaps; gaps of the other classes wait in the tracker for the user to schedule.
- If #1 was edited by another session after the executor's last read, then the executor shall re-read it before editing and ask which session owns it.

## Classification (Block 0 result)

| Issue | Plain meaning | Class | Where it goes |
| --- | --- | --- | --- |
| #1 | the specification of the talk and the demo kit | open, three questions only the author can answer; another session edited it | Block 1 (decisions) |
| #3 | gate demo, module A demo and rule wording | fixed in code and merged; owed: backup recordings (author) and a final run before each delivery | Blocks 2, 4, 5 |
| #4 | repository integrity follow-ups | four follow-ups open: orphaned diagnostic setting after an interrupted demo 1 (third class), `run.json` from another run (third), the broad `BadRequest` pattern (second), the VM extension error text (third) | parked unless the user schedules them |
| #10 | module C demo: reproduce platform behaviour in an own lab | candidate 1 merged (demo 6); candidate 2 (PSRule) needs a run; candidate 3 stays a story slide; recording owed | after D, deadline D+12 |

No issue is fixed-and-stale: none can be closed now.

## Block 0, D-14: status sweep (read-only)

- [x] Re-read #1, #3, #4, #10 and the open pull requests; classify each.
- [x] Find nothing to close as stale.
- [x] Ask the user which session owns #1: none, the executor owns it (2026-11-04).

## Block 1, D-14 to D-13: decisions (the user's)

No agent work. Evidence: a comment on each issue that records the decision.

- [x] #1 open question (decided: stays "two live Azure demos"): the goal stays "two live Azure demos" or becomes "two live demos, at least one in Azure".
- [x] #1 (confirmed by the speaker): confirm or correct the speaker's statement for the five stories the "AI role per story" section marks as undocumented (#128, #252, #472, #109, #384).
- [x] #1: SkyCraft #188 stays withdrawn (parked).
- [x] #4: scheduled before Block 2; offline part in PR #17, comment on #4.
- [x] Say yes to the live run of Block 2: given 2026-11-04, after PR #17 was prepared.

## Block 2, D-12 to D-10 (run early, 2026-11-04): one live run of the whole on-stage sequence

Evidence: dated run, every command with its exit code taken from the process, counts, in `docs/live-run-log.md`.

- [x] Run 1 collected the gaps: setup, rogue VM, demos 0, 1, 3 and 5 and the teardown (run `202611041553`, output recorded, process exit codes not evidenced). It also found that an orphaned diagnostic setting cannot be listed while its account is gone.
- [x] One pull request for the first-class gaps: PR #17, merged as `4c73f01` (teardown recreates a missing account, foreign `run.json`, narrower `BadRequest`); #4 closed by hand with the evidence.
- [x] Confirming runs with real exit codes: runs `202611041652` (found the listing lag) and `202611041708` (teardown exit 0, `Removed 1`, 0 groups, 0 tagged resources); local demos 2, 4 and 6 on `4c73f01` (PR #18 records them).
- [x] Every other gap recorded: the ownership audit group-name case stays as Azure spells it (decision recorded on #4).
- [x] The whole sequence in Azure on `04b51f8` as one run with process exit codes (run `202611041758`, 2026-11-04: all steps 0 except the two ownership audits, 1 by design; nothing left afterwards). Recorded in PR "docs: record the full Azure run on main".

## Audit findings of 2026-11-05 (#19, #20, #21): offline fixes, done early

Evidence: full suite exit code and green CI run ids in each pull request.

- [x] #19 CI accepts Pester container and discovery failures: PR #23 merged (`872f036`), closed by it.
- [x] #20 teardown may delete the SSH keys of another run: PR #24 merged (`d72e9b2`), `Refs #20`; issue open, a live teardown with a foreign record is optional and owed.
- [x] #21 demo 1 preparation does not fail when the leftover setting is absent: PR #25 merged (`99fa8fd`), `Refs #21`; issue open, the live preparation check (`-Step Verify` after `Recreate`) is owed and needs the user's yes.

## Block 3, D-9 to D-6: decks and notes (not this repository)

Another session works on them in the private repository. Dependency only: the core deck and the module A deck are ready for rehearsal at D-5.

## Block 4, D-5 to D-3: rehearsal on the author's own screen

Evidence: a dated block in `docs/live-run-log.md` from the author's run.

- [ ] The author runs the sequence once on the screen used on stage.
- [ ] Anything that fails becomes an issue with its class.

## Block 5, D-2 to D: recordings and the last check

- [ ] The author records demos 0, 1, 4, 5 and 6 and checks each frame for subscription id, tenant, account name and local path (#3).
- [ ] One final live run shortly before delivery (#3).
- [x] The merged worktrees and branches of PRs #23 to #25 are removed (2026-11-05). Still to remove at close-out: `log-full-run` after PR #22 merges, and `burndown` with this file.

## Block 6, D to D+1: close-out

- [ ] Close each issue with evidence, or record the parked decision.
- [ ] File the remaining gaps as issues.
- [ ] Delete this file in the last commit of the pull request that closes the plan.

## Beyond D, D+1 to D+12: module C

Evidence: dated run, command, exit code; an offline test in CI.

- [ ] Candidate 2 (PSRule): install `PSRule` and `PSRule.Rules.Azure`, run on the sample template, learn what `Assert-PSRule` does when an object is not processed; build the demo only if the result is a gap a gate would miss (#10).
- [ ] Backup recording of demo 6 and of any candidate 2 demo, after an identifier check (#10).
- [x] The four follow-ups of #4: done in PR #17 and #4 closed (2026-11-04).

## Needs the user

- Nothing from Block 1: decided 2026-11-04 (executor owns #1; goal stays two live Azure demos; five stories confirmed; #188 parked; #4 scheduled and closed; live run approved and done).
- A decision on merging the PR that records run `202611041758` in the log.
- Rehearsal on the author's screen, the backup recordings and the decks (Blocks 3 to 5).
- A yes to one live preparation run for #21 (`-Step Delete`, `Recreate`, `Verify`, then the teardown; about 0.29 EUR) and, in the same run, the optional foreign-record check for #20. Both issues stay open until a dated run is recorded.
- Not in this repository: the repository secret `GNP_DENY_LIST` and the topics (not verified), the `azure` remote with an embedded credential in a local clone of the course repository (remove it and reset the publishing credentials), and the old revision of #10 in its edit history (delete it by hand).

## Risks

- A cached Azure sign-in expired earlier in this work; a role assignment through the PowerShell cmdlet needed a Microsoft Graph sign-in the session did not have. Run `Get-AzContext` and confirm the demo subscription before each live block.
- Activity Log entries appeared up to 4 minutes after an operation; do not read an early empty query as "no entry".
- One live run is about 15 minutes of Azure time plus teardown; the VM extension step alone took 37 s in the last run.
- D-5 is nine days after the plan was written; Block 3 belongs to another session and can slip without this plan seeing it.

Maintainer of the checkboxes: the session that does the work ticks them in the same commit; the tracker page is republished from them.
