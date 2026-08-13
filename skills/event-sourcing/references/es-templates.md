# Event Sourcing Templates

Substitutions: `<app>` (service), `<entity>` (lowercase), `<Entity>` (PascalCase).

## `internal/<app>/infrastructure/storage/event_store.go`

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
		// Unknown event type — add a case here when new domain events are introduced.
		return nil, nil
	}
}
```

## `internal/<app>/infrastructure/storage/eventstore_client.go`

```go
func NewEventStoreDbClient(connStr string) (*esdb.Client, error) {
	settings, err := esdb.ParseConnectionString(connStr)
	if err != nil {
		return nil, fmt.Errorf("parsing EventStoreDB connection string: %w", err)
	}
	return esdb.NewClient(settings)
}
```

Add `NewEventStoreDbClient` and `NewEventStoreDb` to `wire.Build`, bind the
handler's `EventStore` field to `*storage.EventStoreDb`
(`wire.Bind(new(storage.EventStore), new(*storage.EventStoreDb))`), remove the
Postgres repository provider for the sourced entity, and regenerate. The
connection string comes from `EVENTSTORE_CONNECTION_STRING`.

## compose.yaml additions (merge into existing file)

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
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:2113/health/live || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
```

## .env.example additions

```
EVENTSTORE_PORT=2113
EVENTSTORE_CONNECTION_STRING=esdb://eventstore:2113?tls=false
```

## `etc/projections/<entity>_projection.js`

Server-side projection that runs inside EventStoreDB — load it via the admin UI
at `http://localhost:2113` or the HTTP API; it is NOT part of the Go binary.

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

## Handler patterns

Handlers keep the base scaffold's bus signatures (`messaging.Command` +
type assertion, ctx first) — only the persistence changes.

**Command handler — append to stream instead of saving to Postgres:**

```go
type Register<Entity>Handler struct {
	Logger     logger.Logger
	EventStore storage.EventStore
}

func (h Register<Entity>Handler) Handle(ctx context.Context, cmd messaging.Command) error {
	c, ok := cmd.(*command.Register<Entity>)
	if !ok {
		h.Logger.Error("invalid command type passed to Register<Entity>Handler", "command", cmd)
		return fmt.Errorf("invalid command type passed to Register<Entity>Handler: %v", cmd)
	}

	streamId := fmt.Sprintf("<entity>-%s", c.Id)

	e, err := <entity>.Register(c.Id)
	if err != nil {
		return fmt.Errorf("registering <entity>: %w", err)
	}

	if err := h.EventStore.AppendToStream(ctx, streamId, e.Version(), e.UncommittedEvents()); err != nil {
		return fmt.Errorf("appending events: %w", err)
	}

	e.ClearUncommittedEvents()
	return nil
}
```

**Query handler — read stream and replay:**

```go
func (h Get<Entity>ByIdHandler) Handle(ctx context.Context, qry messaging.Query) (any, error) {
	q, ok := qry.(query.Get<Entity>ById)
	if !ok {
		return nil, fmt.Errorf("invalid query type passed to Get<Entity>ByIdHandler: %v", qry)
	}

	streamId := fmt.Sprintf("<entity>-%s", q.Id)

	events, err := h.EventStore.ReadFromStream(ctx, streamId)
	if err != nil {
		return nil, fmt.Errorf("reading stream: %w", err)
	}

	return <entity>.LoadFromEvents(events)
}
```

**Aggregate replay constructor** (`domain/<entity>/<entity>.go`):

```go
func LoadFromEvents(events []event.Event) (*<Entity>, error) {
	if len(events) == 0 {
		return nil, fmt.Errorf("<entity> not found")
	}
	e := &<Entity>{version: -1}
	for _, ev := range events {
		e.applyEvent(ev)
	}
	return e, nil
}
```

`applyEvent` in the replay path mutates state and increments `version` — it does
NOT append to `uncommittedEvents`. `raise()` does both (apply + append).

## go.mod

```
github.com/EventStore/EventStore-Client-Go/v4 v4.2.0
```

Run `bin/exec go mod tidy` after adding.

## Project CLAUDE.md block to add

```markdown
## Event Sourcing

- Stream IDs: `<entity>-{ulid}`
- Aggregates load state via `LoadFromEvents` — never instantiate directly from DB rows
- Command handlers: call aggregate method → `AppendToStream` → `ClearUncommittedEvents`
- Query handlers: `ReadFromStream` → `LoadFromEvents` → return aggregate
- Optimistic concurrency: pass `e.Version()` to `AppendToStream`; EventStoreDB rejects writes if the stream has moved
- `wire_gen.go` must be regenerated after swapping repository → event store providers
```
