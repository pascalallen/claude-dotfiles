---
name: new-php-service
description: Scaffold a new PHP service — bare Symfony skeleton with DDD, hexagonal architecture, CQRS, Doctrine, PostgreSQL, and Docker — by starting from the pascalallen/DockerSymfony boilerplate and imposing the canonical src/{Domain,Application,Infrastructure} structure. Use when creating a new PHP backend from scratch.
---

# New PHP Service

Scaffold a production-ready PHP service following Pascal Allen's canonical
architecture: the same DDD + hexagonal + CQRS structure as the Go services,
imposed on a bare Symfony skeleton. Structural reference: `pascalallen/Astral`
(the pattern) applied via `pascalallen/DockerSymfony` (the Docker/Symfony base).

## Source of truth: start from the living boilerplate

Do not hand-write Docker/nginx/composer plumbing from memory — clone
**`pascalallen/DockerSymfony`** and impose the domain structure on top:

```bash
git clone --depth 1 https://github.com/pascalallen/DockerSymfony <app>
cd <app>
rm -rf .git && git init
# rename the app: composer.json "name", compose service/image names, .env.example
```

The boilerplate owns: Dockerfile, compose file, nginx config, `bin/` scripts
(`up`, `down`, `exec`, `composer`, `phpunit`), phpunit config, and the Symfony
skeleton. This skill owns what the boilerplate can't give you: the DDD structure
and conventions. **Read `references/structure.md` before writing code** — it has
the target tree and the code shapes.

## Process

Ask the user:
1. **App name** (kebab-case, e.g. `order-service`) — directory, composer package
   `pascalallen/<app>`, Docker image name.
2. **First domain entity** (PascalCase, e.g. `Order`) — seeds the entity, initial
   event, command/query pair, and Doctrine repository.

Substitutions: `<app>` · `<entity>` (lowercase) · `<Entity>` (PascalCase).

## Conventions (mirror the Go services)

- **Layers**: `src/Domain` (pure PHP — zero Symfony/Doctrine imports),
  `src/Application` (commands, invokable handlers, queries, events, listeners),
  `src/Infrastructure` (controllers, Doctrine repositories, messaging adapters,
  DI config). Dependency direction is strict: Infrastructure → Application →
  Domain.
- **IDs are ULIDs** (`symfony/uid` `Ulid`), not UUIDs — same as the Go services.
- **Entities are simple**: public readonly-ish state via getters is fine, but no
  event-sourcing machinery (`raise`/`applyEvent`/version) — that pattern is
  ES-only. Factory `register()` constructor, `createdAt` +
  nullable `modifiedAt` timestamps (match the Go `CreatedAt`/`ModifiedAt`
  convention).
- **Handlers are invokable** (`($handler)($command)`) with constructor-injected
  dependencies; controllers are thin and delegate to handlers/buses — no business
  logic in controllers.
- **Domain events** are dispatched by command handlers after persistence (via an
  `EventDispatcherInterface` port), carry `\DateTimeImmutable $occurredAt` set at
  construction, and are named past-tense (`<Entity>Registered`).
- **Repository interfaces live in the Domain**; Doctrine implementations in
  Infrastructure. Keep the domain free of Doctrine imports — map entities via XML
  (`config/doctrine/*.orm.xml`), not attributes on domain classes.
- Migrations: `migrations/` via doctrine-migrations-bundle. Auth: JWT
  (LexikJWTAuthenticationBundle). PHP ≥ 8.2, strict types everywhere.
- DI wiring in `config/services.yaml`: autowire/autoconfigure, exclude
  `src/Domain`, bind each `Domain\...RepositoryInterface` to its Doctrine
  implementation.

## Verify

All dev commands run inside Docker via the `bin/` scripts:

```bash
bin/up                 # build + start (php-fpm, nginx, postgres)
bin/composer install
bin/exec php bin/console doctrine:migrations:migrate -n
bin/phpunit            # MUST pass
```

Do not consider the scaffold done until the containers are healthy, migrations
run, and PHPUnit is green. Add a project-level `CLAUDE.md` (template in
`references/structure.md`).

Once the service is green, apply the Claude Code kit with the
`claude-code-repo-setup` skill (it's Go-shaped by default — see its
"Non-Go backend" note for what to adapt).
