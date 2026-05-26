# Claude Global Config — Pascal Allen

## Who I Am

Senior software engineer and computer scientist at Crimson Drive Design LLC, Austin TX. Primary language is Go; PHP is my origin language. I write about Go architecture, distributed systems, and infrastructure on Medium. Calibrate all explanations to expert level — skip basics, no padding.

## Default Architecture

Every project uses DDD + hexagonal architecture + CQRS unless I say otherwise.

- **Domain layer** — pure business logic, zero framework or infrastructure imports. Contains: entities, aggregate roots, value objects, domain events, repository interfaces.
- **Application layer** — use case orchestration. Contains: command structs, command handlers, query structs, query handlers, event listeners.
- **Infrastructure layer** — all external integrations: HTTP, persistence, messaging, DI wiring.

Dependency direction is strict: infrastructure imports application and domain; domain imports nothing outside itself.

## Default Go Stack

- Language: Go
- DI: Google Wire (`wire.go` injector + generated `wire_gen.go`)
- HTTP: Gin
- Database: PostgreSQL
- DB access: `pgx` / raw SQL — no ORM in Go
- Auth: JWT
- Messaging (when needed): native Go channels (ChannelCommandBus + ChannelEventDispatcher)
- Event store (ES only): EventStoreDB
- Containerization: Docker + Compose
- Deployments: Kubernetes
- All dev commands run inside Docker via `bin/exec`
- Scripts always present: `bin/up`, `bin/down`, `bin/exec`

## Default PHP Stack

- Language: PHP 8+
- Framework: Symfony (bare skeleton — I impose my own structure on top)
- DI: Symfony DI container via `config/services.yaml`
- HTTP: Symfony controllers (thin — delegate to command bus)
- Database: PostgreSQL
- ORM: Doctrine
- Auth: JWT (LexikJWTAuthenticationBundle or equivalent)
- Containerization: Docker + Compose
- Deployments: Kubernetes
- All dev commands run inside Docker via `bin/exec`
- Scripts always present: `bin/up`, `bin/down`, `bin/exec`, `bin/composer`, `bin/phpunit`

## Default Frontend Stack

- Framework: React
- Language: TypeScript (strict mode)
- Build: Vite
- HTTP client: Axios
- Styling: CSS Modules (default) or Tailwind (if requested)
- Served in production via NGINX in Docker

## Event Sourcing — When to Reach For It

Event sourcing is **not** a default. Use it only when:
- State history has explicit business value (audit trail, temporal queries)
- The domain requires replaying events to reconstruct state
- Stakeholders need to query past states

When in doubt, use standard CQRS with PostgreSQL. The `event-sourcing` skill adds the ES layer additively on top of an existing Go service.

## Conventions

- Entity IDs: ULID (preferred over UUID)
- Stream IDs: `<entity>-{ulid}` (Go ES projects)
- Aggregate methods raise domain events internally — external code never instantiates domain events directly
- Optimistic concurrency via aggregate version (Go ES)
- Domain events carry `OccurredAt time.Time` (Go) / `\DateTimeImmutable $occurredAt` (PHP) set at raise-time
- Migrations: `database/` (Go) or `migrations/` (PHP)
- No ORM in Go — raw SQL via pgx
- `wire_gen.go` is generated — never edit by hand; run `wire` in the `cmd/<app>` directory to regenerate

## Canonical Reference Repos

- `pascalallen/go-clean-arch` — DDD + CQRS + hexagonal in Go (standard CQRS, no ES)
- `pascalallen/es-go` — DDD + CQRS + hexagonal + event sourcing in Go
- `pascalallen/Astral` — DDD + CQRS + hexagonal in PHP (custom PSR-11 DI, architecturally correct)
- `pascalallen/DockerLaravel` — Laravel boilerplate with React/TS frontend
- `pascalallen/DockerSymfony` — Symfony boilerplate

When uncertain about pattern application in Go, treat `go-clean-arch` and `es-go` as ground truth. For PHP, apply the same structural patterns onto a bare Symfony skeleton.
