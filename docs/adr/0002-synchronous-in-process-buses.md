# ADR 0002 — Synchronous in-process buses; channels live in the pubsub library

**Status:** Accepted (2026-08-13, reflecting carline production)

## Context

The messaging stack evolved: GCP Pub/Sub → RabbitMQ → native Go channel buses
(`ChannelCommandBus`, buffered channel + consumer goroutine) → **synchronous
map-based buses**. The channel generation existed to preserve a broker-shaped
API after dropping RabbitMQ, but publisher and consumer were the same process:
the async hop added `StartConsuming`/`Shutdown` lifecycle, panic recovery, and
fire-and-forget dispatch that swallowed handler errors — and bought nothing.

## Decision

- `CommandBus.Dispatch(ctx, cmd) error`, `QueryBus.Fetch(ctx, qry) (any, error)`,
  `EventDispatcher.Dispatch(ctx, evt)` are **synchronous, map-registry, in-process**.
  The caller gets the handler's real error; HTTP actions respond from real results.
- `context.Context` threads through every bus, handler, listener, and repository
  call; events that must outlive the request dispatch with `context.WithoutCancel`.
- True background/fan-out work uses the standalone `pascalallen/pubsub` library
  (goroutine/channel pub-sub) beside the buses — the channel pattern survived as
  a library, not as the app's command path.

## Consequences

- In-process bus + WebSocket hub ⇒ **single-instance deployment** is a hard
  constraint (`instance_count: 1` on DO App Platform) until messaging is
  externalized.
- One listener per event name (registry overwrite semantics); fan-out belongs in
  pubsub, not the dispatcher.
- `go-clean-arch` still ships the channel generation; the `new-go-service` skill
  aligns clones to this ADR until the template is migrated.
