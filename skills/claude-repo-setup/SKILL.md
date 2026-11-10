---
name: claude-repo-setup
description: Give a repository its Claude Code setup — committed settings with an allowlist, deny rules and a format hook, path-scoped rules, a verify skill that mirrors CI, writer and reviewer agents, glossary, ADRs, ROADMAP.md, REVIEW.md, build log, CI and PR templates — by copying from the living reference repo and adapting. Use right after scaffolding a new service, or when an existing repo lacks this setup or has drifted from it.
---

# Claude Code repo setup

The setup is copied from a living reference repo and adapted, never written from memory (ADR 0001). The reference is `$SETUP_REF`, named in `~/.claude/private-references.md`; it is private, so never name it in the target repo. What each file must contain, and why, is in [references/conventions.md](references/conventions.md); where the reference and the conventions differ, the conventions win.

## 1. Look first

```bash
ls -a .claude .github docs 2>/dev/null; cat CLAUDE.md .mcp.json 2>/dev/null | head -50
gh pr list --state closed --search "claude in:title" --limit 10
```

Keep what exists and is right. If a closed PR already tried part of this setup, read why it was closed before repeating it.

## 2. Copy and adapt

| From `$SETUP_REF` | Adapt |
|---|---|
| `.claude/settings.json` | allowlist to this repo's commands (`bin/*`, its package manager); `deny` its generated files; keep the format hook for its language |
| `.claude/rules/*.md` | keep only the areas this repo has; fix every `paths:` glob; delete rules about the reference's domain |
| `.claude/skills/verify/` | rewrite the steps from this repo's CI file, same order, same flags, same toolchain version |
| `.github/workflows/ci.yml`, issue and PR templates | this repo's jobs; CI = build, vet, format check, race tests with coverage, generated-code drift, vulnerability check, frontend lint/types/tests/build |
| `.gitignore`, `.dockerignore` entries | `.claude/settings.local.json`, `CLAUDE.local.md`, `.claude/worktrees/`, `.agents/` ignored; `.claude/` and `.agents/` out of the Docker context |

Agents come from `~/.claude/agents/code-writer.md` and `code-reviewer.md`: copy into `.claude/agents/` under project names, set `model` on each, replace the generic invariants with this repo's, and point both at `REVIEW.md`.

Project-only plugins and MCP servers are enabled in this repo's settings, never globally; machine-local values (hosts, tenant names, tokens) go in `.claude/settings.local.json`.

## 3. Write the docs

- `CLAUDE.md`, under ~120 lines, pointers only: what the project is, run and data, the architecture rules a newcomer breaks, "done means", the workflow, the agent roster. No status.
- `GLOSSARY.md` with `_Avoid_` terms (and `GLOSSARY-MAP.md` when there are several contexts): build it with the `mattpocock-skills:domain-modeling` skill. A lending repo aligns with the canonical glossary named in the private references.
- `docs/adr/0001-<slug>.md`: the first real decision, in the format the domain-modeling skill uses.
- `docs/agents/`: ask the owner to run `/mattpocock-skills:setup-matt-pocock-skills` (it is user-invoked only); it writes `issue-tracker.md`, `domain.md` and `triage-labels.md` and an `## Agent skills` block in `CLAUDE.md`.
- `ROADMAP.md`: ordered milestones, one line each, linking the epic issue. No status, no dates that will rot.
- `REVIEW.md`: the invariants a reviewer checks in this repo (tenancy, transactions, money, migrations, error mapping), each with the failure it prevents.
- `docs/build-log.md`: a heading per epic, then one line per merged PR (`- #<n> <slug>: what landed; evidence; deviations`). Never one growing paragraph.

## 4. Turn prose into checks

For each rule in `CLAUDE.md` or the rules files, ask whether a test, hook or CI step can enforce it. The usual first two: an architecture test for the layer import rules, and a route conformance test (every route has a guard row, every row is served). File the rest as `needs-triage` issues. Delete the prose once its check exists.

## 5. Gate

- `jq empty .claude/settings.json`; every rule file's `paths:` matches at least one file (`git ls-files '<glob>' | head -1`).
- The `verify` skill runs green on a clean checkout, and its steps match the CI file line for line.
- `wc -l CLAUDE.md` is under ~120; `git grep` finds no private repo name and no machine-local value in tracked files.
- A fresh session in the repo lists the project agents and the `verify` skill.

Ship it as one PR per part when the repo already has work in flight (settings and rules; verify and CI; docs), otherwise one setup PR.
