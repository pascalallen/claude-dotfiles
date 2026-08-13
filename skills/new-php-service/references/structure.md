# PHP Service Structure & Code Shapes

The DockerSymfony boilerplate provides the container/tooling shell. Impose this
structure on `src/` (PSR-4 `App\` → `src/`):

```
src/
  Domain/
    <Entity>/
      <Entity>.php                    entity + factory
    Event/
      EventInterface.php              eventName() + occurredAt()
      <Entity>Registered.php
    Repository/
      <Entity>RepositoryInterface.php
    Messaging/
      EventDispatcherInterface.php    port — implemented in Infrastructure
  Application/
    Command/Register<Entity>.php
    CommandHandler/Register<Entity>Handler.php   invokable
    Query/Get<Entity>ById.php
    QueryHandler/Get<Entity>ByIdHandler.php      invokable
    Listener/                         event listeners (react, chain commands)
  Infrastructure/
    Http/<Entity>Controller.php       thin, delegates to handlers
    Persistence/Doctrine<Entity>Repository.php
    Messaging/SymfonyEventDispatcher.php
config/
  doctrine/<Entity>.orm.xml           XML mapping — domain stays Doctrine-free
  services.yaml
migrations/
tests/                                mirrors src/
```

## Entity — plain, ULID id, no ES machinery

```php
<?php

declare(strict_types=1);

namespace App\Domain\<Entity>;

use DateTimeImmutable;
use Symfony\Component\Uid\Ulid;   // permitted: symfony/uid is a value-object lib, not framework coupling

final class <Entity>
{
    private ?DateTimeImmutable $modifiedAt = null;

    private function __construct(
        private readonly Ulid $id,
        private string $name,
        private readonly DateTimeImmutable $createdAt,
    ) {}

    public static function register(Ulid $id, string $name): self
    {
        return new self($id, $name, new DateTimeImmutable());
    }

    public function updateName(string $name): void
    {
        $this->name = $name;
        $this->modifiedAt = new DateTimeImmutable();
    }

    public function id(): Ulid { return $this->id; }
    public function name(): string { return $this->name; }
    public function createdAt(): DateTimeImmutable { return $this->createdAt; }
    public function modifiedAt(): ?DateTimeImmutable { return $this->modifiedAt; }
}
```

## Domain event

```php
final class <Entity>Registered implements EventInterface
{
    public function __construct(
        public readonly string $<entity>Id,
        public readonly DateTimeImmutable $occurredAt = new DateTimeImmutable(),
    ) {}

    public function eventName(): string { return '<Entity>Registered'; }
    public function occurredAt(): DateTimeImmutable { return $this->occurredAt; }
}
```

## Invokable command handler — dispatches the event after persistence

```php
final class Register<Entity>Handler
{
    public function __construct(
        private readonly <Entity>RepositoryInterface $repository,
        private readonly EventDispatcherInterface $eventDispatcher,
    ) {}

    public function __invoke(Register<Entity> $command): void
    {
        $<entity> = <Entity>::register($command->id, $command->name);
        $this->repository->save($<entity>);
        $this->eventDispatcher->dispatch(new <Entity>Registered(<entity>Id: (string) $command->id));
    }
}
```

Query handlers mirror this: `__invoke(Get<Entity>ById $query): ?<Entity>` via the
repository; return `null` on not-found and let the controller map it to a 404.

## Thin controller

```php
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
        $id = new Ulid();
        ($this->register<Entity>Handler)(new Register<Entity>(id: $id, name: /* validated payload */));
        return new JsonResponse(['id' => (string) $id], Response::HTTP_CREATED);
    }
}
```

## services.yaml wiring

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

    App\Domain\Messaging\EventDispatcherInterface:
        class: App\Infrastructure\Messaging\SymfonyEventDispatcher
```

## Doctrine XML mapping (`config/doctrine/<Entity>.orm.xml`)

Map the private fields; store the ULID as `CHAR(26)` (`ulid` type from
symfony/uid's Doctrine bridge, or a string column + embeddable). Point
doctrine.yaml's mapping at `%kernel.project_dir%/config/doctrine` with
`type: xml`, `prefix: App\Domain`.

## Project CLAUDE.md template

```markdown
# CLAUDE.md

`<app>` is a PHP service: bare Symfony skeleton + DDD + hexagonal + CQRS.

## Commands
bin/up · bin/down · bin/exec php bin/console <cmd> · bin/composer <cmd> · bin/phpunit

## Architecture
src/Domain — pure PHP, zero Symfony/Doctrine imports (mapping is XML in config/doctrine)
src/Application — commands, invokable handlers, queries, listeners
src/Infrastructure — controllers (thin), Doctrine repositories, messaging adapters

## Key patterns
- ULID ids (symfony/uid); `<Entity>::register()` factory; createdAt/modifiedAt timestamps
- Command handlers dispatch domain events after persistence via EventDispatcherInterface
- services.yaml binds Domain interfaces → Infrastructure implementations
```
