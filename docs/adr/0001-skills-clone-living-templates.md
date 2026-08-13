# ADR 0001 — Skills clone living templates instead of embedding file copies

**Status:** Accepted (2026-07-13, reaffirmed 2026-08-13)

## Context

The original scaffold skills embedded full copies of every file they generated
(composer.json, Dockerfiles, nginx configs, webpack configs, entire Go files).
Those copies rotted: within months the skills prescribed a messaging pattern,
frontend stack, and directory layout that production (`carline`) had already
moved past. A skill that is a snapshot of a repo is a second copy of that repo
with no CI.

## Decision

Scaffold skills do not embed full file bodies. Each skill is:

1. a **clone/copy recipe** against a living, buildable template repo
   (`go-clean-arch`, `DockerSymfony`, `carline/web/app`), plus
2. the **conventions** the template encodes, in a `references/` file, marked
   authoritative over the template when the two diverge, plus
3. a **verification gate** (build + tests green) before the scaffold counts as done.

Small illustrative snippets are fine; complete config/file dumps are not.

## Consequences

- Skills stay short (SKILL.md ≤ ~150 lines) and age well; drift shows up as a
  one-line conventions fix, not a 500-line template rewrite.
- The template repos must stay buildable — they are effectively part of the
  toolchain. When production diverges from a template (e.g. carline's
  synchronous buses vs go-clean-arch's channel buses), the conventions file
  records the delta until the template is migrated.
