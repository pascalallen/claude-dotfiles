# Go Service Conventions (authoritative)

These are the rules the code follows. When you add anything, match them exactly —
`carline` (production) is the ground truth; `go-clean-arch` is the clean template.
Where the two diverge, carline wins.

## Domain (`internal/<app>/domain/`) — pure Go, zero framework/infra imports

- Entities are **plain structs with exported fields and JSON tags**; IDs are
  `ulid.ULID` (`github.com/oklog/ulid/v2`), stored as `CHAR(26)` with a
  `char_length(id) = 26` CHECK. No private-field/getter aggregates, no
  event-sourcing machinery (`raise`/`applyEvent`/`version`) — that lives only in
  the `event-sourcing` skill. Secrets are tagged `json:"-"`.
- Timestamps: `CreatedAt time.Time`, `ModifiedAt *time.Time` (nil until first change).
- Construct via a factory: `Register(id ulid.ULID, ...) *Entity` (returns the
  pointer, **no error**). Mutations are methods that set fields and stamp
  `ModifiedAt = &now`.
- The **repository interface is defined in the domain package** (`user.Repository`),
  not next to the handler. Value objects get their own sub-package (`password`,
  `pagination`, etc.).

## Messaging — synchronous, in-process, map-based

All three buses are **synchronous**: map-based registries, no channels, no
goroutines. The command bus returns the handler's real error to the caller.
`ctx context.Context` is threaded through every bus method, handler, listener,
and repository call.

```go
type CommandBus interface {
	RegisterHandler(commandType string, handler CommandHandler)
	Dispatch(ctx context.Context, cmd Command) error
}
type QueryBus interface {
	RegisterHandler(queryType string, handler QueryHandler)
	Fetch(ctx context.Context, qry Query) (any, error)
}
type EventDispatcher interface {
	RegisterListener(eventType string, listener Listener)
	Dispatch(ctx context.Context, evt Event) // no error return — listeners log failures
}
```

Implementations are `SynchronousCommandBus` / `SynchronousQueryBus` /
`SynchronousEventDispatcher`, constructed via `New...(logger) <Interface>`.
Dispatch looks up the handler in the map (`no handler registered` error if
missing), logs at entry/success/error. The dispatcher holds **one listener per
event name** — registering again overwrites.

When an event must survive the request that produced it (email sends, WebSocket
broadcasts), dispatch with `context.WithoutCancel(ctx)`.

For true background/fan-out work, do NOT make the bus async again — use the
standalone `github.com/pascalallen/pubsub/v2` library (goroutine/channel pub-sub)
alongside the synchronous buses.

> Deployment consequence: buses and any WebSocket hub are in-process, so the
> service runs with a **single instance** (`instance_count: 1` on DO App Platform).

## Application (`internal/<app>/application/`)

- Commands/queries/events/handlers/listeners are **grouped by domain into one file
  per layer** (`command/user.go`, `command_handler/user.go`, `query/user.go`, …) —
  NOT one file per message. `command/user.go` holds `RegisterUser` + `DeleteUser`.
- A command struct has `CommandName() string`; a query `QueryName() string`; an
  event `EventName() string` — each returning the literal type name.
- **Handlers are structs with exported dependency fields** and a value receiver,
  wired by **struct literal in `main.go`**, not by a `NewXHandler` constructor.
- Signatures:
  `Handle(ctx context.Context, cmd messaging.Command) error` (command),
  `Handle(ctx context.Context, qry messaging.Query) (any, error)` (query),
  `Handle(ctx context.Context, evt messaging.Event) error` (listener).
- Handlers type-assert the concrete message first; on mismatch log an error and
  return an error. Errors wrap with `fmt.Errorf("...: %s", err)`. Log Info at
  entry and at success.
- Command handlers **dispatch events via the injected `EventDispatcher`**;
  listeners react — often by dispatching a follow-up command via `CommandBus`
  (e.g. `UserRegistered` → `SendWelcomeEmail`).
- Repositories return `nil, nil` (not an error) when a record is not found
  (`errors.Is(err, sql.ErrNoRows)`); callers must nil-check.

## Infrastructure (`internal/<app>/infrastructure/`)

- DB is **`database/sql` + `lib/pq`** (`*sql.DB`), raw parameterized SQL, **no
  ORM**, no pgx. Repository constructors take `(*sql.DB, logger.Logger)` and
  **return the domain interface** (`func NewPostgresUserRepository(...)
  user.Repository`). Files named `postgres_<entity>_repository.go`. Multi-table
  writes use a transaction with rollback-on-error.
- DI: Google **Wire** builds a `container.Container` struct
  (`InitializeContainer() Container`) in `infrastructure/container/`. Add a
  dependency by adding a field to `Container`, a param to `NewContainer`, and a
  provider to `wire.Build`, then regenerate with `go tool wire`.
- HTTP: a `routes.Router` wrapper with one method per domain group; Gin handlers
  live in `application/http/action/<domain>/` as closures returning
  `gin.HandlerFunc`, named for the verb (`create.go`, `list.go`, `detail.go`);
  per-action `XRequestPayload`/`XResponsePayload` structs with `binding` tags;
  responses go through the `responder` JSend helpers; cross-cutting concerns are
  `middleware/`. Route groups under `const v1 = "/api/v1"`.
- Migrations: golang-migrate, `.up.sql`/`.down.sql` pairs under
  `infrastructure/database/migrations/`, run on startup by
  `database.RunMigrations` (which also seeds). `CITEXT` for emails,
  trimmed-nonempty CHECK constraints.
- Logger is `log/slog` behind the `domain/logger.Logger` interface (JSON in
  production via `APP_ENV`, text otherwise).

## Wiring flow in `cmd/<app>/main.go`

`container.InitializeContainer()` → `database.RunMigrations` → register handlers
and listeners in `registerCommandHandlers` / `registerEventListeners` /
`registerQueryHandlers` (struct literals reading `container` fields) →
`configureServer` builds the router → graceful shutdown on SIGINT/SIGTERM stops
the HTTP server. No consumer goroutines, no bus `Shutdown()` — the buses are
synchronous. Maintenance CLIs get their **own binary** (`cmd/admin`), never
server subcommands, and never run migrations.

## Testing

`stretchr/testify`. Test names are plain and descriptive, with `t.Run` subtests
that read as sentences:

```go
func TestSynchronousCommandBus(t *testing.T) {
	t.Run("runs the handler inline and returns nil on success", func(t *testing.T) { ... })
	t.Run("returns an error when no handler is registered", func(t *testing.T) { ... })
}
```

Do not report work done until `go build ./...` and `go test ./...` are green.

## Condensed reference snippets

Illustrative shapes — the cloned repo and `carline` are the full, current source.

**Domain entity + repository interface** (`domain/<entity>/`):
```go
// <entity>.go
package <entity>

type <Entity> struct {
	Id         ulid.ULID  `json:"id"`
	Name       string     `json:"name"`
	CreatedAt  time.Time  `json:"created_at"`
	ModifiedAt *time.Time `json:"modified_at,omitempty"`
}

func Register(id ulid.ULID, name string) *<Entity> {
	return &<Entity>{Id: id, Name: name, CreatedAt: time.Now()}
}

func (e *<Entity>) UpdateName(name string) {
	e.Name = name
	now := time.Now()
	e.ModifiedAt = &now
}

// repository.go
type Repository interface {
	GetById(ctx context.Context, id ulid.ULID) (*<Entity>, error)
	GetAll(ctx context.Context, pageParams pagination.PageParams) (*pagination.Collection[<Entity>], error)
	Add(ctx context.Context, e *<Entity>) error
	Save(ctx context.Context, e *<Entity>) error
	Remove(ctx context.Context, e *<Entity>) error
}
```

**Command + struct-literal handler dispatching an event** (`application/`):
```go
// command/<entity>.go
type Register<Entity> struct {
	Id   ulid.ULID `json:"id"`
	Name string    `json:"name"`
}
func (c Register<Entity>) CommandName() string { return "Register<Entity>" }

// command_handler/<entity>.go
type Register<Entity>Handler struct {
	Logger             logger.Logger
	<Entity>Repository <entity>.Repository
	EventDispatcher    messaging.EventDispatcher
}

func (h Register<Entity>Handler) Handle(ctx context.Context, cmd messaging.Command) error {
	c, ok := cmd.(*command.Register<Entity>)
	if !ok {
		h.Logger.Error("invalid command type passed to Register<Entity>Handler", "command", cmd)
		return fmt.Errorf("invalid command type passed to Register<Entity>Handler: %v", cmd)
	}
	e := <entity>.Register(c.Id, c.Name)
	if err := h.<Entity>Repository.Add(ctx, e); err != nil {
		return fmt.Errorf("<entity> registration failed: %s", err)
	}
	h.EventDispatcher.Dispatch(context.WithoutCancel(ctx), &event.<Entity>Registered{Id: c.Id, Name: c.Name})
	return nil
}
```

**lib/pq repository method** (`infrastructure/repository/`):
```go
func NewPostgres<Entity>Repository(session *sql.DB, logger logger.Logger) <entity>.Repository {
	return &Postgres<Entity>Repository{session: session, logger: logger}
}

func (r *Postgres<Entity>Repository) GetById(ctx context.Context, id ulid.ULID) (*<entity>.<Entity>, error) {
	var e <entity>.<Entity>
	var i string
	q := `SELECT id, name, created_at, modified_at FROM <entity>s WHERE id = $1`
	if err := r.session.QueryRowContext(ctx, q, id.String()).Scan(&i, &e.Name, &e.CreatedAt, &e.ModifiedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil // not found — caller nil-checks
		}
		return nil, fmt.Errorf("error scanning <Entity> by ID: %s", err)
	}
	e.Id = ulid.MustParse(i)
	return &e, nil
}
```

**Wire container fragment** (`infrastructure/container/`):
```go
type Container struct {
	DatabaseSession    *sql.DB
	Logger             logger.Logger
	<Entity>Repository <entity>.Repository
	CommandBus         messaging.CommandBus
	QueryBus           messaging.QueryBus
	EventDispatcher    messaging.EventDispatcher
}
// wire.go: wire.Build(NewContainer, slog.New, database.NewPostgresSession,
//   repository.NewPostgres<Entity>Repository, messaging.NewSynchronousCommandBus,
//   messaging.NewSynchronousQueryBus, messaging.NewSynchronousEventDispatcher, ...)
```

**Register in `main.go`:**
```go
container.CommandBus.RegisterHandler(command.Register<Entity>{}.CommandName(), command_handler.Register<Entity>Handler{
	Logger:             c.Logger,
	<Entity>Repository: c.<Entity>Repository,
	EventDispatcher:    c.EventDispatcher,
})
```

## Project layout

```
cmd/<app>/            main.go — container init, migrations, registration, router, shutdown
cmd/admin/            optional maintenance CLI (own binary; never runs migrations)
internal/<app>/
  domain/             pure types (no framework imports)
    <entity>/         entity struct + Repository interface
    password/ pagination/ logger/ ...   value objects + interfaces
  application/
    command/ command_handler/           grouped by domain, one file per layer
    query/   query_handler/
    event/   listener/
    http/action/<domain>/  http/middleware/  http/responder/   (Gin, JSend)
  infrastructure/
    container/        Wire Container struct (container.go + wire.go + wire_gen.go)
    database/         NewPostgresSession, RunMigrations, migrations/, seeders/
    repository/       database/sql + lib/pq implementations (return domain interface)
    messaging/        Synchronous command/query bus + event dispatcher (interfaces)
    routes/           Router wrapper, one method per domain group
    logger/slog/      slog adapter for domain/logger.Logger
    service/          JWT / external service adapters
    websocket/        Hub (only if the service needs real-time)
Dockerfile  compose.yaml  bin/{up,down,exec}  .env.example  go.mod
```
