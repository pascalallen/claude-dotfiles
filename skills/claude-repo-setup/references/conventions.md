# Per-repo setup conventions

Authoritative over the reference repo when the two differ.

## Settings (`.claude/settings.json`, committed)

- `permissions.allow`: the repo's own verify loop and read-only git and GitHub commands, in the space form (`Bash(go test *)`). No bare `Bash(git push *)`, `Bash(gh api *)` or `Bash(env)`.
- `permissions.deny`: `Read(**/.env)`, `Read(**/.env.local)`, `Edit(**/<generated file>)` for every generated file (`wire_gen.go`, swagger output).
- One PostToolUse hook on `Edit|Write` that formats the touched file and can never block (always exits 0).
- A grant to merge (`Bash(gh pr merge *)`) is the owner's to add, in `settings.local.json`, for the round it covers.

## Rules (`.claude/rules/*.md`)

- One file per area with `paths:` frontmatter so it loads only there; a nested `CLAUDE.md` is the alternative for a single directory.
- A rule states what to do and names the file to copy; it does not explain the pattern.

## Verify skill

- Mirrors CI exactly: same steps, order, flags and toolchain version. A looser local run (longer timeout, a retry) hides what CI will show.
- `allowed-tools` lists just the commands it runs. It stops at the first failure and reports a pass/fail table.
- When CI changes, the skill changes in the same PR.

## Agents

- An implementer (worktree, opens the PR, never merges) and a read-only refute-by-default reviewer; a domain evaluator where behaviour is not unit-testable.
- `model` is set on each definition or at launch, never left to inherit by accident.
- Frontmatter fields that exist: `name`, `description`, `tools`, `model`, `effort`, `isolation: worktree`, `skills`, `maxTurns`. Unknown fields are ignored without an error, so check spelling.

## Docs

- `GLOSSARY.md` is the name the mattpocock skills read. An older repo's `CONTEXT.md` keeps working for people but not for those skills; rename it when the repo is next reworked.
- `REVIEW.md` is read by the managed GitHub code review and by the project's reviewer agent. The local `/code-review` command reads `CLAUDE.md` only, so `CLAUDE.md` points to `REVIEW.md`.
- Status lives in the epic issue and `docs/build-log.md`. `CLAUDE.md` and `ROADMAP.md` carry none.

## Git and Docker

- Ignored: `.claude/settings.local.json`, `CLAUDE.local.md`, `.claude/worktrees/`, `.agents/`.
- `.dockerignore` excludes `.claude/` and `.agents/`: worktrees inside the build context have produced multi-gigabyte contexts.
- Test databases are named per round and item and dropped at the end of the round.
