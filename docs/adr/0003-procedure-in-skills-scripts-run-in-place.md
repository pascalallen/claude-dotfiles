# ADR 0003 — Agent procedure lives in skills; its scripts run in place

**Status:** Accepted (2026-11-10)

## Context

A long agent-driven build kept its orchestration procedure in three places: the
project `CLAUDE.md`, per-project memory, and scratch folders outside git. The
landing scripts were copied into every round folder with hardcoded paths; about
thirty copies drifted (toolchain version, rebase versus merge, a stale notice
in PR comments). None of it reached the next project.

A previous attempt to ship a per-repo setup as a kit of embedded files in this
repo was closed: it contradicted ADR 0001.

## Decision

- Rules that hold in every session stay in `CLAUDE.md`, a line each.
- Procedure is a skill: `agent-waves` for running waves, `claude-repo-setup`
  for a repo's setup.
- `claude-repo-setup` follows ADR 0001: a copy recipe against a living
  reference repo plus a conventions file. No file bodies.
- `agent-waves` ships two scripts. They are tools, not templates: called
  through `${CLAUDE_SKILL_DIR}`, never copied into a project. Anything
  project-specific is a command the project supplies (`VERIFY_CMD`,
  `GATE_CMD`).
- Round files (briefs, ledger, logs) live in the project's git-ignored
  `.agents/rounds/<id>/`.

## Consequences

- A fix to landing is one change here and reaches every project.
- The scripts need `gh`, `jq` and `git`, and assume GitHub check runs.
- A project with no verify or gate command lands on CI alone; the skill says
  so instead of inventing one.
