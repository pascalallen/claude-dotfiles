---
name: add-cqrs-feature
description: Add a CQRS feature — a command+handler, query+handler, and/or domain event+listener, optionally exposed over an HTTP route — to an existing Go service built on Pascal Allen's DDD/hexagonal/CQRS conventions (go-clean-arch / carline shape). Use when extending a service the new-go-service skill produced, not for scaffolding a new one.
---

# Add CQRS Feature

Extend an existing Go service (the shape produced by the `new-go-service` skill /
`go-clean-arch` / `carline`) with a new command, query, event, and/or route,
following the established conventions exactly.

Code templates for every step are in **`references/templates.md`** — read it
before writing code.

## When to use

- Adding a state-changing operation → **command + command handler** (+ optional
  domain event + listener).
- Adding a read → **query + query handler**.
- Reacting to something that happened → **domain event + listener**.
- Exposing any of the above over HTTP → **route + action**.

If you are creating the service from scratch, use `new-go-service` first.

## Orient before editing

Read the target service so you follow ITS names, not a template's:

```bash
find internal/*/application -maxdepth 2 -type d
sed -n '1,80p' cmd/*/main.go              # how handlers/listeners are registered
ls internal/*/infrastructure/container/    # container.go — available dependencies
```

Note the module path (`go.mod`), the `internal/<app>/` segment, the domain package
for your entity, and which repositories/services already exist on
`container.Container`. Also check the handler signatures in the service — current
convention is `Handle(ctx context.Context, ...)` with synchronous buses; older
scaffolds may lack `ctx` (match the service, or migrate it first via
`new-go-service` § "Align messaging").

## The conventions (non-negotiable)

- **Group by domain, one file per layer.** A new `Invoice` command goes into the
  existing `command/invoice.go` (create it if the domain is new), NOT a new
  `register_invoice.go`. Same for `command_handler/invoice.go`, `query/invoice.go`,
  `query_handler/invoice.go`, `event/invoice.go`, `listener/invoice.go`.
- **Handlers are structs with exported dependency fields + value receiver**, wired
  by struct literal in `main.go`. No `NewXHandler` constructors.
- Command handler: `Handle(ctx context.Context, cmd messaging.Command) error`.
  Query handler: `Handle(ctx context.Context, qry messaging.Query) (any, error)`.
  Listener: `Handle(ctx context.Context, evt messaging.Event) error`.
- Each message struct carries its name method: `CommandName()` / `QueryName()` /
  `EventName()` returning the exact type name string.
- Type-assert the concrete message first; on mismatch log an error and return an
  error. Use `ulid.ULID` for IDs. Return `nil, nil` from repositories on not-found.
- Dispatch events from within command handlers via the injected
  `messaging.EventDispatcher`, using `context.WithoutCancel(ctx)` when the event's
  side effects must survive the request. Never construct events outside the
  handler flow that owns them.
- Buses are synchronous: `CommandBus.Dispatch` returns the handler's real error;
  `QueryBus.Fetch` returns `(any, error)`. HTTP actions surface those results —
  no fire-and-forget.

## Steps

1. **Command (state change)** — append the command struct to
   `application/command/<domain>.go` and its handler to
   `application/command_handler/<domain>.go` (templates § 1).
2. **Query (read)** — append to `application/query/<domain>.go` and
   `application/query_handler/<domain>.go` (templates § 2).
3. **Domain event + listener (optional)** — `application/event/<domain>.go` and
   `application/listener/<domain>.go`; listeners often chain a follow-up command
   via `CommandBus` or broadcast via a `websocket.Hub` (templates § 3).
4. **Repository method (if the handler needs new persistence)** — add the method
   to the domain `Repository` interface AND implement it in
   `infrastructure/repository/postgres_<entity>_repository.go` with raw
   parameterized SQL; transaction for multi-table writes. New entity → struct +
   factory + golang-migrate `.up.sql`/`.down.sql` pair under
   `infrastructure/database/migrations/` (templates § 4).
5. **Register in `main.go`** — add the registration line to the matching
   `register*` function, reading dependencies off the container. New dependency →
   add a `Container` field, `NewContainer` param, and `wire.Build` provider
   (templates § 5).
6. **HTTP route (optional)** — action closure in
   `application/http/action/<domain>/<verb>.go` returning `gin.HandlerFunc`;
   bind + validate the request payload, `Dispatch`/`Fetch` on the bus, respond
   via the `responder` JSend helpers; register on the domain's router method in
   `infrastructure/routes/<domain>.go` (templates § 6).
7. **Regenerate Wire & verify** — only if the container changed:

```bash
go get -tool github.com/google/wire/cmd/wire      # once, if not already in go.mod
go generate ./internal/<app>/infrastructure/container/...   # if container.go has //go:generate go tool wire
(cd internal/<app>/infrastructure/container && go tool wire) # fallback if it doesn't
git diff --stat internal/<app>/infrastructure/container/wire_gen.go   # confirm it actually changed
go build ./...     # MUST pass
go test ./...      # MUST pass
```

> Use `go tool wire`, not a stale global `wire` binary (older-toolchain wire
> refuses newer modules). In Docker: `bin/exec` inside the Go container.
> `go generate` with no `//go:generate` directive in the package prints
> nothing and exits 0 — that is NOT proof `wire_gen.go` regenerated; the
> `git diff --stat` step above is what actually confirms it (see
> `new-go-service` for adding the directive to a scaffold missing one).

Add a testify test for new domain behavior — plain descriptive names with `t.Run`
sentence subtests. Do not report the feature done until build and tests are green.

## Checklist

- [ ] Message struct(s) added to the grouped-by-domain file, with `*Name()` method
- [ ] Handler/listener struct with exported deps + value receiver + `ctx` + type assertion
- [ ] Repository interface + lib/pq implementation updated (if persistence changed)
- [ ] Migration pair added (if a new table/column)
- [ ] Registered in the correct `register*` func in `main.go`
- [ ] Container + Wire updated and regenerated (if a new dependency)
- [ ] Route + action + responder wired (if exposed over HTTP)
- [ ] `go build ./...` and `go test ./...` green
