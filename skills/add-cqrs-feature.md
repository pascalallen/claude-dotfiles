---
name: add-cqrs-feature
description: Add a CQRS feature — a command+handler, query+handler, and/or domain event+listener, optionally exposed over an HTTP route — to an existing Go service built on Pascal Allen's DDD/hexagonal/CQRS conventions (go-clean-arch / carline shape). Use when extending a service the new-go-service skill produced, not for scaffolding a new one.
---

# Add CQRS Feature

Extend an existing Go service (the shape produced by the `new-go-service` skill /
`go-clean-arch` / `carline`) with a new command, query, event, and/or route,
following the established conventions exactly.

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
for your entity, and which repositories/services already exist on `container.Container`.

## The conventions (non-negotiable)

- **Group by domain, one file per layer.** A new `Invoice` command goes into the
  existing `command/invoice.go` (create it if the domain is new), NOT a new
  `register_invoice.go`. Same for `command_handler/invoice.go`, `query/invoice.go`,
  `query_handler/invoice.go`, `event/invoice.go`, `listener/invoice.go`.
- **Handlers are structs with exported dependency fields + value receiver**, wired
  by struct literal in `main.go`. No `NewXHandler` constructors.
- Command handler signature: `Handle(cmd messaging.Command) error`.
  Query handler signature: `Handle(qry messaging.Query) (any, error)`.
  Listener signature: `Handle(evt messaging.Event) error`.
- Each message struct carries its name method: `CommandName()` / `QueryName()` /
  `EventName()` returning the exact type name string.
- Type-assert the concrete message first; on mismatch log an error and return an
  error. Use `ulid.ULID` for IDs. Return `nil, nil` from repositories on not-found.
- Dispatch events from within command handlers via an injected
  `messaging.EventDispatcher`. Never construct events outside the aggregate/handler
  flow that owns them.

## Steps

### 1. Command (state change)

Append to `application/command/<domain>.go`:
```go
type <Verb><Entity> struct {
	Id   ulid.ULID `json:"id"`
	// ...fields
}
func (c <Verb><Entity>) CommandName() string { return "<Verb><Entity>" }
```

Append the handler to `application/command_handler/<domain>.go`:
```go
type <Verb><Entity>Handler struct {
	Logger            logger.Logger
	<Entity>Repository <entity>.Repository
	EventDispatcher   messaging.EventDispatcher // only if it emits events
}

func (h <Verb><Entity>Handler) Handle(cmd messaging.Command) error {
	c, ok := cmd.(*command.<Verb><Entity>)
	if !ok {
		h.Logger.Error("invalid command type passed to <Verb><Entity>Handler", "command", cmd)
		return fmt.Errorf("invalid command type passed to <Verb><Entity>Handler: %v", cmd)
	}
	// load / mutate / persist via repository
	// h.EventDispatcher.Dispatch(&event.<Entity><Past>{...})
	return nil
}
```

### 2. Query (read)

Append to `application/query/<domain>.go`:
```go
type Get<Entity>ById struct {
	Id ulid.ULID `json:"id"`
}
func (q Get<Entity>ById) QueryName() string { return "Get<Entity>ById" }
```

Append the handler to `application/query_handler/<domain>.go`:
```go
type Get<Entity>ByIdHandler struct {
	Logger            logger.Logger
	<Entity>Repository <entity>.Repository
}

func (h Get<Entity>ByIdHandler) Handle(qry messaging.Query) (any, error) {
	q, ok := qry.(query.Get<Entity>ById)
	if !ok {
		return nil, fmt.Errorf("invalid query type passed to Get<Entity>ByIdHandler: %v", qry)
	}
	return h.<Entity>Repository.GetById(q.Id)
}
```

### 3. Domain event + listener (optional)

`application/event/<domain>.go`:
```go
type <Entity><Past> struct {
	Id ulid.ULID `json:"id"`
	// ...payload the listener needs
}
func (e <Entity><Past>) EventName() string { return "<Entity><Past>" }
```

`application/listener/<domain>.go` — a struct with the deps it needs (often
`CommandBus` to chain a follow-up command, or a `websocket.Hub` to broadcast):
```go
type <Entity><Past>Listener struct {
	Logger     logger.Logger
	CommandBus messaging.CommandBus
}

func (l <Entity><Past>Listener) Handle(evt messaging.Event) error {
	e, ok := evt.(*event.<Entity><Past>)
	if !ok {
		return fmt.Errorf("invalid event type passed to <Entity><Past>Listener: %v", evt)
	}
	// react: l.CommandBus.Execute(&command.SomethingNext{...})
	return nil
}
```

### 4. Repository method (if the handler needs new persistence)

Add the method to the domain `Repository` interface (`domain/<entity>/repository.go`)
**and** implement it in `infrastructure/repository/postgres_<entity>_repository.go`
using `database/sql` + `lib/pq`, raw parameterized SQL, `nil, nil` on `sql.ErrNoRows`,
and a transaction for multi-table writes. If the entity is brand new, also add its
struct + factory (`domain/<entity>/<entity>.go`) and a golang-migrate
`.up.sql`/`.down.sql` pair under `infrastructure/database/migrations`.

### 5. Register in `main.go`

Add the registration line to the matching `setup*` function, reading dependencies
off the `container`:
```go
commandBus.RegisterHandler(command.<Verb><Entity>{}.CommandName(), command_handler.<Verb><Entity>Handler{
	Logger:            c.Logger,
	<Entity>Repository: c.<Entity>Repository,
	EventDispatcher:   c.EventDispatcher,
})
// query:  queryBus.RegisterHandler(query.Get<Entity>ById{}.QueryName(), query_handler.Get<Entity>ByIdHandler{...})
// event:  eventDispatcher.RegisterListener(event.<Entity><Past>{}.EventName(), listener.<Entity><Past>Listener{...})
```

If the handler needs a dependency not yet on the container, add it: a field on
`container.Container`, a param to `NewContainer`, and a provider in
`wire.Build`, then **regenerate Wire** (see step 7).

### 6. HTTP route (optional)

Add a handler closure in `application/http/action/<domain>/<action>.go` returning
`gin.HandlerFunc` — bind + validate the request, `commandBus.Execute(...)` (async,
respond `202`/`AcceptedResponse`) or `queryBus.Fetch(...)` (respond via
`responder.OkResponse`), and use the `responder` JSend helpers for every response.
Register it on the domain's router method in `infrastructure/routes/<domain>.go`
(add the method if the domain group is new, and call it from `configureServer` in
`main.go`). Apply `middleware.AuthRequired`-style middleware where the existing
routes do.

### 7. Regenerate Wire (only if the container changed) & verify

Regenerate only when you added a field/provider to the container in step 5. Use the
tool directive (build the generator with the module's own toolchain — a stale global
`wire` refuses a newer module):

```bash
go get -tool github.com/google/wire/cmd/wire      # once, if not already in go.mod
(cd internal/<app>/infrastructure/container && go tool wire)
go build ./...     # MUST pass
go test ./...      # MUST pass
```

Add a `TestThat...` test (testify) for new domain behavior. Do not report the
feature done until build and tests are green.

## Checklist

- [ ] Message struct(s) added to the grouped-by-domain file, with `*Name()` method
- [ ] Handler/listener struct with exported deps + value receiver + type assertion
- [ ] Repository interface + lib/pq implementation updated (if persistence changed)
- [ ] Migration pair added (if a new table/column)
- [ ] Registered in the correct `setup*` func in `main.go`
- [ ] Container + Wire updated and regenerated (if a new dependency)
- [ ] Route + action + responder wired (if exposed over HTTP)
- [ ] `go build ./...` and `go test ./...` green
