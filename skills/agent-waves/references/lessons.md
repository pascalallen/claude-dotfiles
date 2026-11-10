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
- Editing a script while a background run was executing it corrupted the run.
- After `/clear` or plan mode, agents were still running in worktrees the hub then touched.

## Review
- Reviewers found real defects in more than half of the PRs they read, all with green suites. Cutting them to save tokens is the wrong saving.
- A writer's statement about what the spec says is often wrong; the reviewer checks it first.
- A reviewer without the diff file and worktree path reviewed nothing.
- One defect pattern found twice was in a dozen places. Sweep the class.
- A PR needed four fix passes; the rule since is two, then stop and report.
- Reviewer notes about the PR body were dropped until the hub applied them itself.
- A test that still passes with its guard removed is a defect; hand mutants find it.

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

## Working with the owner
- An approach rejected in a closed PR was proposed again a week later. Read closed PRs first.
- A large plan was built on an unconfirmed scope assumption and deleted.
- "Blocked" labels were stale; ten items were answerable from data already on disk.
- A merge grant covers what it named. A blocked merge is reported, not worked around.
- A process question asked again gets one line, not a re-explanation.
- Prose rules that a default overrides (commit trailers) need a setting or a hook.
