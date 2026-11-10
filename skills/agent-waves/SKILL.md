---
name: agent-waves
description: Run a build as rolling waves of long-running writer and reviewer agents — brief files on disk, worktree writers, refute-by-default reviewers, a serial land queue with a post-merge gate, and a ledger with handoff blocks. Use when several independent checklist items (an epic, a phase, a backlog) should be built in parallel by agents and merged safely; not for a single item or a small edit, which is done inline.
---

# Agent waves

You are the orchestrator (the hub). You plan, write briefs, launch agents, read their short replies, queue PRs and keep the ledger. You do not read their transcripts or write their code. Rules already in the global `CLAUDE.md` (wave size, one item per agent, reviewers refute by default) are not repeated here; this is the procedure.

Shapes for the files named below: [references/templates.md](references/templates.md). The reasons behind each rule: [references/lessons.md](references/lessons.md), read it once per project.

## 1. Before the first wave

1. One hub session only. It owns merge order, migration numbers and shared files.
2. Create the round folder `.agents/rounds/<id>/` in the repo and make sure `.agents/` is git-ignored and in `.dockerignore`. Briefs, the ledger and logs live here, never in the session scratchpad: a restart wipes that.
3. Write `round.env` there: `VERIFY_CMD` (the repo's verify, same toolchain version and flags as CI), `GATE_CMD` (the post-merge gate, see 5), `REQUIRE_CI` (1 unless CI is switched off), `MERGE_METHOD`.
4. Write `shared.md`: the rules every agent in this round follows (branch pattern, toolchain pin, scratch dir and test database per item, ports, shared files that are append-only).
5. Check the land grant. Agents never merge. The land queue merges only when the owner has granted merging for this round; without that, run it with nothing queued and report PRs as ready.
6. Budget: one CI run costs minutes and each PR takes several; say the estimate before a burst.
7. Re-check every item marked blocked or done against its source before planning around it.

## 2. Briefs

One file per item, `brief-<slug>.md`. A writer trusts its brief over repo habit, so the brief states every rule that matters for the item: what to build, the evidence, the files to copy shape from, the tests that prove it, the live proof, what is out. Items are sized for under ~250k writer tokens. A tiny pattern copy is done inline, not by an agent.

Never let sibling branches grow the same new file from an empty stub: land the first PR that creates a shared file alone, then fan out.

## 3. Launch a wave

- Fresh agents from the project's writer definition, `isolation: worktree`, the model set on the launch, the prompt naming only the brief and `shared.md`. Never a fork of the hub.
- At most 4 writers. All launches in one message so they run together; waits run in the background and notify, never a foreground poll.
- A stacked PR gets a fresh writer. Continue a finished writer (SendMessage) only for a small fix, and keep its worktree until its PR is merged.
- After `/clear`, `/compact` or plan mode, list the running agents before touching any worktree.

## 4. Review

- Every PR that changes behaviour gets a reviewer: read-only, given the PR number, a diff file (`gh pr diff <n> > .agents/rounds/<id>/diff-<n>.patch`) and the worktree path. At most 2 at once.
- A defect goes back to the writer as a fix note file; the fix is a second plain commit, never a force-push. Re-review the fix.
- A repeated defect: have the writer sweep the whole class. After two fix passes, or when a new class of defect appears, stop and report to the owner.
- Apply the reviewer's `PR-BODY:` corrections to the PR body yourself.

## 5. Land

```bash
export ROUND_DIR="$PWD/.agents/rounds/<id>"
nohup "${CLAUDE_SKILL_DIR}/scripts/landq.sh" run >/dev/null 2>&1 &   # one runner per round
"${CLAUDE_SKILL_DIR}/scripts/landq.sh" add <pr> <worktree>
"${CLAUDE_SKILL_DIR}/scripts/landq.sh" status
```

The queue lands one PR at a time: merge the default branch into the PR branch, run `VERIFY_CMD`, push, wait for CI on that exact commit, merge with `--match-head-commit`, confirm the state is MERGED, delete the branch unless it is the base of an open PR, then run `GATE_CMD` before the next PR. A failed gate writes `STOP` and pauses the queue. Results are lines in `landq.out` (`MERGED`, `CONFLICT`, `VERIFY-FAILED`, `CI-FAILED`, `GATE-FAILED`); read that file, not the terminal.

- `CONFLICT`: the writer (or you, for append-only files) resolves it as the default branch's version plus the branch's own change. Never resolve by keeping both sides line by line.
- A failure with no code cause (machine load, sleep): read the log, then add the PR again unchanged.
- Do not edit a script or `round.env` while the runner is mid-item.

`GATE_CMD` is the project's own script: the default branch's build on its own port against a fresh, empty database, then the seed, a login per role, the browser smoke and any invariant queries (for a ledger: balanced). It must never touch the dev stack.

## 6. Ledger and handoff

`status.md` is the only thing the next session reads. After each wave: one line per item (slug, PR, state), owner decisions as dated lines, follow-ups found. Record each merged PR in the build log and tick the epic.

Stop and hand off at ~150k tokens of hub context or ~12 merged PRs, whichever comes first: write a `== HANDOFF ==` block (merged, queued, runner state, next steps in order, waiting on the owner, unexplained failures), update the one handoff memory entry to point at it, then `/clear`.

## 7. Stop rules

- Usage limit or 429: stop, write the handoff block, report. Do not switch models.
- A permission or classifier block: retry twice at most, then report. Never route around it.
- The gate fails: nothing else lands until the default branch is fixed.
- End of round: remove merged worktrees, drop the round's scratch databases, delete merged local branches.
