# Design: Align Go scaffold skills with real conventions

**Date:** 2026-07-13
**Repo:** `claude-dotfiles`
**Status:** Approved (approach) — pending spec review

## Problem

`skills/new-go-service.md` has drifted away from Pascal's actual Go conventions. It
was authored with an event-sourcing-flavored aggregate template that matches
*neither* of the two repos it claims as canonical (`go-clean-arch`, `carline`).
An audit of both repos shows they agree with each other and disagree with the
skill on every major dimension.

### Audit findings — skill vs. reality

| Dimension | Skill currently says | `carline` **and** `go-clean-arch` actually do |
|---|---|---|
| Domain entity | Private fields + getters; `uncommittedEvents`, `raise()`, `applyEvent()`, `version`; `Register` returns `(*E, error)` | Plain struct, **exported fields + JSON tags**, `Id ulid.ULID`; `Register(...)` returns `*E` (no error); mutators set fields + `ModifiedAt *time.Time`; **no event machinery** |
| Timestamps | `createdAt/updatedAt/deletedAt` | `CreatedAt time.Time`, `ModifiedAt *time.Time` |
| DB driver | `pgx/pgxpool` | `database/sql` + `lib/pq`; repo ctor returns the **domain interface**; logger injected; txns for multi-table writes; `nil,nil` on `sql.ErrNoRows` |
| Repository interface | Defined per-handler in `command_handler`/`query_handler` | Defined in the **domain package** (`user.Repository`) |
| Handlers | `NewRegisterXHandler(repo)` ctor; one file per command | **Struct literals with exported fields**; handlers **grouped by domain** (`command_handler/user.go`) |
| Commands/queries | One file per command | Grouped by domain (`command/user.go`) |
| DI | Wire returns a big **tuple** | Wire builds a `container.Container` **struct**; handlers wired in `main.go` via `setup*` funcs |
| Messaging | `*ChannelCommandBus` concrete; no interface; no `ExecuteSync` | `messaging.CommandBus/QueryBus/EventDispatcher` **interfaces**; ctor returns interface; bus has `Execute` (async) **and** `ExecuteSync` |
| Events | `domain/event` only | Dispatched **from command handlers** via injected `EventDispatcher`; listeners are structs in `listener/` |
| HTTP | Inline handlers in one `router.go` | `routes/` wrapper grouped by domain; actions in `http/action/<domain>/`; `responder/` (JSend) + `middleware/` |
| Migrations | none | golang-migrate, run on startup, + seeders |
| go.mod | go 1.23, wire 0.6, pgx, jwt/v5 | go 1.26, gin 1.11, wire 0.7, lib/pq, oklog/ulid v2.1.1, golang-migrate, testify |

### Secondary drift

- `README.md` stack table lists **"RabbitMQ (messaging)"** and **"Kubernetes | Deployments"** — but messaging is Go channels and carline deploys to **DigitalOcean App Platform**.
- `CLAUDE.md` claims **"DB access: pgx / raw SQL"** — but both repos ship `database/sql` + `lib/pq`.

## Root cause

The skill embedded a **full static copy** of every file, and that copy rotted.
Re-embedding corrected copies would rebuild the same drift machine.

## Approach

Three coordinated changes, scoped to Go + docs. Deploy and React skills are
explicitly deferred to separate passes.

### 1. Rewrite `new-go-service.md` — reference the living template

`go-clean-arch` is Pascal's maintained, canonical, standard-CQRS repo. It is a
complete scaffold: `internal/app/` with the full domain/application/infrastructure
layering, migrations, seeders, Wire `Container` struct, `bin/` scripts, Dockerfile,
compose, auth action. The skill will treat it as the **source of truth** rather
than embedding a competing copy.

New skill shape:

1. **Scaffold source** — clone/degit `pascalallen/go-clean-arch`, then rename:
   - module path `github.com/pascalallen/go-clean-arch` → `github.com/pascalallen/<app>`
   - package path `internal/app/` → `internal/<app>/`
   - `package app`? (it is `package app` under `internal/app`) → `<app>`
   - Re-run Wire, tidy modules.
2. **CONVENTIONS section** — the authoritative, copy-proof part. Encodes:
   entity style (plain struct, exported fields, ULID, `Register` factory, mutators
   + `ModifiedAt`), domain-owned repository interface, `database/sql`+`lib/pq` repo
   (interface-returning ctor, injected logger, txns, `nil,nil` on not-found),
   grouped-by-domain commands/queries/handlers, struct-literal handler wiring,
   Wire `Container` struct + `setup*` funcs in `main.go`, `messaging` interfaces
   (`Execute`/`ExecuteSync`), events dispatched from handlers + `listener/` structs,
   `routes/` wrapper + `http/action/<domain>/` + `responder/` (JSend) + `middleware/`,
   golang-migrate migrations run on startup, ULID IDs, JSON tags, testify +
   `TestThatXReturnsY` naming.
3. **Condensed reference snippets** — short, correct examples of the key shapes
   (entity, domain repo interface, lib/pq repo method, command + struct-literal
   handler, event + listener, Wire container fragment, route). Kept small: they
   make conventions concrete and survive an offline/unreachable-repo moment, but
   are explicitly **not** a full file-by-file copy.
4. **Verification gate** — `bin/exec go build ./...` and `bin/exec go test ./...`
   must pass before the skill is considered done.

**DB driver decision:** encode `database/sql` + `lib/pq` (what both repos ship).
The `pgx` line in `CLAUDE.md` is aspirational-but-false and gets corrected.

### 2. Add `add-cqrs-feature.md` — feature-level skill

Runs against an **existing** Go service (the shape `new-go-service` produced).
Adds, following grouped-by-domain conventions:

- a command struct (append to `command/<domain>.go`) + `CommandName()`
- a command handler struct (append to `command_handler/<domain>.go`) with exported
  deps, `Handle(cmd messaging.Command) error`, type-assert, optional event dispatch
- OR a query + query handler (`query/`, `query_handler/`) with `Handle(q messaging.Query) (any, error)`
- optional domain event (`event/`) + listener (`listener/`)
- register the handler/listener in `main.go` `setup*` funcs (add a `container` field
  + a `RegisterHandler` line)
- optional route in `routes/<domain>.go` + `http/action/<domain>/`
- reminders: regenerate Wire if a new provider/dep was added; verify build + tests.

The skill encodes the checklist and the exact insertion points, with condensed
snippets mirrored from `go-clean-arch`/`carline`.

### 3. Fix stale docs

- `README.md`: stack table — replace "RabbitMQ (messaging)" with "native Go channels";
  reframe deploy row from "Kubernetes" to "DigitalOcean App Platform (Kubernetes optional)";
  add `add-cqrs-feature` to the skills table; correct DB driver mention.
- `CLAUDE.md`: change "DB access: pgx / raw SQL — no ORM" to
  "`database/sql` + `lib/pq` / raw SQL — no ORM"; keep RabbitMQ already-removed state
  consistent; note deploy target is DO App Platform (k8s is optional/legacy).

## Deferred (separate passes)

- **Deploy skill:** `k8s-deploy` is stale vs. the real DO App Platform deploy
  (`.do/app.yaml`, single-instance constraint, `doctl`, secrets-wipe gotcha). Its own
  scoped skill later.
- **React skill:** `new-react-app` scaffolds Vite/Axios/CSS-Modules; carline FE is
  Webpack/React 19/TanStack Query/Bootstrap/custom AuthStore. Large, orthogonal rewrite.

## Testing / no-regressions plan

1. `go-clean-arch` (the template) builds and tests green — establishes the baseline.
2. Dry-run `new-go-service`: scaffold a throwaway `<app>` into the scratchpad
   following the skill exactly (clone + rename), run `go build ./...` and
   `go test ./...`. Must be green.
3. Dry-run `add-cqrs-feature` against that throwaway service: add one command+handler
   and one query+handler, rebuild + retest. Must be green.
4. Proofread README/CLAUDE.md against actual `go.mod`/deploy reality — no false claims.

## Out of scope

- Migrating any repo to `pgx`.
- Any change to `carline` or `go-clean-arch` themselves.
- `event-sourcing.md`, `new-php-service.md` (unaffected by this pass).

## Git / workflow

Work lands in `claude-dotfiles`. Branch → commit → PR (no GH issue needed for this
repo); Pascal reviews/merges.
