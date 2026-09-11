---
name: claude-code-repo-setup
description: Add or refresh Claude Code configuration in a repository — project CLAUDE.md (<200 lines, commands + conventions + gotchas), committed .claude/settings.json with permissions and gofmt/prettier hooks, path-scoped .claude/rules/, the project `verify` skill, and GitHub Actions CI + claude-code-action workflows — using the canonical files in this repo's claude-code/ directory. Use when a repo lacks .claude/settings.json or CI, when CLAUDE.md is stale, or when asked to make a repo Claude-Code-ready.
---

# Claude Code Repo Setup

Make a target repo Claude-Code-ready by copying the canonical kit in this
repo's `claude-code/` directory — don't hand-write these files from memory,
they drift the same way scaffold skills do (see ADR 0001).

## Copy the kit

Run from the target repo's root:

```bash
mkdir -p .claude/rules .claude/skills/verify .github/workflows

cp ~/code/claude-dotfiles/claude-code/settings.json .claude/settings.json
cp ~/code/claude-dotfiles/claude-code/rules/go.md .claude/rules/go.md
cp ~/code/claude-dotfiles/claude-code/rules/frontend.md .claude/rules/frontend.md
cp ~/code/claude-dotfiles/claude-code/skills/verify/SKILL.md .claude/skills/verify/SKILL.md
cp ~/code/claude-dotfiles/claude-code/workflows/ci.yml .github/workflows/ci.yml
cp ~/code/claude-dotfiles/claude-code/workflows/claude.yml .github/workflows/claude.yml
cp ~/code/claude-dotfiles/claude-code/workflows/claude-review.yml .github/workflows/claude-review.yml
```

## Adapt to the target repo

- **No frontend** (no `web/app/`): delete `.claude/rules/frontend.md`, drop the
  `yarn` job from `ci.yml`, and drop the prettier `PostToolUse` hook entry from
  `settings.json` (keep the gofmt one).
- **Frontend lives somewhere other than `web/app`**: edit the `paths:`
  frontmatter in `rules/frontend.md`, the `working-directory` /
  `cache-dependency-path` in `ci.yml`'s `yarn` job, and the path glob in the
  prettier hook's `case` pattern.
- **Non-Go backend**: drop `rules/go.md` and the `go` job in `ci.yml`; adapt
  `verify/SKILL.md`'s Go gate to the language's build/lint/test commands.
- **Project-specific gates**: fill in `verify/SKILL.md`'s `## Project-specific
  checks` section with anything this repo's gate needs beyond the standard Go
  and frontend gates (a wire regeneration reminder, a manual e2e recipe,
  etc.) — that section is the slot for it; don't improvise a location
  elsewhere in the file.

## Project CLAUDE.md checklist

Keep it **under 200 lines** — this is a hard budget, not a suggestion (see the
global CLAUDE.md's "Claude Code Repo Conventions"). Include:
- Exact build/test/run commands (copy-pasteable, not paraphrased).
- Architecture pointers that are **not derivable by reading the code** —
  layering decisions, why a convention diverges from the obvious default.
- The verification gates that must be green before claiming work done.
- Any end-to-end verification recipe (seed data, external dependency, expected
  output) that a test suite alone can't prove.
- Repo-specific gotchas (the kind of thing this task's own brief records for
  `new-react-app` — runtime-config timing, gin static fallthrough, etc.).
- `@path` imports are fine for pulling in `README.md` or a docs file — they
  still count against the loaded content, just not against hand-typed lines.

## `.gitignore` entries

Confirm these are present (add any missing):

```
.claude/settings.local.json
.claude/worktrees/
.mcp.json
.superpowers/
CLAUDE.local.md
```

**Frontend repos** (`web/app/` present): also create a **tracked** (not
gitignored) `web/go.mod` — module `<module>/web`, `go <version>`, no Go code,
just a boundary marker with a comment explaining why it's there. Without it,
`go build/vet/test/list ./...` run from the repo root descends into
`web/app/node_modules`, which ships stray `.go` files from vendored
dependencies; the separate module stops the Go toolchain's `./...` expansion
at the `web/` boundary. `gofmt` doesn't respect module boundaries, so its
gates still target `cmd internal` explicitly regardless of `web/go.mod` — see
the `new-react-app` skill's `references/config-notes.md`, § Go serving
gotchas, for the same note from the frontend-scaffold side.

## Repository secret

Both `claude.yml` and `claude-review.yml` need an `ANTHROPIC_API_KEY`
repository secret (Settings → Secrets and variables → Actions) — note this to
the user; this skill cannot set the secret itself.

## Verify

```bash
claude --version
```
Then in a session: `/context` shows `.claude/settings.json`, the copied rules,
and CLAUDE.md under **Memory files**; `/hooks` lists the gofmt (and, if kept,
prettier) `PostToolUse` hooks; and the `verify` skill runs and reports green.
Don't consider the setup done until all three check out.
