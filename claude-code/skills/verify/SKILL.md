---
name: verify
description: Run the full verification gate for this repo (Go build/vet/gofmt/race tests and, when web/app exists, yarn lint/typecheck/test/build) and report pass/fail per step. Use before claiming work is done, before committing, and before opening a PR.
allowed-tools: Bash(go *) Bash(gofmt *) Bash(yarn *) Bash(bin/exec *) Bash(bin/yarn *)
---

# Verify

Run every gate this repo enforces in CI, **in order, stopping at the first
failure**. Report each step's pass/fail as a table; don't summarize away a
failure or skip ahead to later steps once one fails.

## Go gate

```bash
go build ./...
go vet ./...
test -z "$(gofmt -l .)"     # non-empty output = files need gofmt -w
go test -race -cover ./...
```

If the project runs Go inside Docker (check for `bin/exec`), run each command
through it instead: `bin/exec go build ./...`, etc.

## Frontend gate (only if `web/app/` exists)

```bash
cd web/app
yarn lint
yarn typecheck
yarn test --ci
yarn build
```

If the project runs Yarn inside Docker (check for `bin/yarn`), use
`bin/yarn lint`, `bin/yarn typecheck`, `bin/yarn test --ci`, `bin/yarn build`
instead, run from the repo root.

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
