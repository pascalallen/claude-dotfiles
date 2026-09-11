---
name: verify
description: Run the full verification gate for this repo (Go build/vet/gofmt/race tests and, when web/app exists, yarn lint/typecheck/test/build) and report pass/fail per step. Use before claiming work is done, before committing, and before opening a PR.
allowed-tools: Bash(go *) Bash(gofmt *) Bash(yarn *) Bash(yarn --cwd web/app *) Bash(bin/exec *) Bash(bin/yarn *)
---

# Verify

Run every gate this repo enforces in CI, **in order, stopping at the first
failure**. Report each step's pass/fail as a table; don't summarize away a
failure or skip ahead to later steps once one fails.

## Go gate

```bash
go build ./...
go vet ./...
gofmt -l cmd internal     # empty output = pass; any filename printed = fail (needs gofmt -w)
go test -race -cover ./...
```

**Never run `gofmt -l .`** in a repo that has `web/app` — it walks the
filesystem, not Go module boundaries, and sweeps up the stray `.go` files
`node_modules` ships, producing false positives. Target `cmd internal`
(or whatever top-level Go package roots the repo actually has) instead.

If the project runs Go inside Docker (check for `bin/exec`), run each command
through it instead: `bin/exec go build ./...`, etc.

## Frontend gate (only if `web/app/` exists)

Run from the repo root using `yarn --cwd web/app` rather than `cd web/app &&
yarn ...` — it keeps each step a single command that matches one allow rule,
instead of a compound `cd && yarn` command Claude Code has to match as two
separate pieces:

```bash
yarn --cwd web/app lint
yarn --cwd web/app typecheck
yarn --cwd web/app test --ci
yarn --cwd web/app build
```

If the project runs Yarn inside Docker (check for `bin/yarn`), use
`bin/yarn lint`, `bin/yarn typecheck`, `bin/yarn test --ci`, `bin/yarn build`
instead — those already run from the repo root.

## Report

A table with one row per step actually run:

| Step | Result |
|------|--------|
| go build | pass |
| go vet | pass |
| gofmt | pass |
| go test -race -cover | pass |
| yarn lint | pass |
| yarn typecheck | pass |
| yarn test | pass |
| yarn build | pass |

Stop at the first failing step, show its full output, and do not report later
steps as passed — they didn't run. A green table is the bar for "done"; a
green test suite alone is not.

## Project-specific checks

<!-- e.g. wire regeneration reminder, manual e2e recipe -->

This section is the slot for anything this repo's gate needs beyond the Go
and frontend gates above — append here instead of improvising a location
elsewhere in the file. Add its steps to the Report table too.
