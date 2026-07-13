# Go Channel Message Broker Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace RabbitMQ with native Go channel-based messaging across `CLAUDE.md` and scaffold skills, then verify with a scaffolded test service.

**Architecture:** `ChannelCommandBus` and `ChannelEventDispatcher` use buffered Go channels (size 256) with `StartConsuming`/`Shutdown` lifecycle. `SynchronousQueryBus` stays synchronous (HTTP handlers need results before responding). All messaging types take a domain `Logger` interface backed by a `slog` implementation wired via Google Wire.

**Tech Stack:** Go 1.23, `log/slog` (stdlib), Google Wire, Gin, pgx, Docker Compose

---

## Task 1: Update CLAUDE.md messaging line

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Make the edit**

In `CLAUDE.md`, find and replace the messaging line:

```
- Messaging (when needed): RabbitMQ
```

Replace with:

```
- Messaging (when needed): native Go channels (ChannelCommandBus + ChannelEventDispatcher)
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "feat: update messaging stack from RabbitMQ to native Go channels"
```

---

## Task 2: Update directory structure in new-go-service.md

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Replace the directory structure block**

Find the `## Directory Structure to Generate` section. Replace the current `internal/<app>/` subtree (everything under it, up to the `Dockerfile` line) with:

```
internal/<app>/
  domain/
    event/
      <entity>.go
    logger/
      logger.go
    <entity>/
      <entity>.go
  application/
    command/
      register_<entity>.go
    command_handler/
      register_<entity>_handler.go
    query/
      get_<entity>_by_id.go
    query_handler/
      get_<entity>_by_id_handler.go
  infrastructure/
    http/
      router.go
    logger/
      slog/
        slog_logger.go
    messaging/
      command_bus.go
      event_dispatcher.go
      messaging_test.go
      query_bus.go
    storage/
      postgres_<entity>_repository.go
```

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): add logger + event dispatcher dirs to scaffold structure"
```

---

## Task 3: Add domain logger interface template

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Add template section**

After the `### \`internal/<app>/domain/event/<entity>.go\`` section, insert a new section:

````markdown
### `internal/<app>/domain/logger/logger.go`
```go
package logger

import "context"

type Logger interface {
	Debug(msg string, keyVals ...any)
	Info(msg string, keyVals ...any)
	Warn(msg string, keyVals ...any)
	Error(msg string, keyVals ...any)
	With(keyVals ...any) Logger
	WithContext(ctx context.Context) Logger
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): add domain Logger interface template"
```

---

## Task 4: Add slog logger implementation template

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Add template section**

After the `### \`internal/<app>/domain/logger/logger.go\`` section, insert:

````markdown
### `internal/<app>/infrastructure/logger/slog/slog_logger.go`
```go
package sloglogger

import (
	"context"
	"log/slog"
	"os"

	"github.com/pascalallen/<app>/internal/<app>/domain/logger"
)

type SlogLogger struct {
	l *slog.Logger
}

func NewSlogLogger() *SlogLogger {
	return &SlogLogger{l: slog.New(slog.NewJSONHandler(os.Stdout, nil))}
}

func (s *SlogLogger) Debug(msg string, keyVals ...any) { s.l.Debug(msg, keyVals...) }
func (s *SlogLogger) Info(msg string, keyVals ...any)  { s.l.Info(msg, keyVals...) }
func (s *SlogLogger) Warn(msg string, keyVals ...any)  { s.l.Warn(msg, keyVals...) }
func (s *SlogLogger) Error(msg string, keyVals ...any) { s.l.Error(msg, keyVals...) }

func (s *SlogLogger) With(keyVals ...any) logger.Logger {
	return &SlogLogger{l: s.l.With(keyVals...)}
}

func (s *SlogLogger) WithContext(_ context.Context) logger.Logger {
	return s
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): add slog Logger implementation template"
```

---

## Task 5: Add messaging test template (TDD — write tests first)

**Files:**
- Modify: `skills/new-go-service.md`

The test file uses local test-only types so it has no dependency on concrete command/event packages and exercises the channel buses in isolation.

- [ ] **Step 1: Add template section**

After the `### \`internal/<app>/domain/logger/logger.go\`` section (before the command_bus template), insert:

````markdown
### `internal/<app>/infrastructure/messaging/messaging_test.go`
```go
package messaging

import (
	"context"
	"testing"
	"time"

	"github.com/pascalallen/<app>/internal/<app>/domain/logger"
)

type mockLogger struct{}

func (m *mockLogger) Debug(msg string, keyVals ...any)            {}
func (m *mockLogger) Info(msg string, keyVals ...any)             {}
func (m *mockLogger) Warn(msg string, keyVals ...any)             {}
func (m *mockLogger) Error(msg string, keyVals ...any)            {}
func (m *mockLogger) With(keyVals ...any) logger.Logger           { return m }
func (m *mockLogger) WithContext(_ context.Context) logger.Logger { return m }

type testCmd struct{ name string }

func (c *testCmd) CommandName() string { return c.name }

type testEvent struct{ name string }

func (e *testEvent) EventName() string { return e.name }

type mockHandler struct{ fn func(cmd Command) error }

func (m *mockHandler) Handle(cmd Command) error { return m.fn(cmd) }

type mockListener struct{ fn func(evt Event) error }

func (m *mockListener) Handle(evt Event) error { return m.fn(evt) }

func TestChannelCommandBus(t *testing.T) {
	bus := NewChannelCommandBus(&mockLogger{})

	done := make(chan bool, 1)
	bus.RegisterHandler("test.cmd", &mockHandler{fn: func(cmd Command) error {
		if cmd.CommandName() == "test.cmd" {
			done <- true
		}
		return nil
	}})

	go bus.StartConsuming()

	if err := bus.Execute(&testCmd{name: "test.cmd"}); err != nil {
		t.Fatalf("Execute: %v", err)
	}

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for command handler")
	}

	bus.Shutdown()
}

func TestChannelEventDispatcher(t *testing.T) {
	dispatcher := NewChannelEventDispatcher(&mockLogger{})

	done := make(chan bool, 1)
	dispatcher.RegisterListener("test.event", &mockListener{fn: func(evt Event) error {
		if evt.EventName() == "test.event" {
			done <- true
		}
		return nil
	}})

	go dispatcher.StartConsuming()

	dispatcher.Dispatch(&testEvent{name: "test.event"})

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for event listener")
	}

	dispatcher.Shutdown()
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): add messaging test template (TDD)"
```

---

## Task 6: Replace command_bus.go template with ChannelCommandBus

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Replace the command_bus.go template**

Find the `### \`internal/<app>/infrastructure/messaging/command_bus.go\`` section. Replace the entire code block with:

````markdown
### `internal/<app>/infrastructure/messaging/command_bus.go`
```go
package messaging

import (
	"sync"

	"github.com/pascalallen/<app>/internal/<app>/domain/logger"
)

type Command interface {
	CommandName() string
}

type CommandHandler interface {
	Handle(cmd Command) error
}

const channelBufferSize = 256

type ChannelCommandBus struct {
	ch       chan Command
	handlers map[string]CommandHandler
	logger   logger.Logger
	once     sync.Once
	wg       sync.WaitGroup
}

func NewChannelCommandBus(log logger.Logger) *ChannelCommandBus {
	return &ChannelCommandBus{
		ch:       make(chan Command, channelBufferSize),
		handlers: make(map[string]CommandHandler),
		logger:   log,
	}
}

func (b *ChannelCommandBus) RegisterHandler(commandType string, handler CommandHandler) {
	b.logger.Info("registering command handler", "commandType", commandType)
	b.handlers[commandType] = handler
}

func (b *ChannelCommandBus) Execute(cmd Command) error {
	b.logger.Info("executing command", "commandName", cmd.CommandName())
	b.ch <- cmd
	return nil
}

func (b *ChannelCommandBus) StartConsuming() {
	b.logger.Info("starting command bus consumption")
	b.wg.Add(1)
	defer b.wg.Done()
	for cmd := range b.ch {
		b.processCommand(cmd)
	}
}

func (b *ChannelCommandBus) Shutdown() {
	b.once.Do(func() { close(b.ch) })
	b.wg.Wait()
}

func (b *ChannelCommandBus) processCommand(cmd Command) {
	defer func() {
		if r := recover(); r != nil {
			b.logger.Error("panic in command handler", "panic", r, "commandType", cmd.CommandName())
		}
	}()

	b.logger.Info("processing command", "commandType", cmd.CommandName())

	handler, found := b.handlers[cmd.CommandName()]
	if !found {
		b.logger.Warn("no handler registered", "commandType", cmd.CommandName())
		return
	}

	if err := handler.Handle(cmd); err != nil {
		b.logger.Error("command handler error", "error", err, "commandType", cmd.CommandName())
	}
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): replace sync CommandBus with ChannelCommandBus template"
```

---

## Task 7: Update query_bus.go template to SynchronousQueryBus

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Replace the query_bus.go template**

Find the `### \`internal/<app>/infrastructure/messaging/query_bus.go\`` section. Replace the entire code block with:

````markdown
### `internal/<app>/infrastructure/messaging/query_bus.go`
```go
package messaging

import (
	"fmt"

	"github.com/pascalallen/<app>/internal/<app>/domain/logger"
)

type Query interface {
	QueryName() string
}

type QueryHandler interface {
	Handle(query Query) (any, error)
}

type SynchronousQueryBus struct {
	handlers map[string]QueryHandler
	logger   logger.Logger
}

func NewSynchronousQueryBus(log logger.Logger) *SynchronousQueryBus {
	return &SynchronousQueryBus{
		handlers: make(map[string]QueryHandler),
		logger:   log,
	}
}

func (b *SynchronousQueryBus) RegisterHandler(queryType string, handler QueryHandler) {
	b.logger.Info("registering query handler", "queryType", queryType)
	b.handlers[queryType] = handler
}

func (b *SynchronousQueryBus) Fetch(query Query) (any, error) {
	b.logger.Info("fetching query", "queryName", query.QueryName())
	handler, found := b.handlers[query.QueryName()]
	if !found {
		return nil, fmt.Errorf("no handler registered for query type: %s", query.QueryName())
	}
	results, err := handler.Handle(query)
	if err != nil {
		b.logger.Error("query handler error", "error", err, "queryType", query.QueryName())
		return nil, fmt.Errorf("query handler error: %w", err)
	}
	return results, nil
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update QueryBus to SynchronousQueryBus with logger template"
```

---

## Task 8: Add event_dispatcher.go template

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Add template section**

After the `query_bus.go` template section, insert:

````markdown
### `internal/<app>/infrastructure/messaging/event_dispatcher.go`
```go
package messaging

import (
	"sync"

	"github.com/pascalallen/<app>/internal/<app>/domain/logger"
)

// Event is the dispatch interface used for cross-aggregate fan-out.
// It is distinct from domain/event types which carry aggregate state changes.
type Event interface {
	EventName() string
}

type Listener interface {
	Handle(event Event) error
}

type ChannelEventDispatcher struct {
	ch        chan Event
	listeners map[string]Listener
	logger    logger.Logger
	once      sync.Once
	wg        sync.WaitGroup
}

func NewChannelEventDispatcher(log logger.Logger) *ChannelEventDispatcher {
	return &ChannelEventDispatcher{
		ch:        make(chan Event, channelBufferSize),
		listeners: make(map[string]Listener),
		logger:    log,
	}
}

func (e *ChannelEventDispatcher) RegisterListener(eventType string, listener Listener) {
	e.logger.Info("registering event listener", "eventType", eventType)
	e.listeners[eventType] = listener
}

func (e *ChannelEventDispatcher) Dispatch(evt Event) {
	e.logger.Info("dispatching event", "eventName", evt.EventName())
	e.ch <- evt
}

func (e *ChannelEventDispatcher) StartConsuming() {
	e.logger.Info("starting event dispatcher consumption")
	e.wg.Add(1)
	defer e.wg.Done()
	for evt := range e.ch {
		e.processEvent(evt)
	}
}

func (e *ChannelEventDispatcher) Shutdown() {
	e.once.Do(func() { close(e.ch) })
	e.wg.Wait()
}

func (e *ChannelEventDispatcher) processEvent(evt Event) {
	defer func() {
		if r := recover(); r != nil {
			e.logger.Error("panic in event listener", "panic", r, "eventType", evt.EventName())
		}
	}()

	e.logger.Info("processing event", "eventType", evt.EventName())

	listener, found := e.listeners[evt.EventName()]
	if !found {
		e.logger.Warn("no listener registered", "eventType", evt.EventName())
		return
	}

	if err := listener.Handle(evt); err != nil {
		e.logger.Error("event listener error", "error", err, "eventType", evt.EventName())
	}
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): add ChannelEventDispatcher template"
```

---

## Task 9: Update command struct — add CommandName()

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Replace the command struct template**

Find the `### \`internal/<app>/application/command/register_<entity>.go\`` section. Replace with:

````markdown
### `internal/<app>/application/command/register_<entity>.go`
```go
package command

type Register<Entity> struct {
	Id string
}

func (c Register<Entity>) CommandName() string { return "Register<Entity>" }
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): add CommandName() to Register<Entity> command template"
```

---

## Task 10: Update query struct — add QueryName()

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Replace the query struct template**

Find the `### \`internal/<app>/application/query/get_<entity>_by_id.go\`` section. Replace with:

````markdown
### `internal/<app>/application/query/get_<entity>_by_id.go`
```go
package query

type Get<Entity>ById struct {
	Id string
}

func (q Get<Entity>ById) QueryName() string { return "Get<Entity>ById" }
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): add QueryName() to Get<Entity>ById query template"
```

---

## Task 11: Update command handler — Handle(messaging.Command)

**Files:**
- Modify: `skills/new-go-service.md`

The handler imports `infrastructure/messaging` for the `Command` interface. This is a pragmatic application→infrastructure import that matches the carline reference implementation; the interface is structural so the dependency is shallow.

- [ ] **Step 1: Replace the command handler template**

Find the `### \`internal/<app>/application/command_handler/register_<entity>_handler.go\`` section. Replace the entire code block with:

````markdown
### `internal/<app>/application/command_handler/register_<entity>_handler.go`
```go
package command_handler

import (
	"context"
	"fmt"

	"github.com/pascalallen/<app>/internal/<app>/application/command"
	<entity>domain "github.com/pascalallen/<app>/internal/<app>/domain/<entity>"
	"github.com/pascalallen/<app>/internal/<app>/infrastructure/messaging"
)

type <Entity>Repository interface {
	Save(ctx context.Context, e *<entity>domain.<Entity>) error
	FindById(ctx context.Context, id string) (*<entity>domain.<Entity>, error)
}

type Register<Entity>Handler struct {
	repo <Entity>Repository
}

func NewRegister<Entity>Handler(repo <Entity>Repository) *Register<Entity>Handler {
	return &Register<Entity>Handler{repo: repo}
}

func (h *Register<Entity>Handler) Handle(cmd messaging.Command) error {
	c, ok := cmd.(*command.Register<Entity>)
	if !ok {
		return fmt.Errorf("unexpected command type: %T", cmd)
	}
	e, err := <entity>domain.Register(c.Id)
	if err != nil {
		return fmt.Errorf("registering <entity>: %w", err)
	}
	if err := h.repo.Save(context.Background(), e); err != nil {
		return fmt.Errorf("saving <entity>: %w", err)
	}
	e.ClearUncommittedEvents()
	return nil
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update Register<Entity>Handler to implement messaging.CommandHandler"
```

---

## Task 12: Update query handler — Handle(messaging.Query)

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Replace the query handler template**

Find the `### \`internal/<app>/application/query_handler/get_<entity>_by_id_handler.go\`` section. Replace the entire code block with:

````markdown
### `internal/<app>/application/query_handler/get_<entity>_by_id_handler.go`
```go
package query_handler

import (
	"context"
	"fmt"

	"github.com/pascalallen/<app>/internal/<app>/application/query"
	<entity>domain "github.com/pascalallen/<app>/internal/<app>/domain/<entity>"
	"github.com/pascalallen/<app>/internal/<app>/infrastructure/messaging"
)

type Get<Entity>Repository interface {
	FindById(ctx context.Context, id string) (*<entity>domain.<Entity>, error)
}

type Get<Entity>ByIdHandler struct {
	repo Get<Entity>Repository
}

func NewGet<Entity>ByIdHandler(repo Get<Entity>Repository) *Get<Entity>ByIdHandler {
	return &Get<Entity>ByIdHandler{repo: repo}
}

func (h *Get<Entity>ByIdHandler) Handle(q messaging.Query) (any, error) {
	qry, ok := q.(query.Get<Entity>ById)
	if !ok {
		return nil, fmt.Errorf("unexpected query type: %T", q)
	}
	e, err := h.repo.FindById(context.Background(), qry.Id)
	if err != nil {
		return nil, fmt.Errorf("fetching <entity> by id %s: %w", qry.Id, err)
	}
	return e, nil
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update Get<Entity>ByIdHandler to implement messaging.QueryHandler"
```

---

## Task 13: Update router.go — dispatch via buses

**Files:**
- Modify: `skills/new-go-service.md`

The router takes buses (not concrete handlers) and generates a ULID for each POST. The GET endpoint dispatches through the query bus.

- [ ] **Step 1: Replace the router template**

Find the `### \`internal/<app>/infrastructure/http/router.go\`` section. Replace the entire code block with:

````markdown
### `internal/<app>/infrastructure/http/router.go`
```go
package http

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/oklog/ulid/v2"
	"github.com/pascalallen/<app>/internal/<app>/application/command"
	"github.com/pascalallen/<app>/internal/<app>/application/query"
	"github.com/pascalallen/<app>/internal/<app>/infrastructure/messaging"
)

func NewRouter(
	commandBus *messaging.ChannelCommandBus,
	queryBus *messaging.SynchronousQueryBus,
) *gin.Engine {
	r := gin.Default()

	v1 := r.Group("/api/v1")
	{
		v1.POST("/<entity>s", func(c *gin.Context) {
			id := ulid.Make().String()
			if err := commandBus.Execute(&command.Register<Entity>{Id: id}); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusAccepted, gin.H{"id": id})
		})
		v1.GET("/<entity>s/:id", func(c *gin.Context) {
			result, err := queryBus.Fetch(query.Get<Entity>ById{Id: c.Param("id")})
			if err != nil {
				c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, result)
		})
	}

	return r
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update router to dispatch through command/query buses"
```

---

## Task 14: Update main.go — goroutines + graceful shutdown

**Files:**
- Modify: `skills/new-go-service.md`

`initializeRouter` now returns buses and handlers so `main` can register handlers before starting consumers.

- [ ] **Step 1: Replace the main.go template**

Find the `### \`cmd/<app>/main.go\`` section. Replace with:

````markdown
### `cmd/<app>/main.go`
```go
package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/pascalallen/<app>/internal/<app>/application/command"
	"github.com/pascalallen/<app>/internal/<app>/application/query"
)

func main() {
	ctx := context.Background()
	router, commandBus, queryBus, eventDispatcher, register<Entity>Handler, get<Entity>ByIdHandler, cleanup, err := initializeRouter(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer cleanup()

	commandBus.RegisterHandler(command.Register<Entity>{}.CommandName(), register<Entity>Handler)
	queryBus.RegisterHandler(query.Get<Entity>ById{}.QueryName(), get<Entity>ByIdHandler)

	go commandBus.StartConsuming()
	go eventDispatcher.StartConsuming()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		if err := router.Run(":8080"); err != nil {
			log.Printf("router stopped: %v", err)
		}
	}()

	<-quit
	log.Println("shutting down...")
	commandBus.Shutdown()
	eventDispatcher.Shutdown()
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update main.go with goroutines and graceful shutdown"
```

---

## Task 15: Update wire.go — logger + new messaging providers

**Files:**
- Modify: `skills/new-go-service.md`

`initializeRouter` now takes `context.Context` and returns buses and handlers in addition to the router.

- [ ] **Step 1: Replace the wire.go template**

Find the `### \`cmd/<app>/wire.go\`` section. Replace with:

````markdown
### `cmd/<app>/wire.go`
```go
//go:build wireinject

package main

import (
	"context"

	"github.com/gin-gonic/gin"
	"github.com/google/wire"
	"github.com/pascalallen/<app>/internal/<app>/application/command_handler"
	"github.com/pascalallen/<app>/internal/<app>/application/query_handler"
	"github.com/pascalallen/<app>/internal/<app>/domain/logger"
	apphttp "github.com/pascalallen/<app>/internal/<app>/infrastructure/http"
	sloglogger "github.com/pascalallen/<app>/internal/<app>/infrastructure/logger/slog"
	"github.com/pascalallen/<app>/internal/<app>/infrastructure/messaging"
	"github.com/pascalallen/<app>/internal/<app>/infrastructure/storage"
)

func initializeRouter(ctx context.Context) (
	*gin.Engine,
	*messaging.ChannelCommandBus,
	*messaging.SynchronousQueryBus,
	*messaging.ChannelEventDispatcher,
	*command_handler.Register<Entity>Handler,
	*query_handler.Get<Entity>ByIdHandler,
	func(),
	error,
) {
	wire.Build(
		storage.NewPool,
		storage.NewPostgres<Entity>Repository,
		wire.Bind(new(command_handler.<Entity>Repository), new(*storage.Postgres<Entity>Repository)),
		wire.Bind(new(query_handler.Get<Entity>Repository), new(*storage.Postgres<Entity>Repository)),
		sloglogger.NewSlogLogger,
		wire.Bind(new(logger.Logger), new(*sloglogger.SlogLogger)),
		messaging.NewChannelCommandBus,
		messaging.NewSynchronousQueryBus,
		messaging.NewChannelEventDispatcher,
		command_handler.NewRegister<Entity>Handler,
		query_handler.NewGet<Entity>ByIdHandler,
		apphttp.NewRouter,
	)
	return nil, nil, nil, nil, nil, nil, nil, nil
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update wire.go with logger and new messaging providers"
```

---

## Task 16: Update wire_gen.go placeholder

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Replace the wire_gen.go template**

Find the `### \`cmd/<app>/wire_gen.go\`` section. Replace the code block with:

````markdown
### `cmd/<app>/wire_gen.go`

> **Do not edit this file by hand.** It is generated by Wire. After scaffolding, run `wire` inside the container to generate the real implementation:
> ```bash
> bin/exec go run github.com/google/wire/cmd/wire ./cmd/<app>/
> ```
> The placeholder below satisfies the build constraint so the package compiles before Wire has been run.

```go
// Code generated by Wire. DO NOT EDIT.

//go:generate go run github.com/google/wire/cmd/wire
//go:build !wireinject

package main

import (
	"context"

	"github.com/gin-gonic/gin"
	"github.com/pascalallen/<app>/internal/<app>/application/command_handler"
	"github.com/pascalallen/<app>/internal/<app>/application/query_handler"
	"github.com/pascalallen/<app>/internal/<app>/infrastructure/messaging"
)

func initializeRouter(ctx context.Context) (
	*gin.Engine,
	*messaging.ChannelCommandBus,
	*messaging.SynchronousQueryBus,
	*messaging.ChannelEventDispatcher,
	*command_handler.Register<Entity>Handler,
	*query_handler.Get<Entity>ByIdHandler,
	func(),
	error,
) {
	return nil, nil, nil, nil, nil, nil, nil, nil
}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update wire_gen.go placeholder to match new signature"
```

---

## Task 17: Update project CLAUDE.md template in new-go-service.md

**Files:**
- Modify: `skills/new-go-service.md`

- [ ] **Step 1: Update the CLAUDE.md template section**

Find the `### \`CLAUDE.md\` (project-level)` section. Update the Architecture section's messaging line:

```
    messaging/         — command + query buses
```

Replace with:

```
    messaging/         — ChannelCommandBus (async), SynchronousQueryBus, ChannelEventDispatcher
```

Also add to the Key Patterns section:

```markdown
- Command bus: fire-and-forget async — `Execute(cmd)` sends to buffered channel; HTTP handlers return 202 Accepted
- Query bus: synchronous — `Fetch(q)` blocks until the handler returns (HTTP handlers need the result)
- `StartConsuming()` runs in a goroutine; `Shutdown()` drains the channel and waits before exit
- Handler registration (`RegisterHandler`, `RegisterListener`) happens in `main.go` before `StartConsuming()`
```

- [ ] **Step 2: Commit**

```bash
git add skills/new-go-service.md
git commit -m "feat(new-go-service): update project CLAUDE.md template with channel bus patterns"
```

---

## Task 18: Strip RabbitMQ from event-sourcing.md

**Files:**
- Modify: `skills/event-sourcing.md`

- [ ] **Step 1: Update skill description frontmatter**

Find:
```
description: Augment an existing Go service (scaffolded with new-go-service) with event sourcing using EventStoreDB for persistence and RabbitMQ for async command dispatch
```

Replace with:
```
description: Augment an existing Go service (scaffolded with new-go-service) with event sourcing using EventStoreDB for persistence; the channel command bus from the base scaffold handles async dispatch
```

- [ ] **Step 2: Remove the command_bus.go replacement section**

Delete the entire `### \`internal/<app>/infrastructure/messaging/command_bus.go\` (replace existing)` section and its code block — this is the `RabbitMqCommandBus` template.

- [ ] **Step 3: Update "Files modified" table**

In the `### What Gets Added or Modified` section, find the `### Files modified` table and remove this row:

```
| `internal/<app>/infrastructure/messaging/command_bus.go`  — replaced with RabbitMQ async bus |
```

Replace it with a note (can be a new table row or prose below the table):

> The channel command bus from the base scaffold is the async dispatch mechanism. No changes to messaging are required when adding event sourcing.

- [ ] **Step 4: Remove rabbitmq from compose.yaml additions**

In the `### compose.yaml additions (merge into existing file)` section, delete the entire `rabbitmq:` service block:

```yaml
  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS}
    ports:
      - "5672:5672"
      - "15672:15672"
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

- [ ] **Step 5: Remove RABBITMQ vars from .env.example additions**

In the `### .env.example additions` section, delete:

```
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=guest
```

- [ ] **Step 6: Remove amqp dependency from go.mod additions**

In the `## After Adding Event Sourcing` section, find the go.mod requires block and remove:

```
github.com/rabbitmq/amqp091-go v1.11.0
```

- [ ] **Step 7: Remove NewAmqpConnection wire provider**

In the `### Wire providers to add` section, delete the entire `// infrastructure/messaging/amqp_connection.go` block and its function, and remove the sentence about adding it to `wire.Build`.

Also remove the reference to `NewAmqpConnection` and `bus.StartConsuming()` instructions that reference AMQP (the channel bus's `StartConsuming` is already handled in `main.go` from the base scaffold).

- [ ] **Step 8: Commit**

```bash
git add skills/event-sourcing.md
git commit -m "feat(event-sourcing): remove RabbitMQ — channel bus from base scaffold handles async dispatch"
```

---

## Task 19: Scaffold test-service and verify compilation

**Files:**
- Create: `../test-service/` (sibling directory to claude-dotfiles — delete after verification)

- [ ] **Step 1: Create the test-service directory**

```bash
mkdir -p /tmp/test-service
```

- [ ] **Step 2: Invoke the new-go-service skill**

Open a new Claude Code session in `/tmp/test-service` and invoke the `new-go-service` skill with:
- App name: `test-service`
- Entity name: `Widget`

The skill will generate all files with `<app>` → `test-service` and `<Entity>` → `Widget` substitutions.

- [ ] **Step 3: Initialize git and copy .env**

```bash
cd /tmp/test-service
git init
cp .env.example .env
```

- [ ] **Step 4: Start containers**

```bash
bin/up -d
```

Expected: postgres container reaches `healthy`, app container starts. No error about RabbitMQ or missing AMQP connection.

- [ ] **Step 5: Run Wire to generate wire_gen.go**

```bash
bin/exec go run github.com/google/wire/cmd/wire ./cmd/test-service/
```

Expected output: `wire: github.com/pascalallen/test-service/cmd/test-service: wrote .../wire_gen.go`

- [ ] **Step 6: Verify compilation**

```bash
bin/exec go build ./cmd/test-service/
```

Expected: exits 0, no output.

- [ ] **Step 7: Run messaging unit tests**

```bash
bin/exec go test ./internal/test-service/infrastructure/messaging/... -v
```

Expected output:
```
--- PASS: TestChannelCommandBus (0.00s)
--- PASS: TestChannelEventDispatcher (0.00s)
PASS
```

- [ ] **Step 8: Run all tests**

```bash
bin/exec go test ./...
```

Expected: all PASS.

---

## Task 20: Smoke test the running service

**Files:** none

- [ ] **Step 1: Restart app after Wire regeneration**

```bash
bin/down && bin/up -d
```

Wait for postgres healthy + app ready (watch `docker compose logs app`).

- [ ] **Step 2: POST to create a widget**

```bash
curl -s -X POST http://localhost:8080/api/v1/widgets | jq .
```

Expected response (202 Accepted):
```json
{"id": "01J..."}
```

- [ ] **Step 3: Check app logs for command processing**

```bash
docker compose logs app | grep -E "executing command|processing command"
```

Expected: two log lines per POST — one for `executing command` (HTTP goroutine) and one for `processing command` (consumer goroutine). Confirms the channel bus dispatched async.

- [ ] **Step 4: Verify graceful shutdown**

```bash
bin/down
docker compose logs app | tail -5
```

Expected: `shutting down...` log line. No panic or unclean exit.

- [ ] **Step 5: Clean up test-service**

```bash
rm -rf /tmp/test-service
```

---

## Task 21: Final commit and summary

**Files:**
- No new edits — this is a verification-and-close task

- [ ] **Step 1: Confirm all dotfiles changes are committed**

```bash
git -C /path/to/claude-dotfiles log --oneline -15
```

Expected: commits for each task above visible in history.

- [ ] **Step 2: Save memory**

Save a project memory noting that RabbitMQ has been replaced with native Go channels in the dotfiles, and the `carline` repo was the reference implementation.
