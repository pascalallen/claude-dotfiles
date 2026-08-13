---
name: event-sourcing
description: Augment an existing Go service (scaffolded with new-go-service) with event sourcing using EventStoreDB for persistence. Use only when the domain explicitly requires audit trail, event replay, or temporal queries — never as a default. Reference implementation is pascalallen/es-go.
---

# Event Sourcing

Add event sourcing to an existing Go service. This is an **additive layer** — it
replaces the PostgreSQL repository with EventStoreDB persistence; the synchronous
in-process buses from the base scaffold keep handling dispatch, and no messaging
changes are required. Reference: `pascalallen/es-go`.

File templates (event store, compose additions, projections, handler patterns)
are in **`references/es-templates.md`** — read it before writing code.

## When to Use

Only invoke this skill when the domain explicitly requires one or more of:
- Full audit trail of every state change
- Ability to replay events to reconstruct state at any point in time
- Stakeholders querying past states as a business requirement

If unsure, default to standard CQRS with PostgreSQL. You can always add ES later.

## Process

Ask the user:
1. **Service name** — the `<app>` value used when the service was scaffolded
2. **Why event sourcing?** — brief statement of the business reason (audit trail,
   temporal queries, etc.) — surfaces the justification and confirms the decision
   is deliberate

Substitutions: `<app>` (as-is) · `<entity>` (lowercase) · `<Entity>` (PascalCase).

## ES conventions (this skill only — they do NOT apply to standard CQRS services)

- Stream IDs: `<entity>-{ulid}`.
- Aggregates use private fields with a `version int` and
  `uncommittedEvents []event.Event`; **aggregate methods raise domain events
  internally via `raise()`/`applyEvent()`** — external code never instantiates
  domain events directly. Factories return `(*<Entity>, error)` and validate
  invariants.
- Domain events live in `domain/event/` (not `application/event/`) and carry
  `OccurredAt time.Time` set at raise-time.
- Aggregates load via `LoadFromEvents(events)` — never instantiate from DB rows.
- Command handlers: call aggregate factory/method → `AppendToStream` →
  `ClearUncommittedEvents`. Query handlers: `ReadFromStream` → `LoadFromEvents` →
  return the aggregate.
- Optimistic concurrency: pass `aggregate.Version()` to `AppendToStream`;
  EventStoreDB rejects the write if the stream has moved.

## What Gets Added or Modified

New files:
```
internal/<app>/infrastructure/storage/event_store.go       EventStore interface + EventStoreDb impl
internal/<app>/infrastructure/storage/eventstore_client.go NewEventStoreDbClient provider
etc/projections/<entity>_projection.js                     EventStoreDB server-side projection
                                                           (loaded via admin UI / HTTP API, not compiled with Go)
```

Modified:
```
compose.yaml    — add EventStoreDB service (healthchecked)
.env.example    — EVENTSTORE_PORT / EVENTSTORE_CONNECTION_STRING
go.mod          — github.com/EventStore/EventStore-Client-Go/v4
domain/<entity> — ES-style aggregate (raise/applyEvent/version/LoadFromEvents)
domain/event/   — domain events with OccurredAt
command/query handlers — ES patterns (see references)
wire.go         — EventStore providers replace the Postgres repository binding; regenerate
CLAUDE.md       — project-level ES notes block (see references)
```

## Verify

```bash
bin/exec go mod tidy
(cd internal/<app>/infrastructure/container && go tool wire)   # providers changed
bin/exec go build ./...   # MUST pass
bin/exec go test ./...    # MUST pass
```

`wire_gen.go` must be regenerated after swapping repository → event store
providers. EventStoreDB admin UI is at `http://localhost:2113` for loading
projections and inspecting streams.
