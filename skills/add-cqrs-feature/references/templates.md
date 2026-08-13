# Add-CQRS-Feature Code Templates

Substitutions: `<app>` (service), `<domain>`/`<entity>` (lowercase), `<Entity>`
(PascalCase), `<Verb>` (imperative, e.g. `Register`), `<Past>` (past-tense event
suffix, e.g. `Registered`).

## 1. Command + handler

`application/command/<domain>.go`:
```go
type <Verb><Entity> struct {
	Id   ulid.ULID `json:"id"`
	// ...fields
}
func (c <Verb><Entity>) CommandName() string { return "<Verb><Entity>" }
```

`application/command_handler/<domain>.go`:
```go
type <Verb><Entity>Handler struct {
	Logger             logger.Logger
	<Entity>Repository <entity>.Repository
	EventDispatcher    messaging.EventDispatcher // only if it emits events
}

func (h <Verb><Entity>Handler) Handle(ctx context.Context, cmd messaging.Command) error {
	c, ok := cmd.(*command.<Verb><Entity>)
	if !ok {
		h.Logger.Error("invalid command type passed to <Verb><Entity>Handler", "command", cmd)
		return fmt.Errorf("invalid command type passed to <Verb><Entity>Handler: %v", cmd)
	}
	// load / mutate / persist via repository (pass ctx through)
	// h.EventDispatcher.Dispatch(context.WithoutCancel(ctx), &event.<Entity><Past>{...})
	return nil
}
```

## 2. Query + handler

`application/query/<domain>.go`:
```go
type Get<Entity>ById struct {
	Id ulid.ULID `json:"id"`
}
func (q Get<Entity>ById) QueryName() string { return "Get<Entity>ById" }
```

`application/query_handler/<domain>.go`:
```go
type Get<Entity>ByIdHandler struct {
	Logger             logger.Logger
	<Entity>Repository <entity>.Repository
}

func (h Get<Entity>ByIdHandler) Handle(ctx context.Context, qry messaging.Query) (any, error) {
	q, ok := qry.(query.Get<Entity>ById)
	if !ok {
		return nil, fmt.Errorf("invalid query type passed to Get<Entity>ByIdHandler: %v", qry)
	}
	return h.<Entity>Repository.GetById(ctx, q.Id)
}
```

## 3. Domain event + listener

`application/event/<domain>.go`:
```go
type <Entity><Past> struct {
	Id ulid.ULID `json:"id"`
	// ...payload the listener needs
}
func (e <Entity><Past>) EventName() string { return "<Entity><Past>" }
```

`application/listener/<domain>.go` — a struct with the deps it needs (often
`CommandBus` to chain a follow-up command, or a `websocket.Hub` to broadcast):
```go
type <Entity><Past>Listener struct {
	Logger     logger.Logger
	CommandBus messaging.CommandBus
}

func (l <Entity><Past>Listener) Handle(ctx context.Context, evt messaging.Event) error {
	e, ok := evt.(*event.<Entity><Past>)
	if !ok {
		return fmt.Errorf("invalid event type passed to <Entity><Past>Listener: %v", evt)
	}
	// react: return l.CommandBus.Dispatch(ctx, &command.SomethingNext{...})
	return nil
}
```

## 4. Repository method

Add to the domain interface (`domain/<entity>/repository.go`) and implement in
`infrastructure/repository/postgres_<entity>_repository.go`:
```go
func (r *Postgres<Entity>Repository) GetById(ctx context.Context, id ulid.ULID) (*<entity>.<Entity>, error) {
	var e <entity>.<Entity>
	var i string
	q := `SELECT id, name, created_at, modified_at FROM <entity>s WHERE id = $1`
	if err := r.session.QueryRowContext(ctx, q, id.String()).Scan(&i, &e.Name, &e.CreatedAt, &e.ModifiedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil // not found — caller nil-checks
		}
		return nil, fmt.Errorf("error scanning <Entity> by ID: %s", err)
	}
	e.Id = ulid.MustParse(i)
	return &e, nil
}
```

Raw parameterized SQL only; transaction with rollback-on-error for multi-table
writes. Migration pair (`NNNNNN_create_<entity>s_table.{up,down}.sql`) under
`infrastructure/database/migrations/` — ULID PKs as `CHAR(26)` with
`CONSTRAINT chk_<entity>s_id_len CHECK (char_length(id) = 26)`.

## 5. Register in `main.go`

```go
container.CommandBus.RegisterHandler(command.<Verb><Entity>{}.CommandName(), command_handler.<Verb><Entity>Handler{
	Logger:             c.Logger,
	<Entity>Repository: c.<Entity>Repository,
	EventDispatcher:    c.EventDispatcher,
})
// query:  container.QueryBus.RegisterHandler(query.Get<Entity>ById{}.QueryName(), query_handler.Get<Entity>ByIdHandler{...})
// event:  container.EventDispatcher.RegisterListener(event.<Entity><Past>{}.EventName(), listener.<Entity><Past>Listener{...})
```

## 6. HTTP action

`application/http/action/<domain>/<verb>.go` — closure returning
`gin.HandlerFunc`; the bus is synchronous, so the action responds based on the
real result:
```go
type <Verb><Entity>RequestPayload struct {
	Name string `json:"name" binding:"required,max=100"`
}

func Handle<Verb>(commandBus messaging.CommandBus) gin.HandlerFunc {
	return func(c *gin.Context) {
		var payload <Verb><Entity>RequestPayload
		if err := c.ShouldBindJSON(&payload); err != nil {
			responder.BadRequestResponse(c, err)
			return
		}
		cmd := command.<Verb><Entity>{Id: ulid.Make(), Name: payload.Name}
		if err := commandBus.Dispatch(c.Request.Context(), &cmd); err != nil {
			responder.InternalServerErrorResponse(c, err)
			return
		}
		responder.CreatedResponse(c, &cmd)
	}
}
// queries: results, err := queryBus.Fetch(c.Request.Context(), query.Get<Entity>ById{...})
//          → responder.OkResponse on success
```

Use the service's actual `responder` JSend helper names — check
`application/http/responder/responses.go`. Register the action on the domain's
router method in `infrastructure/routes/<domain>.go` (add the method if the
domain group is new, and call it from `configureServer` in `main.go`). Apply
`middleware.AuthRequired`-style middleware where the existing routes do.
