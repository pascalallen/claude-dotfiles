---
name: jira-ticket
description: Work a Jira ticket end to end in the repository you are standing in — read the ticket, learn the repo's own process and conventions, plan, implement, make one commit and open a draft pull request. Use when given a Jira ticket URL or key (e.g. https://<host>/browse/ABC-123, or "ABC-123"), or when asked to pick up, start, or implement a ticket. Never merges.
---

# Jira Ticket

Drive one Jira ticket from URL to draft pull request, using the conventions the
target repository already demonstrates rather than any encoded here.

## The one rule

**Derive conventions, never assume them.** Branch names, commit subjects, PR body
shape and ticket-reference form vary per repository and per team. They are already
written down — in the repo's agent docs, or demonstrated in its merged pull
requests. Read them. A skill that hardcodes one house style is wrong in every
other house, and goes stale in its own.

## Steps

### 1. Read the ticket

Parse the key from the URL (`.../browse/<KEY>`) or take it bare. Then, in order:

1. An Atlassian MCP server, if one is connected **and authenticated**. Several are
   commonly present but unauthenticated — a call that returns an auth prompt is a
   miss, not an answer.
2. The user, if it is not. Ask for the title and description; do not guess at
   scope from the key alone.

Restate the ticket in one or two sentences and say which repository you believe
it lands in. Stop if that is not the repository you are standing in.

### 2. Learn this repository's process

Read, in this order, skipping what does not exist:

- `AGENTS.md` / `CLAUDE.md` at the root, and **follow their pointers** — they
  frequently delegate to a separate process or decision repository rather than
  restating rules locally. Read what they point at, including `docs/agents/*`.
- `CONTRIBUTING.md`, `.github/pull_request_template.md`, `docs/adr/`.
- The evidence: `git log --format='%s%n%b' -15` and the last handful of merged
  PRs. This is how you learn the real branch prefix, whether the subject carries
  a conventional-commit type and the ticket key as a scope, whether the commit
  body *is* the PR body, and whether the ticket is referenced by a `Ticket:`
  line, a trailer, or a `Closes #n`.

Note which issue tracker actually governs the work. Where a repository's agent
docs name a separate decision repository, a bare `#42` means issue 42 **here** —
cross-repository references must be written and read in full.

### 3. Plan, then confirm

Explore enough to name the files you will touch. Present the plan and the
conventions you inferred (branch, subject, body shape) before writing anything.
Deriving a convention is fallible; showing your reading of it is how that gets
caught.

### 4. Branch

Create the branch before editing. The default branch is usually protected, and a
protected branch rejects the push *after* the work is done. Shape the name on
what the repo's own branches look like, with the ticket key in it.

### 5. Implement and commit

Do the work, then **one commit**. Match the inferred subject form and include the
ticket reference in the form the repo uses — for a Jira-tracked repo with no
GitHub issue, a `Ticket: <KEY>` line usually is that form.

**Add no AI attribution** — no `Co-Authored-By`, no generated-with footer — unless
the repository's own recent commits carry one. Stage files explicitly; many repos
lack a `.gitignore` and `git add -A` will sweep in editor directories.

### 6. Draft pull request

Push, then open the PR **as a draft**. Prefer `gh pr create`; fall back to the
GitHub MCP `create_pull_request` with `draft: true` when `gh` is absent. Title and
body follow the inferred form.

**Never merge, and never push to the default branch.** The author reviews and
merges every pull request themselves.

### 7. Report

Give the PR URL, the branch, and anything you deliberately left out of scope.

## Checklist

- [ ] Ticket read from Jira or supplied by the user — not inferred from the key
- [ ] Repo's agent docs read, *including what they point at elsewhere*
- [ ] Conventions derived from `git log` / merged PRs, and shown to the user
- [ ] Branch created before the first edit
- [ ] One commit, ticket referenced in the repo's own form
- [ ] No AI attribution unless the repo's own history has it
- [ ] Files staged explicitly
- [ ] PR opened as a draft, not merged
