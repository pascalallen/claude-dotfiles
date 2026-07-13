# claude-dotfiles

Global Claude Code configuration for Pascal Allen — installs architecture context and scaffold skills into `~/.claude/`.

## Who This Is For

These dotfiles are for Pascal Allen — senior software engineer at Crimson Drive Design LLC in Austin, TX. Go is the primary language; PHP (Symfony) is the secondary. Every project, regardless of stack, is built on DDD, hexagonal architecture, and CQRS. This repo encodes those decisions so Claude applies them consistently across all sessions without re-explanation.

## Philosophy

Every project I build follows the same architectural foundation: **Domain-Driven Design**, **hexagonal architecture**, **CQRS**, and **SOLID principles**. The stack varies (Go or PHP on the backend, React + TypeScript on the frontend), but the structural decisions don't. This repo encodes those decisions so Claude applies them consistently without being re-explained in every session.

Event sourcing is a deliberate non-default. I reach for it only when the domain has an explicit requirement for state history or event replay — not as a general pattern.

## Patterns

| Pattern | Applied When |
|--------|-------------|
| Domain-Driven Design | Always — domain layer is pure business logic with no framework imports |
| Hexagonal Architecture | Always — strict dependency direction: infrastructure → application → domain |
| CQRS | Always — commands mutate state, queries read it, never mixed |
| Repository Pattern | Always — infrastructure implements interfaces defined in the domain |
| DI Container | Always — Google Wire (Go) or Symfony DI (PHP) |
| Event Sourcing | Only when state history has explicit business value |
| Containerization | Always — everything runs in Docker, dev commands via `bin/exec` |
| DigitalOcean App Platform | Default deploy target — builds the Dockerfile from GitHub, managed Postgres |
| Kubernetes | Optional — `k8s-deploy` skill scaffolds manifests when a cluster is the target |

## Stack

**Backend (Go):** Go · Google Wire · Gin · PostgreSQL · `database/sql` + `lib/pq` (no ORM) · golang-migrate · JWT · native Go channels (messaging) · EventStoreDB + RabbitMQ (ES only)

**Backend (PHP):** PHP 8+ · Symfony (bare skeleton) · Doctrine ORM · PostgreSQL · JWT

**Frontend:** React · TypeScript (strict) · Vite · Axios · CSS Modules or Tailwind · NGINX

**Infrastructure:** Docker · Docker Compose · DigitalOcean App Platform (default) · Kubernetes (optional)

## Skills

| Skill | Trigger | Scaffolds |
|-------|---------|-----------|
| `new-go-service` | `/new-go-service` | Go microservice by cloning + renaming the `go-clean-arch` template: DDD + hexagonal + CQRS + Wire + Gin + `database/sql`/`lib/pq` + migrations + Docker |
| `add-cqrs-feature` | `/add-cqrs-feature` | Add a command/query/event+listener and optional HTTP route to an existing Go service, following the grouped-by-domain conventions |
| `new-php-service` | `/new-php-service` | PHP service: Symfony skeleton + DDD + hexagonal + CQRS + Doctrine + Docker |
| `new-react-app` | `/new-react-app` | React + TypeScript: Vite + Axios + ESLint/Prettier + Docker/NGINX |
| `k8s-deploy` | `/k8s-deploy` | Kubernetes manifests (Deployment, Service, ConfigMap, HPA) + deploy script |
| `event-sourcing` | `/event-sourcing` | Augments an existing Go service with EventStoreDB + RabbitMQ ES layer |

## Installation

```bash
git clone https://github.com/pascalallen/claude-dotfiles.git ~/projects/claude-dotfiles
cd ~/projects/claude-dotfiles
./install.sh
```

Restart Claude Code after installing. To uninstall:

```bash
./uninstall.sh
```

## Canonical Reference Repos

- [go-clean-arch](https://github.com/pascalallen/go-clean-arch) — DDD + CQRS + hexagonal in Go (standard CQRS, no ES)
- [es-go](https://github.com/pascalallen/es-go) — same patterns + event sourcing (EventStoreDB + RabbitMQ)
- [Astral](https://github.com/pascalallen/Astral) — DDD + CQRS + hexagonal in PHP (custom PSR-11 DI)

## Future Extensions

The first feature-level skill (`add-cqrs-feature`) now extends a scaffolded service surgically. Natural next additions: a DigitalOcean App Platform deploy skill (superseding/​complementing `k8s-deploy`), and aligning `new-react-app` with the Webpack + TanStack Query + Bootstrap frontend stack used in production.
