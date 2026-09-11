---
paths:
  - "cmd/**"
  - "internal/**"
  - "**/*.go"
---

# Go conventions

- **Hexagonal layering is one-directional**: `domain` imports nothing outside
  itself (no framework, no infrastructure). `application` orchestrates use
  cases and never imports `infrastructure`. `infrastructure` imports both
  `application` and `domain`. If a file under `application/` needs to import
  something from `infrastructure/`, that's the layering violation to fix, not
  a reason to add an exception.
- HTTP handlers are Gin **closure actions** (`func HandleX() gin.HandlerFunc`)
  returning a `gin.HandlerFunc`, not method-per-struct controllers. Responses
  go through the shared JSend responders — don't hand-roll response envelopes.
- `wire_gen.go` is **generated** — never hand-edit it. After changing a Wire
  provider, regenerate with `go generate ./internal/<app>/infrastructure/container/...`
  (not a bare `go tool wire` unless the project's own docs say otherwise —
  check the project's CLAUDE.md for the exact command).
- Repository implementations return `nil, nil` for "not found", never a
  sentinel error — callers branch on a nil check, not error-type matching.
- Thread `ctx context.Context` through every handler and repository method;
  don't drop it partway down a call chain.
- Tests use **testify** with one `TestXxx` per type/unit and `t.Run` subtests
  named as sentences (`t.Run("returns nil when the record does not exist", ...)`),
  not terse label-style names.
- `gofmt -l cmd internal` and `go vet ./...` must both be clean before code is
  considered done — this is enforced by the `gofmt` PostToolUse hook and CI,
  but don't rely on the hook alone; run the gate yourself before claiming a
  task done. **Never run `gofmt -l .`** in a repo that has `web/app` — it
  walks the filesystem regardless of Go module boundaries and sweeps up the
  stray `.go` files `node_modules` ships, producing false positives.
