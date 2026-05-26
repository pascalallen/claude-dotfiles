---
name: new-php-service
description: Scaffold a new PHP service using a bare Symfony skeleton with DDD, hexagonal architecture, CQRS, Doctrine ORM, and Docker
---

# New PHP Service

Scaffold a production-ready PHP microservice using a bare Symfony skeleton following Pascal Allen's canonical architecture. Reference: `pascalallen/Astral` (DDD/CQRS/hexagonal pattern) applied onto Symfony's foundation instead of a custom framework.

## Process

Ask the user:
1. **App name** (kebab-case, e.g. `order-service`) — used for directory names and Docker image name
2. **First domain entity name** (PascalCase, e.g. `Order`) — seeds the aggregate root, initial domain events, command/query pair, and Doctrine repository

Substitutions:
- `<app>` → app name as-is (e.g. `order-service`)
- `<entity>` → entity name lowercased (e.g. `order`)
- `<Entity>` → entity name PascalCase as provided (e.g. `Order`)

## Directory Structure to Generate

```
src/
  Domain/
    Event/
      <Entity>Registered.php
      EventInterface.php
    <Entity>/
      <Entity>.php
    Repository/
      <Entity>RepositoryInterface.php
  Application/
    Command/
      Register<Entity>.php
    CommandHandler/
      Register<Entity>Handler.php
    Query/
      Get<Entity>ById.php
    QueryHandler/
      Get<Entity>ByIdHandler.php
    Messaging/
      CommandBusInterface.php
      QueryBusInterface.php
  Infrastructure/
    Http/
      <Entity>Controller.php
    Persistence/
      Doctrine<Entity>Repository.php
    Messaging/
      SymfonyCommandBus.php
      SymfonyQueryBus.php
config/
  packages/
    doctrine.yaml
  routes/
    api.yaml
  services.yaml
migrations/
  (empty placeholder)
etc/
  nginx/
    default.conf
public/
  index.php
bin/
  up
  down
  exec
  composer
  phpunit
Dockerfile
docker-compose.yml
.env.example
phpunit.xml.dist
composer.json
CLAUDE.md
.gitignore
.github/
  workflows/
    php.yml
```

## File Templates

### `composer.json`
```json
{
    "name": "pascalallen/<app>",
    "type": "project",
    "require": {
        "php": ">=8.2",
        "symfony/framework-bundle": "^7.0",
        "symfony/dotenv": "^7.0",
        "symfony/flex": "^2",
        "symfony/runtime": "^7.0",
        "doctrine/orm": "^3.0",
        "doctrine/doctrine-bundle": "^2.11",
        "doctrine/doctrine-migrations-bundle": "^3.3",
        "lexik/jwt-authentication-bundle": "^3.0",
        "ramsey/uuid": "^4.7"
    },
    "require-dev": {
        "phpunit/phpunit": "^11.0",
        "symfony/test-pack": "^1.1"
    },
    "autoload": {
        "psr-4": { "App\\": "src/" }
    },
    "autoload-dev": {
        "psr-4": { "App\\Tests\\": "tests/" }
    }
}
```

### `src/Domain/Event/EventInterface.php`
```php
<?php

declare(strict_types=1);

namespace App\Domain\Event;

use DateTimeImmutable;

interface EventInterface
{
    public function eventName(): string;
    public function occurredAt(): DateTimeImmutable;
}
```

### `src/Domain/Event/<Entity>Registered.php`
```php
<?php

declare(strict_types=1);

namespace App\Domain\Event;

use DateTimeImmutable;

final class <Entity>Registered implements EventInterface
{
    public function __construct(
        public readonly string $<entity>Id,
        public readonly DateTimeImmutable $occurredAt,
    ) {}

    public function eventName(): string
    {
        return '<Entity>Registered';
    }

    public function occurredAt(): DateTimeImmutable
    {
        return $this->occurredAt;
    }
}
```

### `src/Domain/<Entity>/<Entity>.php`
```php
<?php

declare(strict_types=1);

namespace App\Domain\<Entity>;

use App\Domain\Event\EventInterface;
use App\Domain\Event\<Entity>Registered;
use DateTimeImmutable;

class <Entity>
{
    private string $id;
    private DateTimeImmutable $createdAt;
    private DateTimeImmutable $updatedAt;
    private ?DateTimeImmutable $deletedAt = null;

    /** @var EventInterface[] */
    private array $uncommittedEvents = [];

    private function __construct() {}

    public static function register(string $id): self
    {
        $entity = new self();
        $entity->raise(new <Entity>Registered(
            <entity>Id: $id,
            occurredAt: new DateTimeImmutable(),
        ));
        return $entity;
    }

    public function id(): string { return $this->id; }
    public function createdAt(): DateTimeImmutable { return $this->createdAt; }
    public function updatedAt(): DateTimeImmutable { return $this->updatedAt; }
    public function deletedAt(): ?DateTimeImmutable { return $this->deletedAt; }

    /** @return EventInterface[] */
    public function uncommittedEvents(): array { return $this->uncommittedEvents; }
    public function clearUncommittedEvents(): void { $this->uncommittedEvents = []; }

    private function raise(EventInterface $event): void
    {
        $this->applyEvent($event);
        $this->uncommittedEvents[] = $event;
    }

    private function applyEvent(EventInterface $event): void
    {
        match (true) {
            $event instanceof <Entity>Registered => $this->apply<Entity>Registered($event),
            default => null,
        };
    }

    private function apply<Entity>Registered(<Entity>Registered $event): void
    {
        $this->id = $event-><entity>Id;
        $this->createdAt = $event->occurredAt();
        $this->updatedAt = $event->occurredAt();
    }
}
```

### `src/Domain/Repository/<Entity>RepositoryInterface.php`
```php
<?php

declare(strict_types=1);

namespace App\Domain\Repository;

use App\Domain\<Entity>\<Entity>;

interface <Entity>RepositoryInterface
{
    public function save(<Entity> $<entity>): void;
    public function findById(string $id): ?<Entity>;
}
```

### `src/Application/Command/Register<Entity>.php`
```php
<?php

declare(strict_types=1);

namespace App\Application\Command;

final class Register<Entity>
{
    public function __construct(
        public readonly string $id,
    ) {}
}
```

### `src/Application/CommandHandler/Register<Entity>Handler.php`
```php
<?php

declare(strict_types=1);

namespace App\Application\CommandHandler;

use App\Application\Command\Register<Entity>;
use App\Domain\<Entity>\<Entity>;
use App\Domain\Repository\<Entity>RepositoryInterface;

final class Register<Entity>Handler
{
    public function __construct(
        private readonly <Entity>RepositoryInterface $repository,
    ) {}

    public function __invoke(Register<Entity> $command): void
    {
        $<entity> = <Entity>::register($command->id);
        $this->repository->save($<entity>);
        $<entity>->clearUncommittedEvents();
    }
}
```

### `src/Application/Query/Get<Entity>ById.php`
```php
<?php

declare(strict_types=1);

namespace App\Application\Query;

final class Get<Entity>ById
{
    public function __construct(
        public readonly string $id,
    ) {}
}
```

### `src/Application/QueryHandler/Get<Entity>ByIdHandler.php`
```php
<?php

declare(strict_types=1);

namespace App\Application\QueryHandler;

use App\Application\Query\Get<Entity>ById;
use App\Domain\<Entity>\<Entity>;
use App\Domain\Repository\<Entity>RepositoryInterface;
use RuntimeException;

final class Get<Entity>ByIdHandler
{
    public function __construct(
        private readonly <Entity>RepositoryInterface $repository,
    ) {}

    public function __invoke(Get<Entity>ById $query): <Entity>
    {
        $<entity> = $this->repository->findById($query->id);
        if ($<entity> === null) {
            throw new RuntimeException(sprintf('<Entity> not found: %s', $query->id));
        }
        return $<entity>;
    }
}
```

### `src/Infrastructure/Persistence/Doctrine<Entity>Repository.php`
```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Persistence;

use App\Domain\<Entity>\<Entity>;
use App\Domain\Repository\<Entity>RepositoryInterface;
use Doctrine\ORM\EntityManagerInterface;

final class Doctrine<Entity>Repository implements <Entity>RepositoryInterface
{
    public function __construct(
        private readonly EntityManagerInterface $em,
    ) {}

    public function save(<Entity> $<entity>): void
    {
        $this->em->persist($<entity>);
        $this->em->flush();
    }

    public function findById(string $id): ?<Entity>
    {
        return $this->em->find(<Entity>::class, $id);
    }
}
```

### `src/Infrastructure/Http/<Entity>Controller.php`
```php
<?php

declare(strict_types=1);

namespace App\Infrastructure\Http;

use App\Application\Command\Register<Entity>;
use App\Application\CommandHandler\Register<Entity>Handler;
use App\Application\Query\Get<Entity>ById;
use App\Application\QueryHandler\Get<Entity>ByIdHandler;
use Ramsey\Uuid\Uuid;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

#[Route('/api/v1/<entity>s')]
final class <Entity>Controller
{
    public function __construct(
        private readonly Register<Entity>Handler $register<Entity>Handler,
        private readonly Get<Entity>ByIdHandler $get<Entity>ByIdHandler,
    ) {}

    #[Route('', methods: ['POST'])]
    public function register(Request $request): JsonResponse
    {
        $id = Uuid::uuid4()->toString();
        ($this->register<Entity>Handler)(new Register<Entity>(id: $id));
        return new JsonResponse(['id' => $id], Response::HTTP_CREATED);
    }

    #[Route('/{id}', methods: ['GET'])]
    public function getById(string $id): JsonResponse
    {
        $<entity> = ($this->get<Entity>ByIdHandler)(new Get<Entity>ById(id: $id));
        return new JsonResponse(['id' => $<entity>->id()]);
    }
}
```

### `config/services.yaml`
```yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true

    App\:
        resource: '../src/'
        exclude:
            - '../src/Domain/'
            - '../src/Kernel.php'

    App\Domain\Repository\<Entity>RepositoryInterface:
        class: App\Infrastructure\Persistence\Doctrine<Entity>Repository
```

### `config/packages/doctrine.yaml`
```yaml
doctrine:
    dbal:
        url: '%env(resolve:DATABASE_URL)%'
    orm:
        auto_generate_proxy_classes: true
        naming_strategy: doctrine.orm.naming_strategy.underscore_number_aware
        auto_mapping: true
        mappings:
            App:
                is_bundle: false
                dir: '%kernel.project_dir%/src/Domain'
                prefix: 'App\Domain'
                alias: App
```

### `config/routes/api.yaml`
```yaml
controllers:
    resource:
        path: '../../src/Infrastructure/Http/'
        namespace: App\Infrastructure\Http
    type: attribute
```

### `Dockerfile`
```dockerfile
FROM php:8.2-fpm-alpine AS base
RUN apk add --no-cache postgresql-dev \
    && docker-php-ext-install pdo pdo_pgsql opcache
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-scripts --no-autoloader
COPY . .
RUN composer dump-autoload --optimize
EXPOSE 9000
CMD ["php-fpm"]
```

### `docker-compose.yml`
```yaml
services:
  app:
    build: .
    volumes:
      - .:/app
    env_file: .env
    depends_on:
      postgres:
        condition: service_healthy

  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./public:/app/public
      - ./etc/nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### `etc/nginx/default.conf`
```nginx
server {
    listen 80;
    root /app/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

### `.env.example`
```
APP_ENV=dev
APP_SECRET=change_me
DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?serverVersion=16&charset=utf8"
POSTGRES_DB=<app>
POSTGRES_USER=<app>
POSTGRES_PASSWORD=secret
```

### `bin/up`
```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose up --build "$@"
```

### `bin/down`
```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose down "$@"
```

### `bin/exec`
```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose exec app "$@"
```

### `bin/composer`
```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose exec app composer "$@"
```

### `bin/phpunit`
```bash
#!/usr/bin/env bash
set -euo pipefail
docker compose exec app ./vendor/bin/phpunit "$@"
```

Make all bin scripts executable: `chmod +x bin/up bin/down bin/exec bin/composer bin/phpunit`

### `phpunit.xml.dist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="vendor/autoload.php">
    <testsuites>
        <testsuite name="Project Test Suite">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>src</directory>
        </include>
    </source>
</phpunit>
```

### `CLAUDE.md` (project-level)
```markdown
# CLAUDE.md

## Overview

`<app>` is a PHP microservice using a bare Symfony skeleton with DDD, hexagonal architecture, and CQRS.

## Commands

```bash
bin/up                              # Build and start all containers
bin/down                            # Stop and remove containers
bin/exec php bin/console <cmd>      # Run Symfony console commands
bin/composer <cmd>                  # Run Composer commands
bin/phpunit                         # Run tests
```

## Architecture

```
src/
  Domain/              — pure PHP, zero Symfony/Doctrine imports
    Event/             — EventInterface + domain event classes
    <Entity>/          — aggregate root
    Repository/        — repository interfaces
  Application/
    Command/           — command classes
    CommandHandler/    — command handlers (invokable)
    Query/             — query classes
    QueryHandler/      — query handlers (invokable)
  Infrastructure/
    Http/              — Symfony controllers (thin, delegate to handlers)
    Persistence/       — Doctrine repository implementations
```

## Key Patterns

- `<Entity>::register()` is the only way to create an aggregate
- Aggregate methods raise domain events via `raise()` — external code never creates events
- Command handlers are invokable: `($handler)($command)`
- Domain layer has zero Symfony or Doctrine imports — pure PHP only
- `config/services.yaml` wires `<Entity>RepositoryInterface` → `Doctrine<Entity>Repository`
```

### `.gitignore`
```
.env
vendor/
var/
*.cache
```

### `.github/workflows/php.yml`
```yaml
name: PHP

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
      - run: composer install --prefer-dist --no-progress
      - run: ./vendor/bin/phpunit
```
