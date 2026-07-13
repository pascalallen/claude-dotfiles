---
name: new-go-service
description: Scaffold a new Go microservice with DDD, hexagonal architecture, and CQRS by cloning and renaming the canonical go-clean-arch template — Google Wire DI, Gin, database/sql + lib/pq (PostgreSQL), golang-migrate, native Go channel messaging, JWT, Docker
---

# New Go Service

Scaffold a production-ready Go microservice following Pascal Allen's canonical
architecture (DDD + hexagonal + CQRS).

## Source of truth: clone the living template, don't hand-write files

The canonical scaffold is the maintained repo **`pascalallen/go-clean-arch`**
(`~/code/go-clean-arch` locally). It is a complete, buildable, tested reference:
the full `domain / application / infrastructure` layering, a Wire `Container`,
golang-migrate migrations + seeders, `bin/` scripts, Dockerfile, compose, and an
auth action. **Do not reconstruct these files from memory** — a hand-written copy
drifts out of sync with the real conventions. Instead: clone the template, rename
it to the new service, regenerate Wire, and verify it builds. The rest of this
skill is the part cloning can't give you — the rename recipe and the conventions
you must follow when adding to the service.

> `carline` (`~/code/carline`) is the production app built on these same
> conventions; consult it for richer examples (Stripe, WebSocket hub, multi-tenant
> scoping, refresh-token rotation) but treat `go-clean-arch` as the base to clone.

## Process

Ask the user:
1. **App name** — kebab-case (e.g. `billing-service`). Drives the module path
   `github.com/pascalallen/<app>`, the `internal/<app>/` package path, `cmd/<app>`,
   and the Docker image name.
2. **First domain entity** — PascalCase (e.g. `Invoice`). The clone ships a `User`
   entity end-to-end as the worked example; keep it as the reference and add the
   real entity with the `add-cqrs-feature` skill, OR rename `User` → `<Entity>` if
   the service has a single primary aggregate.

Substitutions: `<app>` (kebab, as given) · `<entity>` (lowercase) · `<Entity>` (PascalCase).

## Scaffold: clone + rename

Run from the directory that will hold the new project.

```bash
# 1. Copy the template without its git history (offline: use the local clone;
#    online: `git clone --depth 1 https://github.com/pascalallen/go-clean-arch <app>`)
cp -R ~/code/go-clean-arch <app>
cd <app>
rm -rf .git .idea coverage.out
git init

# 2. Rename the module and package path everywhere in Go source.
#    Order matters: module path first, then the internal package segment.
grep -rl 'pascalallen/go-clean-arch' --include='*.go' . \
  | xargs sed -i '' 's#pascalallen/go-clean-arch#pascalallen/<app>#g'
grep -rl 'internal/app/' --include='*.go' . \
  | xargs sed -i '' 's#internal/app/#internal/<app>/#g'

# 3. Fix the module line in go.mod
sed -i '' 's#module github.com/pascalallen/go-clean-arch#module github.com/pascalallen/<app>#' go.mod

# 4. Rename the physical directories
git mv internal/app internal/<app>   # (or plain `mv` before `git add`)
git mv cmd/app cmd/<app>

# 5. Fix the TWO hardcoded path strings the sed above did NOT catch
#    (they are string literals, not import paths):
#    - internal/<app>/infrastructure/database/migrate.go  → migrationPath
#    - Dockerfile                                         → COPY package path + build target
sed -i '' 's#internal/app/#internal/<app>/#g' internal/<app>/infrastructure/database/migrate.go
sed -i '' 's#internal/app/#internal/<app>/#g; s#\./cmd/app#./cmd/<app>#g' Dockerfile
```

> **Dockerfile caution:** only the package path (`internal/app/` → `internal/<app>/`)
> and the build target (`./cmd/app` → `./cmd/<app>`) change. The builder stage's
> `WORKDIR /app` and the compiled binary name `/usr/local/bin/app` are NOT package
> paths — leave them alone. Do not blanket-replace `/app`.

> On macOS `sed -i ''` takes an empty backup arg; on Linux use `sed -i`.
> After renaming, grep to confirm nothing stale remains:
> `grep -rn 'go-clean-arch\|internal/app/\|cmd/app' . --include='*.go' Dockerfile go.mod`

### Verify (and Wire)

`wire_gen.go` is generated — never hand-edit it. The clone already ships a valid
`wire_gen.go`, and the sed rename above keeps it correct, so **a straight rename needs
no regeneration**. Pin the generator for later use, then tidy and run the gate:

```bash
go get -tool github.com/google/wire/cmd/wire   # one-time: pins wire in go.mod's tool block
go mod tidy
go build ./...      # MUST pass
go test ./...       # MUST pass
```

Do not consider the scaffold done until `go build ./...` and `go test ./...` are both
green. (Locally you have Go directly; in the Docker flow use `bin/exec go build ./...`
after `bin/up`.)

**Regenerating Wire** (only after you change providers — see `add-cqrs-feature`):

```bash
(cd internal/<app>/infrastructure/container && go tool wire)
```

> Use `go tool wire`, not a globally-installed `wire` binary: a `wire` built with an
> older Go toolchain refuses a newer module ("package requires newer Go version").
> `go tool wire` builds the generator with the module's own toolchain. In Docker run
> it via `bin/exec` inside the go1.26 container.

## Conventions (authoritative)

These are the rules the generated code follows. When you add anything, match them
exactly — `go-clean-arch` and `carline` are consistent on all of these.

**Domain (`internal/<app>/domain/`) — pure Go, zero framework/infra imports.**
- Entities are **plain structs with exported fields and JSON tags**; IDs are
  `ulid.ULID` (`github.com/oklog/ulid/v2`). No private-field/getter aggregates, no
  event-sourcing machinery (`raise`/`applyEvent`/`version`) — that lives only in
  the `event-sourcing` skill.
- Timestamps: `CreatedAt time.Time`, `ModifiedAt *time.Time` (nil until first change).
- Construct via a factory: `Register(id ulid.ULID, ...) *Entity` (returns the
  pointer, **no error**). Mutations are methods that set fields and stamp
  `ModifiedAt = &now`.
- The **repository interface is defined in the domain package** (`user.Repository`),
  not next to the handler. Value objects get their own sub-package (`password`,
  `pagination`, etc.).

**Application (`internal/<app>/application/`).**
- Commands/queries/events/handlers/listeners are **grouped by domain into one file
  per layer** (`command/user.go`, `command_handler/user.go`, `query/user.go`, …) —
  NOT one file per message.
- A command struct has a `CommandName() string`; a query has `QueryName() string`;
  an event has `EventName() string`.
- **Handlers are structs with exported dependency fields** and a value receiver:
  `type RegisterUserHandler struct { Logger logger.Logger; UserRepository user.Repository; ... }`
  with `func (h RegisterUserHandler) Handle(cmd messaging.Command) error`. They are
  wired by **struct literal in `main.go`**, not by a `NewXHandler` constructor.
- Command `Handle` type-asserts the concrete command (`cmd.(*command.RegisterUser)`),
  logs an error and returns on mismatch, calls the aggregate factory/method, saves
  via the repository, and **dispatches events via an injected `EventDispatcher`**.
- Query `Handle(qry messaging.Query) (any, error)` type-asserts, reads via the
  repository, returns the result.
- Repositories return `nil, nil` (not an error) when a record is not found
  (`errors.Is(err, sql.ErrNoRows)`); callers must nil-check.

**Infrastructure (`internal/<app>/infrastructure/`).**
- DB is **`database/sql` + `lib/pq`** (`*sql.DB`), raw SQL, **no ORM**, no pgx.
  Repository constructors take `(*sql.DB, logger.Logger)` and **return the domain
  interface** (`func NewPostgresUserRepository(...) user.Repository`). Multi-table
  writes use a transaction with rollback-on-error.
- Messaging: `messaging.CommandBus` / `QueryBus` / `EventDispatcher` are
  **interfaces**; the channel-backed implementations are constructed via `New...`
  returning the interface. Command bus is async (buffered channel, `Execute` →
  handler on a consumer goroutine); query bus is synchronous (`Fetch`). Both recover
  from handler panics; `Shutdown()` drains via `sync.Once` + `WaitGroup`.
- DI: Google **Wire** builds a `container.Container` struct (`InitializeContainer()
  Container`). Add a dependency by adding a field to `Container`, a param to
  `NewContainer`, and a provider to `wire.Build`, then regenerate.
- HTTP: a `routes.Router` wrapper (`NewRouter()`, `.UseLogger()`, `.Serve()`) with
  one method per domain group (`router.Auth(...)`); Gin handlers live in
  `application/http/action/<domain>/` as closures returning `gin.HandlerFunc`;
  responses go through the `responder` JSend helpers; cross-cutting concerns are
  `middleware/`.
- Migrations: golang-migrate, `.up.sql`/`.down.sql` pairs under
  `infrastructure/database/migrations`, run on startup by `database.RunMigrations`
  (which also seeds). Logger is `log/slog` behind the `domain/logger.Logger`
  interface (JSON in production via `APP_ENV`, text otherwise).

**Wiring flow in `cmd/<app>/main.go`.**
`container.InitializeContainer()` → `database.RunMigrations` → register handlers
and listeners in `setupCommandHandlers` / `setupQueryHandlers` / `setupEventListeners`
(struct literals reading `container` fields) → `StartConsuming()` goroutines →
`configureServer` builds the router → graceful shutdown on SIGINT/SIGTERM calls
`CommandBus.Shutdown()` and `EventDispatcher.Shutdown()`. **Register every handler
before `StartConsuming()` is called.**

**Testing.** `stretchr/testify`; test names read `TestThatXReturnsY`. Domain,
responder, and query packages carry tests in the template.

## Condensed reference snippets

Concrete shapes for the conventions above. These are illustrative — the cloned repo
is the full, current source; consult it (or `carline`) rather than treating these as
canonical file contents.

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
	GetById(id ulid.ULID) (*<Entity>, error)
	GetAll(pageParams pagination.PageParams) (*pagination.Collection[<Entity>], error)
	Add(e *<Entity>) error
	Save(e *<Entity>) error
	Remove(e *<Entity>) error
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
	Logger           logger.Logger
	<Entity>Repository <entity>.Repository
	EventDispatcher  messaging.EventDispatcher
}

func (h Register<Entity>Handler) Handle(cmd messaging.Command) error {
	c, ok := cmd.(*command.Register<Entity>)
	if !ok {
		h.Logger.Error("invalid command type passed to Register<Entity>Handler", "command", cmd)
		return fmt.Errorf("invalid command type passed to Register<Entity>Handler: %v", cmd)
	}
	e := <entity>.Register(c.Id, c.Name)
	if err := h.<Entity>Repository.Add(e); err != nil {
		return fmt.Errorf("<entity> registration failed: %s", err)
	}
	h.EventDispatcher.Dispatch(&event.<Entity>Registered{Id: c.Id, Name: c.Name})
	return nil
}
```

**lib/pq repository method** (`infrastructure/repository/`):
```go
func NewPostgres<Entity>Repository(session *sql.DB, logger logger.Logger) <entity>.Repository {
	return &Postgres<Entity>Repository{session: session, logger: logger}
}

func (r *Postgres<Entity>Repository) GetById(id ulid.ULID) (*<entity>.<Entity>, error) {
	var e <entity>.<Entity>
	var i string
	q := `SELECT id, name, created_at, modified_at FROM <entity>s WHERE id = $1`
	if err := r.session.QueryRow(q, id.String()).Scan(&i, &e.Name, &e.CreatedAt, &e.ModifiedAt); err != nil {
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
//   repository.NewPostgres<Entity>Repository, messaging.NewChannelCommandBus,
//   messaging.NewSynchronousQueryBus, messaging.NewChannelEventDispatcher, ...)
```

**Register + serve in `main.go`:**
```go
commandBus.RegisterHandler(command.Register<Entity>{}.CommandName(), command_handler.Register<Entity>Handler{
	Logger:            c.Logger,
	<Entity>Repository: c.<Entity>Repository,
	EventDispatcher:   c.EventDispatcher,
})
// ...then: go c.CommandBus.StartConsuming(); go c.EventDispatcher.StartConsuming()
```

## Project layout

```
cmd/<app>/            main.go — container init, migrations, consumers, router, shutdown
cmd/seed/            optional standalone seeder
internal/<app>/
  domain/            pure types (no framework imports)
    <entity>/        entity struct + Repository interface
    password/ pagination/ logger/ ...   value objects + interfaces
  application/
    command/ command_handler/           grouped by domain, one file per layer
    query/   query_handler/
    event/   listener/
    http/action/<domain>/  http/middleware/  http/responder/   (Gin, JSend)
  infrastructure/
    container/       Wire Container struct (container.go + wire.go + wire_gen.go)
    database/        NewPostgresSession, RunMigrations, migrations/, seeders/
    repository/      database/sql + lib/pq implementations (return domain interface)
    messaging/       Channel command/event bus + synchronous query bus (interfaces)
    routes/          Router wrapper, one method per domain group
    logger/slog/     slog adapter for domain/logger.Logger
    service/         JWT / external service adapters
    websocket/       Hub (only if the service needs real-time)
Dockerfile  compose.yaml  bin/{up,down,exec}  .env.example  go.mod
```

## Adding to the service

Adding another command/query/event/route to an existing service is the
**`add-cqrs-feature`** skill — it encodes the same conventions with the exact
insertion points. Reach for it instead of re-deriving the pattern by hand.

## Dev commands & env

Everything runs in Docker via `bin/exec` (service name `go`):

```bash
bin/up                       # build + start (Postgres waits healthy)
bin/exec go test ./...       # tests
bin/exec go build ./...      # build
bin/down                     # stop
```

DB env (`.env`, see `.env.example`): `DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD`;
`APP_ENV` selects JSON vs text logging; `GIN_MODE`, `PORT`, `TOKEN_SECRET` as needed.
`session.go` uses `sslmode=disable` for local — set `DB_SSLMODE=require` style
handling before deploying to managed Postgres.
