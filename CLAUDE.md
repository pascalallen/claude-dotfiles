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

- DI: Google Wire (`wire.go` injector + generated `wire_gen.go` — never hand-edit; regenerate with `go generate` via the `//go:generate go run -mod=mod github.com/google/wire/cmd/wire` directive in `infrastructure/container/`; no `tool` directive in `go.mod`)
- HTTP: Gin, JSend responders, closure actions
- Database: PostgreSQL via `database/sql` + `lib/pq`, raw SQL — **no ORM**
- Migrations: golang-migrate `.up.sql`/`.down.sql` pairs in `internal/<app>/infrastructure/database/migrations/`, run at startup with seeders
- Messaging: **synchronous in-process buses** (`SynchronousCommandBus`/`QueryBus`/`EventDispatcher` behind `messaging` interfaces), `ctx` threaded through every handler; durable async work via `pascalallen/pgqueue` (Postgres-backed job queue behind a `DurableCommandBus`) when true background work exists — consequence: single-instance deploys
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
- No code comments; rationale goes in the PR body.
- Commits: one or two plain commits per PR, no `Co-Authored-By` trailer. PR body: what is in and out, deviations, what was checked, `Part of #N`, last line `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. One checklist item per PR.
- Decide technical calls by principles (DDD, hexagonal, CQRS, SOLID, RFCs); ask me only about scope or data, in plain words: situation, options, your pick.
- Private repos (see the private references below) are references for you only; never name them in a project's code, docs, issues or PRs.

## Agent Workflow

- One item per agent, from a brief file on disk that names the item, the evidence and the round values. Writers run in their own worktree (`isolation: worktree`) and open the PR; they never merge.
- Reviewers are read-only and refute-by-default: report only defects with a concrete failure scenario. Give them the PR, a diff file and the worktree, not my conclusion.
- Rolling waves: ≤4 writers, ≤2 reviewers; refill a slot when its PR merges. The orchestrator stays thin and reads summaries, not file dumps.
- Context is the cost: `/compact` or `/clear` past ~150k tokens; deterministic work is a script, large outputs go to files and are read in slices. On a usage limit or 429, stop and report.
- Templates: `code-writer` and `code-reviewer` in `~/.claude/agents/`; copy into a project's `.claude/agents/` and specialise once its rules exist.

## Project Hygiene

- Project `CLAUDE.md` holds stable rules only; area-specific rules go in a nested `CLAUDE.md` in that directory. Status lives in the GitHub epic plus `docs/build-log.md`, never in `CLAUDE.md`.
- Prefer a test, hook or CI check over a prose rule (layout → architecture test, routes → conformance test); delete the prose once the check exists.
- Decisions go in `docs/adr/`; the domain glossary in `CONTEXT.md`.
- Memory: one current handoff entry; delete superseded entries; fold durable lessons into `CLAUDE.md` or an agent definition.

## Skills

Procedure lives in skills, not here: `new-go-service` (scaffold), `add-cqrs-feature` (extend), `event-sourcing` (additive ES layer), `new-php-service`, `new-react-app`. Each skill's `references/` files are authoritative for code shapes.

## Canonical Reference Repos

Private references (untracked, local only): @~/.claude/private-references.md

- The production reference app (private; name and path in `~/.claude/private-references.md`, imported above; referred to as `$PROD_REF`) — **ground truth** for Go + React conventions; where it diverges from templates, it wins.
- `pascalallen/go-clean-arch` — the clean Go template the `new-go-service` skill clones
- `pascalallen/es-go` — DDD + CQRS + hexagonal + event sourcing in Go
- `pascalallen/pgqueue` — Postgres-backed durable job queue + NOTIFY/LISTEN pub/sub (the async default, as in production)
- `pascalallen/pubsub` — in-memory channel-based pub/sub library (no durability)
- `pascalallen/Astral` — DDD + CQRS + hexagonal pattern in PHP; `pascalallen/DockerSymfony` — the Symfony/Docker base the `new-php-service` skill clones
