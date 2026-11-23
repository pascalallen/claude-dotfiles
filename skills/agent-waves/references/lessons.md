# Lessons behind the procedure

Each line is a rule and what happened without it, from one build of several hundred agent-written PRs.

## Cost
- Cost is input re-reading: context size times turns. A hub left uncleared reached 500-800k tokens and spent the weekly limit; output was under 1% of the bill.
- An agent launched without a model runs on the session's. Sixty-five subagents did.
- A fork re-reads the hub's whole context (200-340k each). Fresh agents read a brief.
- Writers ran 80-350k tokens, reviewers 30-90k. One continued writer reached 309k: continue only for small fixes.
- Deterministic work (harvesting, counting, cross-checking) is a script. Agents doing it burned the budget and still needed a rerun.

## Agents
- Removing a worktree makes its agent unresumable.
- A restart wipes the session scratchpad; a round's briefs and scripts were lost that way.
- Two writers sharing a scratch file overwrote each other's PR body.
- Several hub sessions at once collided on migration numbers and merge order.
- Small "wait until merged" agents return early; a background loop does not.
- A waiter built on `pgrep -f <name>` matched its own command line and never started the queue. Wait on a PID.
- A hub that queued a PR and ended its turn with nothing armed sat idle 30-40 minutes, three times in one round, until the owner asked. The runner's output wakes nobody; `landq.sh wait` in the background does.
- One-line `while ...; done` waiters typed into a zsh tool shell failed to parse twice. Waits live in scripts.
- Editing a script while a background run was executing it corrupted the run.
- After `/clear` or plan mode, agents were still running in worktrees the hub then touched.
- A writer near its token limit was asked for a redesign and patched the same mistake twice. A fix that is not small goes to a fresh writer on the same branch, after the old clean worktree is removed so the branch is free.

## Review
- Reviewers found real defects in more than half of the PRs they read, all with green suites. Cutting them to save tokens is the wrong saving.
- A writer's statement about what the spec says is often wrong; the reviewer checks it first.
- A reviewer without the diff file and worktree path reviewed nothing.
- One defect pattern found twice was in a dozen places. Sweep the class.
- A PR needed four fix passes; the rule since is two, then stop and report.
- Reviewer notes about the PR body were dropped until the hub applied them itself.
- A test that still passes with its guard removed is a defect; hand mutants find it.
- A reviewer's scratch copy kept the worktree's `.git` file, and one `git checkout` in it staged files in the writer's index. A reviewer works in a copy with no `.git` link.
- A property test hid defects behind a generator filter that dropped most documents, and another failed at a third of unlisted seeds because of a share-of-draws bar tuned to the pinned seed. Briefs for property tests forbid filters and such bars, ask for several seeds, and the reviewer writes its own generator and mutants.

## Landing
- A squash from a stale tree silently reverted two merged PRs. No squash, no `reset --soft`; `git diff --stat origin/main...HEAD` before every push.
- Sibling branches that each filled the same empty stub conflicted on every merge. Keep-both resolution dropped lines and pushed a broken merge.
- PRs merged while CI was pending, and on an older run than the head. Merge on the head commit only.
- Deleting a base branch closed its child PR. Delete after MERGED and only when nothing is stacked on it.
- A script's exit 0 was read as "merged" when it was not. Check the state.
- `| tail`, `;` chains and `grep` under `pipefail` hid failures.
- An empty `--body-file` blanked an epic's body. `test -s` first.
- Overlapping gate runs caused timeouts; the gate is synchronous and one at a time.
- After a failed landing, re-adding the PR was ignored because its line was already marked done.

## Verification
- Ticked checklists hid 53 unbuilt capabilities; a coverage script against the source catalog found them.
- A seeded fixture hid a bug that a first real user hit on an empty database.
- A bundle that threw at load passed unit tests and curl smoke; only a browser showed it.
- Local CI with a longer timeout and one retry hid failures that real CI showed.
- A newer local toolchain formatted differently from CI's and failed three landings.
- Machine sleep and load caused flaky landings: keep the machine awake, add again unchanged, read the log.
- Test databases and build cache filled the disk; worktrees outside `.dockerignore` made a 5 GB build context.
- With CI off, every writer and the land queue ran the same local CI script: they shared one test database, one smoke compose project and its ports, and one run's teardown removed another's containers. Give each run its own database, compose project and ports in `shared.md`, and make the script take them from the environment.
- With `REQUIRE_CI=0` the merge came straight after the push and GitHub answered "not mergeable" while it was still computing; `land.sh` now waits for the pushed head to report `MERGEABLE`.
- Writers cannot write files outside their worktree: PR bodies and notes go in the session scratchpad, logs written by a command may still land in the round dir.
- A screen PR waits for the hub's browser check after review, not before: a review fix would mean driving it twice. One throwaway worktree with the screen PRs merged onto the default branch covers several in one session.
- A PR passed two reviews and every test, and the measured run (an eval) showed it did not fix the case it was written for and made another worse. When a change has a measured acceptance gate (an eval, a benchmark), the hub runs it after the review passes and before the PR is queued; a failed gate is diagnosed before anyone patches again.

## Working with the owner
- An approach rejected in a closed PR was proposed again a week later. Read closed PRs first.
- A large plan was built on an unconfirmed scope assumption and deleted.
- "Blocked" labels were stale; ten items were answerable from data already on disk.
- A merge grant covers what it named. A blocked merge is reported, not worked around.
- A process question asked again gets one line, not a re-explanation.
- Prose rules that a default overrides (commit trailers) need a setting or a hook.
