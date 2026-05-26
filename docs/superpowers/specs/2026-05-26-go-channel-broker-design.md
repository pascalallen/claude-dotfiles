# Go Channel Message Broker Refactor

**Date:** 2026-05-26
**Status:** Approved

## Background

The claude-dotfiles repo defines reusable architecture patterns and scaffold skills for Pascal Allen's Go projects. The global CLAUDE.md listed RabbitMQ as the default messaging solution, and the `event-sourcing.md` skill replaced the base command bus with a `RabbitMqCommandBus` when event sourcing was added.

The carline project demonstrated that an external broker is unnecessary when all publishing and consuming happens within the same Go binary. Go channels provide async, in-process dispatch with zero infrastructure overhead, no serialization, and clean shutdown semantics via `sync.WaitGroup`. This refactor propagates that learning back into the dotfiles so all future scaffolded services start with the correct pattern.

---

## Scope

Three files change:

1. **`CLAUDE.md`** — update Default Go Stack messaging line
2. **`skills/new-go-service.md`** — replace sync CommandBus with ChannelCommandBus; add ChannelEventDispatcher; add domain Logger interface + slog implementation; wire everything via Google Wire
3. **`skills/event-sourcing.md`** — remove RabbitMQ command bus, compose service, env vars, and amqp dependency entirely

Out of scope: `skills/new-php-service.md`, `skills/k8s-deploy.md`, `skills/new-react-app.md`, README.

---

## Architecture

### Why Go channels instead of RabbitMQ

When all producers and consumers are in the same process:

**Before (RabbitMQ):**
```
Execute(cmd) → JSON-encode → AMQP publish → network → AMQP consume
             → JSON-decode → type-switch → handler.Handle(cmd)
```

**After (channels):**
```
Execute(cmd) → send Command interface to buffered channel
             → goroutine reads → handler.Handle(cmd)
```

No network, no serialization, no external container dependency. The `CommandBus` and `EventDispatcher` interfaces are unchanged — swapping in RabbitMQ later (e.g. for multi-service fan-out) requires no changes to callers.

### QueryBus stays synchronous

HTTP handlers call `queryBus.Fetch()` and must return results before writing a response. Making this async would require the caller to block on a result channel — semantically identical to synchronous, with added complexity. `SynchronousQueryBus` is correct by design.

### Trade-off: no durability

In-flight commands and events are lost on process restart. This is acceptable for all standard CQRS use cases covered by the scaffold. If durability becomes a requirement, the interfaces are unchanged — drop in NATS or RabbitMQ behind them without touching callers.

---

## Changes

### 1. `CLAUDE.md`

```diff
- - Messaging (when needed): RabbitMQ
+ - Messaging (when needed): native Go channels (ChannelCommandBus + ChannelEventDispatcher)
```

### 2. `skills/new-go-service.md`

#### New directory structure entries

```
internal/<app>/
  domain/
    logger/
      logger.go                      ← Logger port (domain interface)
  infrastructure/
    logger/
      slog/
        slog_logger.go               ← slog implementation of Logger
    messaging/
      command_bus.go                 ← ChannelCommandBus (replaces sync CommandBus)
      query_bus.go                   ← SynchronousQueryBus (takes Logger)
      event_dispatcher.go            ← ChannelEventDispatcher (new)
```

#### `domain/logger/logger.go`

Defines the `Logger` port used by the messaging layer. Identical to carline:

```go
type Logger interface {
    Debug(msg string, keyVals ...any)
    Info(msg string, keyVals ...any)
    Warn(msg string, keyVals ...any)
    Error(msg string, keyVals ...any)
    With(keyVals ...any) Logger
    WithContext(ctx context.Context) Logger
}
```

#### `infrastructure/logger/slog/slog_logger.go`

Wraps `*slog.Logger` and satisfies the domain `Logger` interface. Constructor: `NewSlogLogger() logger.Logger`.

#### `infrastructure/messaging/command_bus.go`

`ChannelCommandBus` — buffered channel of size 256 (`channelBufferSize` constant), `sync.Once` for safe `Shutdown`, `sync.WaitGroup` to drain before exit. Panics in handlers are recovered and logged.

```
RegisterHandler(commandType string, handler CommandHandler)
Execute(cmd Command) error        // sends to channel; non-blocking within buffer
StartConsuming()                  // blocking; run in goroutine
Shutdown()                        // closes channel; waits for drain
```

`Command` interface: `CommandName() string`.
`CommandHandler` interface: `Handle(cmd Command) error`.

#### `infrastructure/messaging/query_bus.go`

`SynchronousQueryBus` — direct dispatch, no channel. Logs dispatch and errors.

```
RegisterHandler(queryType string, handler QueryHandler)
Fetch(query Query) (any, error)
```

`Query` interface: `QueryName() string`.
`QueryHandler` interface: `Handle(query Query) (any, error)`.

#### `infrastructure/messaging/event_dispatcher.go`

`ChannelEventDispatcher` — same channel pattern as command bus.

```
RegisterListener(eventType string, listener Listener)
Dispatch(evt Event)               // sends to channel; non-blocking within buffer
StartConsuming()                  // blocking; run in goroutine
Shutdown()                        // closes channel; waits for drain
```

`Event` interface: `EventName() string`.
`Listener` interface: `Handle(event Event) error`.

Note: This `Event` interface in the messaging package is the **dispatch event** used for cross-aggregate fan-out. It is distinct from the domain events in `domain/event/` (which carry aggregate state changes). Do not conflate the two.

#### `cmd/<app>/main.go`

```go
func main() {
    router, cleanup, err := initializeRouter()
    // ...
    go commandBus.StartConsuming()
    go eventDispatcher.StartConsuming()
    // OS signal handling for graceful shutdown
    // commandBus.Shutdown(); eventDispatcher.Shutdown()
    router.Run(":8080")
}
```

`initializeRouter()` signature changes to return `(*gin.Engine, *messaging.ChannelCommandBus, *messaging.ChannelEventDispatcher, func(), error)`. Wire supports multiple return values from an injector function.

#### `cmd/<app>/wire.go`

`wire.Build` additions:

```go
sloglogger.NewSlogLogger,
wire.Bind(new(logger.Logger), new(*sloglogger.SlogLogger)),
messaging.NewChannelCommandBus,
messaging.NewSynchronousQueryBus,
messaging.NewChannelEventDispatcher,
```

#### `go.mod`

No new external dependencies. `log/slog` is stdlib (Go 1.21+). The `go` directive stays at `go 1.23`.

### 3. `skills/event-sourcing.md`

**Remove:**

- Entire `internal/<app>/infrastructure/messaging/command_bus.go` template block (the `RabbitMqCommandBus` replacement)
- `rabbitmq` service block from `compose.yaml additions`
- `RABBITMQ_*` vars from `.env.example additions`
- `github.com/rabbitmq/amqp091-go v1.11.0` from `go.mod` additions
- `NewAmqpConnection` wire provider from "Wire providers to add"
- All `amqp` imports and references

**Add note** under "What Gets Added or Modified":

> The channel command bus from the base scaffold is the async dispatch mechanism. No additional messaging infrastructure is required when adding event sourcing.

**Update skill description frontmatter:**

```diff
- description: Augment an existing Go service ... with EventStoreDB for persistence and RabbitMQ for async command dispatch
+ description: Augment an existing Go service ... with EventStoreDB for persistence and the existing channel command bus for async dispatch
```

---

## Verification

After implementation:

1. Invoke `new-go-service` skill on a fresh directory (app: `test-service`, entity: `Widget`)
2. `bin/up` — postgres and app containers start cleanly
3. `POST /api/v1/widgets` — HTTP handler fires command onto channel bus, returns 202
4. Container logs show command consumed by `StartConsuming` goroutine, handler executes, no panics
5. `bin/exec go test ./...` — `TestChannelCommandBus` and `TestChannelEventDispatcher` pass
6. `CTRL-C` — graceful shutdown drains channel buses before exit

---

## Not Changed

- `skills/new-php-service.md`
- `skills/k8s-deploy.md`
- `skills/new-react-app.md`
- `README.md`
- `.github/workflows/go.yml` (in generated services)
