---
name: event-sourcing
description: Augment an existing Go service (scaffolded with new-go-service) with event sourcing using EventStoreDB for persistence and RabbitMQ for async command dispatch
---

# Event Sourcing

Add event sourcing to an existing Go service. This is an **additive layer** — it replaces the PostgreSQL repository and synchronous command bus with EventStoreDB persistence and RabbitMQ async dispatch. Reference: `pascalallen/es-go`.

## When to Use

Only invoke this skill when the domain explicitly requires one or more of:
- Full audit trail of every state change
- Ability to replay events to reconstruct state at any point in time
- Stakeholders querying past states as a business requirement

If unsure, default to standard CQRS with PostgreSQL. You can always add ES later.

## Process

Ask the user:
1. **Service name** — the `<app>` value used when the service was scaffolded (e.g. `user-service`)
2. **Why event sourcing?** — brief statement of the business reason (audit trail, temporal queries, etc.) — surfaces the justification and confirms the decision is deliberate

Substitutions:
- `<app>` → service name as-is
- `<entity>` → primary entity name lowercased
- `<Entity>` → primary entity name PascalCase

## What Gets Added or Modified

### New files added

```
internal/<app>/infrastructure/storage/event_store.go
internal/<app>/application/projection/
  <entity>_projection.js    (example EventStoreDB JS projection)
```

### Files modified

```
internal/<app>/infrastructure/messaging/command_bus.go  — replaced with RabbitMQ async bus
compose.yaml                                            — add EventStoreDB + RabbitMQ services
.env.example                                            — add EventStoreDB + RabbitMQ vars
CLAUDE.md                                               — add ES architecture notes
```

Command handlers and query handlers are also updated to use the ES pattern (see below).

## File Templates

### `internal/<app>/infrastructure/storage/event_store.go`
```go
package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"io"

	"github.com/EventStore/EventStore-Client-Go/v4/esdb"
	"github.com/pascalallen/<app>/internal/<app>/domain/event"
)

type EventStore interface {
	AppendToStream(ctx context.Context, streamId string, version int, events []event.Event) error
	ReadFromStream(ctx context.Context, streamId string) ([]event.Event, error)
}

type EventStoreDb struct {
	client *esdb.Client
}

func NewEventStoreDb(client *esdb.Client) *EventStoreDb {
	return &EventStoreDb{client: client}
}

func (s *EventStoreDb) AppendToStream(ctx context.Context, streamId string, version int, events []event.Event) error {
	var expectedRevision esdb.ExpectedRevision
	if version == -1 {
		expectedRevision = esdb.NoStream{}
	} else {
		expectedRevision = esdb.Revision(uint64(version))
	}

	var eventData []esdb.EventData
	for _, e := range events {
		data, err := json.Marshal(e)
		if err != nil {
			return fmt.Errorf("marshaling event %s: %w", e.EventName(), err)
		}
		eventData = append(eventData, esdb.EventData{
			ContentType: esdb.ContentTypeJson,
			EventType:   e.EventName(),
			Data:        data,
		})
	}

	_, err := s.client.AppendToStream(ctx, streamId, esdb.AppendToStreamOptions{
		ExpectedRevision: expectedRevision,
	}, eventData...)
	return err
}

func (s *EventStoreDb) ReadFromStream(ctx context.Context, streamId string) ([]event.Event, error) {
	stream, err := s.client.ReadStream(ctx, streamId, esdb.ReadStreamOptions{}, ^uint64(0))
	if err != nil {
		return nil, fmt.Errorf("reading stream %s: %w", streamId, err)
	}
	defer stream.Close()

	var events []event.Event
	for {
		resolvedEvent, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		e, err := deserializeEvent(resolvedEvent.Event)
		if err != nil {
			return nil, err
		}
		if e != nil {
			events = append(events, e)
		}
	}
	return events, nil
}

func deserializeEvent(recorded *esdb.RecordedEvent) (event.Event, error) {
	switch recorded.EventType {
	case "<Entity>Registered":
		var e event.<Entity>Registered
		if err := json.Unmarshal(recorded.Data, &e); err != nil {
			return nil, err
		}
		return &e, nil
	default:
		return nil, nil
	}
}
```

### `internal/<app>/infrastructure/messaging/command_bus.go` (replace existing)
```go
package messaging

import (
	"context"
	"encoding/json"
	"fmt"

	amqp "github.com/rabbitmq/amqp091-go"
)

type RabbitMqCommandBus struct {
	conn     *amqp.Connection
	handlers map[string]func([]byte) error
}

func NewRabbitMqCommandBus(conn *amqp.Connection) *RabbitMqCommandBus {
	return &RabbitMqCommandBus{
		conn:     conn,
		handlers: make(map[string]func([]byte) error),
	}
}

func (b *RabbitMqCommandBus) Register(cmdType string, handler func([]byte) error) {
	b.handlers[cmdType] = handler
}

func (b *RabbitMqCommandBus) Execute(ctx context.Context, cmdType string, cmd any) error {
	ch, err := b.conn.Channel()
	if err != nil {
		return fmt.Errorf("opening channel: %w", err)
	}
	defer ch.Close()

	data, err := json.Marshal(cmd)
	if err != nil {
		return fmt.Errorf("marshaling command: %w", err)
	}

	return ch.PublishWithContext(ctx, "", "commands", false, false, amqp.Publishing{
		ContentType: "application/json",
		Type:        cmdType,
		Body:        data,
	})
}

func (b *RabbitMqCommandBus) StartConsuming() error {
	ch, err := b.conn.Channel()
	if err != nil {
		return err
	}

	q, err := ch.QueueDeclare("commands", true, false, false, false, nil)
	if err != nil {
		return err
	}

	msgs, err := ch.Consume(q.Name, "", false, false, false, false, nil)
	if err != nil {
		return err
	}

	go func() {
		for msg := range msgs {
			handler, ok := b.handlers[msg.Type]
			if !ok {
				msg.Nack(false, false)
				continue
			}
			if err := handler(msg.Body); err != nil {
				msg.Nack(false, true)
				continue
			}
			msg.Ack(false)
		}
	}()

	return nil
}
```

### compose.yaml additions (merge into existing file)
```yaml
  eventstore:
    image: eventstore/eventstore:23.10.0-bookworm-slim
    environment:
      EVENTSTORE_CLUSTER_SIZE: 1
      EVENTSTORE_RUN_PROJECTIONS: All
      EVENTSTORE_START_STANDARD_PROJECTIONS: true
      EVENTSTORE_INSECURE: true
    ports:
      - "2113:2113"

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

### .env.example additions
```
EVENTSTORE_HOST=eventstore
EVENTSTORE_HTTP_PORT=2113
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=guest
```

### `internal/<app>/application/projection/<entity>_projection.js`
```js
fromAll()
  .when({
    $init: function() { return {}; },
    "<Entity>Registered": function(state, event) {
      state[event.data.<entity>Id] = true;
    }
  })
  .outputState();
```

## Updated Handler Patterns

### Command handler — ES pattern

Command handlers change from "save aggregate to Postgres" to "append uncommitted events to stream":

```go
func (h *Register<Entity>Handler) Handle(ctx context.Context, cmd command.Register<Entity>) error {
	streamId := fmt.Sprintf("<entity>-%s", cmd.Id)

	e, err := <entity>domain.Register(cmd.Id)
	if err != nil {
		return fmt.Errorf("registering <entity>: %w", err)
	}

	if err := h.store.AppendToStream(ctx, streamId, e.Version(), e.UncommittedEvents()); err != nil {
		return fmt.Errorf("appending events: %w", err)
	}

	e.ClearUncommittedEvents()
	return nil
}
```

The handler's `<Entity>Repository` field is replaced by an `EventStore` field. Update `wire.go` accordingly:
```go
wire.Bind(new(command_handler.<Entity>EventStore), new(*storage.EventStoreDb)),
```

### Query handler — replay pattern

Query handlers change from "find by id in Postgres" to "read stream and replay events":

```go
func (h *Get<Entity>ByIdHandler) Handle(ctx context.Context, q query.Get<Entity>ById) (*<entity>domain.<Entity>, error) {
	streamId := fmt.Sprintf("<entity>-%s", q.Id)

	events, err := h.store.ReadFromStream(ctx, streamId)
	if err != nil {
		return nil, fmt.Errorf("reading stream: %w", err)
	}

	return <entity>domain.LoadFromEvents(events)
}
```

### Add `LoadFromEvents` to the aggregate

Add this to `internal/<app>/domain/<entity>/<entity>.go`:

```go
func LoadFromEvents(events []event.Event) (*<Entity>, error) {
	e := &<Entity>{version: -1}
	for _, ev := range events {
		e.applyEvent(ev)
	}
	return e, nil
}
```

Note: `applyEvent` in the replay path mutates state and increments `version` — it does NOT append to `uncommittedEvents`.

## After Adding Event Sourcing

Add to `go.mod` requires:
```
github.com/EventStore/EventStore-Client-Go/v4 v4.2.0
github.com/rabbitmq/amqp091-go v1.10.0
```

Run inside the container: `bin/exec go mod tidy`

Update the project `CLAUDE.md` to add:

```markdown
## Event Sourcing

- Stream IDs: `<entity>-{ulid}`
- Aggregates load state via `LoadFromEvents` — never instantiate directly from DB rows
- Command handlers: call aggregate method → `AppendToStream` → `ClearUncommittedEvents`
- Query handlers: `ReadFromStream` → `LoadFromEvents` → return aggregate
- Optimistic concurrency: pass `e.Version()` to `AppendToStream`; EventStoreDB rejects writes if the stream has moved
- `wire_gen.go` must be regenerated after swapping repository → event store providers
```
