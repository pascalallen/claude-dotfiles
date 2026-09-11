# Claude Global Config — Pascal Allen

## Who I Am

Senior software engineer and computer scientist; founder of Crimson Drive Design LLC, Austin TX. Primary language is Go; PHP is my origin language. I build MCP servers in Go, author Claude Code skills, and write about Go architecture and distributed systems on Medium. Calibrate all explanations to expert level — skip basics, no padding.

## Default Architecture

Every project uses DDD + hexagonal architecture + CQRS unless I say otherwise.

- **Domain layer** — pure business logic, zero framework or infrastructure imports. Contains: entities, value objects, repository interfaces.
- **Application layer** — use case orchestration. Contains: command structs, command handlers, query structs, query handlers, events, event listeners.
- **Infrastructure layer** — all external integrations: HTTP, persistence, messaging, DI wiring.

Dependency direction is strict: infrastructure imports application and domain; domain imports nothing outside itself.

## Default Go Stack

- DI: Google Wire (`wire.go` injector + generated `wire_gen.go` — never hand-edit; regenerate via the container package's `//go:generate` directive (`go generate ./internal/<app>/infrastructure/container/...`); if the package has no directive, `(cd internal/<app>/infrastructure/container && go tool wire)`; either way confirm `wire_gen.go` actually changed with `git diff --stat`)
- HTTP: Gin, JSend responders, closure actions
- Database: PostgreSQL via `database/sql` + `lib/pq`, raw SQL — **no ORM**
- Migrations: golang-migrate `.up.sql`/`.down.sql` pairs in `internal/<app>/infrastructure/database/migrations/`, run at startup with seeders
- Messaging: **synchronous in-process buses** (`SynchronousCommandBus`/`QueryBus`/`EventDispatcher` behind `messaging` interfaces), `ctx` threaded through every handler; async only via the `pascalallen/pubsub` library when true background work exists — consequence: single-instance deploys
- Auth: JWT · Event store (ES only): EventStoreDB
- Docker + Compose; dev commands run inside Docker via `bin/exec`; `bin/up`, `bin/down`, `bin/exec` always present; **no Makefiles**

## Default PHP Stack

- PHP 8.2+, Symfony bare skeleton — I impose the same src/{Domain,Application,Infrastructure} structure on top
- DI: Symfony container via `config/services.yaml` (Domain interfaces bound to Infrastructure implementations)
- Thin controllers delegating to invokable handlers; Doctrine (XML mappings — domain stays framework-free); PostgreSQL; JWT (Lexik)
- Migrations: `migrations/`; Docker + `bin/up`, `bin/down`, `bin/exec`, `bin/composer`, `bin/phpunit`

## Default Frontend Stack

- React 19 + TypeScript (strict) + Webpack 5 + Yarn — not Vite
- TanStack Query for server state; axios behind a single ApiService; React Router v7
- Bootstrap 5 + react-bootstrap + `@pascalallen/react-form-components`; SCSS
- ESLint 9 flat config + Prettier (120 cols, single quotes); `@`-prefixed TS path aliases
- Custom observable stores for auth/client state — no Redux
- Default shape: lives in `web/app/` of the Go service, Webpack emits to `web/static/`, Go serves the template with runtime config injected as base64 JSON
- Jest + Testing Library for frontend tests; tests mock the service layer, never axios; `yarn lint && yarn typecheck && yarn test && yarn build` is the gate
- Frontend assets are read from disk by the Go binary (`web/template`, `web/static`); deploy ships them beside the binary

## Event Sourcing — Not a Default

Reach for ES only when state history has explicit business value (audit trail, replay, temporal queries). When in doubt, standard CQRS with PostgreSQL. The `event-sourcing` skill adds the ES layer — and owns all ES-only conventions (streams, raise/apply, versioned concurrency).

## Conventions

- Entity IDs: ULID (`oklog/ulid/v2` in Go, `symfony/uid` in PHP), stored as `CHAR(26)`
- Entities are plain structs/classes with a factory constructor and `CreatedAt` + nullable `ModifiedAt`; no ES machinery outside the `event-sourcing` skill
- Command handlers dispatch domain events via an injected `EventDispatcher` after persistence; events are named past-tense
- Commands/queries/events grouped by domain, one file per layer; handlers are structs with exported deps registered by struct literal in `main.go`
- Repositories: interface in the domain package, implementation in infrastructure returning the interface; not-found → `nil, nil`

## Working Principles

- A green test suite is not proof of correctness — verify behavior against real data and paths before declaring something fixed. Hunt for silent failures (wrong behavior with no error) first.
- Prove the mechanism of a bug before fixing it; no plausible-sounding patches.
- Tests: testify; plain descriptive test names with `t.Run` subtests that read as sentences. Build and tests must be green before reporting work done.
- Library-quality bar (as in `pubsub`/`hmac`): gofmt-clean, `go vet`, `go test -race -cover`, govulncheck in CI; semver + `/v2`-style module paths for libraries.
- Workflow: GitHub Issue → `feature/<issue#>-<slug>` branch → PR. I review and merge every PR myself — agents never merge.

## Claude Code Repo Conventions

Every repo commits `.claude/settings.json` (permissions + gofmt/prettier `PostToolUse` hooks), `.claude/rules/` (path-scoped), a project `verify` skill, and `.github/workflows/{ci,claude,claude-review}.yml`. `.claude/settings.local.json`, `.mcp.json`, and `CLAUDE.local.md` stay gitignored. Project CLAUDE.md files stay under 200 lines. The kit lives in `claude-dotfiles/claude-code/` and is applied by the `claude-code-repo-setup` skill, adapted per stack — see that skill (no `yarn` job/prettier hook without a frontend; this dotfiles repo itself carries only CI). When a convention changes in any repo, update this dotfiles repo in the same piece of work — it is not a follow-up task.

## Skills

Procedure lives in skills, not here: `new-go-service` (scaffold), `add-cqrs-feature` (extend), `event-sourcing` (additive ES layer), `new-php-service`, `new-react-app`, `claude-code-repo-setup` (project Claude Code kit). Each skill's `references/` files are authoritative for code shapes.

## Canonical Reference Repos

- `pascalallen/carline` — production SaaS (private; local at `~/code/carline`). **Ground truth** for Go + React conventions; where it diverges from templates, carline wins.
- `pascalallen/go-clean-arch` — the clean Go template the `new-go-service` skill clones
- `pascalallen/es-go` — DDD + CQRS + hexagonal + event sourcing in Go
- `pascalallen/pubsub` — channel-based pub/sub library (the async escape hatch)
- `pascalallen/Astral` — DDD + CQRS + hexagonal pattern in PHP; `pascalallen/DockerSymfony` — the Symfony/Docker base the `new-php-service` skill clones
