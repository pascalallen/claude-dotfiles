# Round file shapes

Small shapes, not files to copy verbatim. `<id>` is the round, `<slug>` the item.

## `round.env`

```bash
VERIFY_CMD="bin/verify"          # same toolchain version and flags as CI
GATE_CMD="bin/post-merge-gate"   # empty when the project has none yet
REQUIRE_CI=1                     # 0 only while CI is off and VERIFY_CMD mirrors it
MERGE_METHOD=merge
```

## `shared.md` (under 15 lines)

```markdown
## Round <id> (issue #<epic>)
- Branch `feature/<epic>-<slug>` exactly. PR body says "Part of #<epic>".
- Toolchain: <the CI version and how to select it>.
- Scratch dir `.agents/rounds/<id>/<slug>/` in your own worktree. Test database `<app>_test_<id>_<slug>`.
- Live checks on the port in your brief, never the dev stack or its database. Test the empty database too.
- Append-only shared files: <list>. Add your own lines at the end; never reformat others.
- If a claim in your brief is wrong, say so. Prove a bug with a failing test before fixing it.
- Before you finish, write `.agents/rounds/<id>/<slug>/build-log.txt`: one sentence naming the PR, the evidence and the deviations.
```

## `brief-<slug>.md`

```markdown
# <slug> (#<epic> item <n>). Port <p>. <Backend | Frontend | Both>.
1. **<Behaviour to build>.** Evidence: <spec section, file:line, source-system reference>. Copy the shape of <nearest existing file>.
2. **<Second behaviour>.** ...

Rules that apply here: <tenancy, money, error mapping, the ones a sibling got wrong>.
Tests: <the cases that prove each point, including the failure cases>.
Live proof: <what to run against the real binary>.
Out: <what a follow-up will do>.
```

## `status.md`

```markdown
# <id> ledger (the hub reads only this). Plan: <path>. Epic #<n>.
slug | pr | state
wave1: a, b, c, d launched
wave1 done: 101 a queued; 102 b FIX (2 assertions), fix note fix-102.txt; 103 c merged
owner 2026-01-15: <decision in their words>
follow-ups: <one line each, with the issue number once filed>

== HANDOFF (hub at merge limit) ==
Merged: 101 103 104. Queued: 105. Runner: landq.sh status. Next port <p>.
NEXT, in order:
1. ...
Waiting on the owner: ...
Unexplained: <a failure that passed on retry, with the test name>
```
