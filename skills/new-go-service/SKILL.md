---
name: new-go-service
description: Scaffold a new Go microservice with DDD, hexagonal architecture, and CQRS by cloning and renaming the canonical go-clean-arch template — Google Wire DI, Gin, database/sql + lib/pq (PostgreSQL), golang-migrate, synchronous in-process messaging, JWT, Docker. Use when creating a new Go service from scratch; use add-cqrs-feature to extend an existing one.
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
it to the new service, align it to current conventions, regenerate Wire, and
verify it builds.

> `carline` (`~/code/carline`) is the production app built on these conventions
> and is **authoritative where the two diverge** — consult it for richer examples
> (Stripe, WebSocket hub, multi-tenant scoping, refresh-token rotation) and for
> the current messaging pattern, but treat `go-clean-arch` as the base to clone.

**Before writing any code, read `references/conventions.md`** — it is the
authoritative statement of the conventions, with condensed code shapes.

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

## Align messaging to current conventions

The current pattern (carline, production) is **synchronous, in-process, map-based
buses** with `context.Context` threaded through every handler. If the cloned
template still ships the older channel-based buses (`ChannelCommandBus`,
`StartConsuming`, no `ctx` on handlers), port it before adding features:

1. Replace `infrastructure/messaging/` with the synchronous implementations in
   `references/conventions.md` (§ Messaging) — copy them from
   `~/code/carline/internal/carline/infrastructure/messaging/` when available.
2. Update handler/listener signatures to take `ctx context.Context` first.
3. In `main.go`: drop `StartConsuming()` goroutines and bus `Shutdown()` calls;
   registration functions stay as-is.
4. Update Wire providers to `NewSynchronousCommandBus` / `NewSynchronousQueryBus`
   / `NewSynchronousEventDispatcher` and regenerate.

## Verify (and Wire)

`wire_gen.go` is generated — never hand-edit it. The clone ships a valid
`wire_gen.go`, and the sed rename keeps it correct, so a straight rename needs no
regeneration. Pin the generator, tidy, and run the gate:

```bash
go get -tool github.com/google/wire/cmd/wire   # one-time: pins wire in go.mod's tool block
go mod tidy
go build ./...      # MUST pass
go test ./...       # MUST pass
```

Do not consider the scaffold done until `go build ./...` and `go test ./...` are
both green. (Locally you have Go directly; in the Docker flow use
`bin/exec go build ./...` after `bin/up`.)

**Regenerating Wire** (only after you change providers):

```bash
(cd internal/<app>/infrastructure/container && go tool wire)
```

> Use `go tool wire`, not a globally-installed `wire` binary: a `wire` built with
> an older Go toolchain refuses a newer module ("package requires newer Go
> version"). `go tool wire` builds the generator with the module's own toolchain.
> In Docker run it via `bin/exec` inside the Go container.

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
