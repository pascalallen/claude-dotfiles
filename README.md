# claude-dotfiles

Personal Claude Code configuration for Pascal Allen — a global `CLAUDE.md`,
user `settings.json` (permissions + hooks), and scaffold/extension skills,
symlinked into `~/.claude/`.

## Philosophy

Every project follows the same structural decisions — **DDD**, **hexagonal
architecture**, **CQRS** — with the stack varying (Go or PHP backend, React +
TypeScript frontend). Event sourcing is a deliberate non-default. This repo
encodes those decisions once so Claude applies them in every session without
re-explanation. The full stack defaults, conventions, and working principles
live in [CLAUDE.md](CLAUDE.md); the durable design rationale lives in
[docs/adr/](docs/adr/).

Two rules keep this repo honest:

- **Skills clone living templates** (`go-clean-arch`, `DockerSymfony`,
  the production reference app's `web/app`) instead of embedding file copies that rot ([ADR 0001](docs/adr/0001-skills-clone-living-templates.md)).
- **Nothing lives here that Claude can already do without it** — no generic
  knowledge, no deployment runbooks, no historical planning documents.

## Installation

```bash
git clone https://github.com/pascalallen/claude-dotfiles.git ~/code/claude-dotfiles
cd ~/code/claude-dotfiles
./install.sh
```

`install.sh` prunes stale/dangling links from previous checkouts, backs up any
pre-existing real `~/.claude/CLAUDE.md` / `~/.claude/settings.json`, then
symlinks `CLAUDE.md`, `settings.json`, each `hooks/*.sh` script, each
`agents/*.md` definition and each `skills/<name>/` directory into `~/.claude/`. Re-running is idempotent. Restart
Claude Code after installing.

```bash
./uninstall.sh   # removes only links owned by a claude-dotfiles checkout
```

**Scope caveat:** everything here applies only to machines where `install.sh`
has run. Claude Code on the web / remote sessions never see `~/.claude/` —
anything a remote session needs (SessionStart dep-warming, project permission
allowlists, MCP servers) must live in the project repo's own `.claude/` and
`.mcp.json`.

## Settings & hooks

`settings.json` is the user-scope config, and because the installed file is a
symlink, any change Claude Code writes to user settings shows up in `git
status` here — config drift is tracked, not silent.

- **Permissions allowlist** — pre-approves the verify loop so sessions don't
  prompt for it: the containerized wrappers (`bin/exec go ...`,
  `bin/exec gofmt ...`, `bin/yarn ...` — sandboxed by Docker), native
  `go build/test/vet/generate` + `gofmt`, and read-only git (`status`,
  `diff`, `log`). Trim or extend to taste; project-specific grants belong in
  that project's `.claude/settings.json`, not here.
- **`hooks/gofmt-on-edit.sh`** (PostToolUse on `Edit|Write`) — runs `gofmt -w`
  on any `.go` file Claude touches. This enforces the "gofmt before finishing"
  rule deterministically instead of relying on the model to remember it. The
  script no-ops (exit 0) for non-Go files or when `gofmt`/`jq`/`python3` are
  missing, so it can never block an edit.

- **No commit trailer** — `attribution.commit` is empty, so commits carry no
  `Co-Authored-By` line; the PR line stays at its default.
- **Global `deny`** — `.env` / `.env.local` reads and `wire_gen.go` edits are
  refused in every repo; a project adds its own generated files.
- **`check.sh`** (run by the `.githooks/pre-commit` hook that `install.sh`
  enables) — refuses a commit when a tracked file holds plugin config or a
  name listed in the untracked `~/.claude/private-references.md`. Because
  `settings.json` is a symlink, Claude Code can write machine-local values
  into it; this is the guard.

- **No secrets, no machine-local config** — this repo is public. Tokens come
  from the shell profile (e.g. `export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth
  token)"`), machine-local MCP servers go in `~/.claude/settings.local.json`,
  and project-only plugins (and `autoMode` notes) go in that project's
  `.claude/settings.local.json`.

## Agents

Project-agnostic subagent templates, linked into `~/.claude/agents/`:

| Agent | Use when |
|-------|----------|
| `code-writer` | One checklist item from a brief file on disk; test-first, own worktree, opens the PR, never merges |
| `code-reviewer` | One PR touching SQL, money, migrations, auth/tenancy or concurrency; read-only, refute-by-default, defects with failure scenarios only |

Copy them into a project's `.claude/agents/` and specialise the invariants and
gates once the project has its own rules.

## How skills work

Skills are **model-invoked, not slash commands**: Claude Code reads each
`~/.claude/skills/<name>/SKILL.md` frontmatter description and loads a skill
when the task matches it. Each skill keeps its `SKILL.md` short and puts
authoritative code shapes in `references/` files loaded on demand.

| Skill | Use when | What it does |
|-------|----------|--------------|
| `new-go-service` | Creating a new Go backend | Clones + renames `go-clean-arch`: DDD/hexagonal/CQRS, Wire, Gin, `database/sql` + `lib/pq`, golang-migrate, synchronous in-process buses, Docker |
| `add-cqrs-feature` | Extending an existing Go service | Adds a command/query/event+listener and optional HTTP route following the grouped-by-domain conventions, with exact insertion points |
| `event-sourcing` | The domain explicitly needs audit/replay/temporal queries | Additively swaps PostgreSQL persistence for EventStoreDB; owns all ES-only conventions |
| `new-php-service` | Creating a new PHP backend | DockerSymfony base + imposed `src/{Domain,Application,Infrastructure}` structure, invokable handlers, ULIDs, XML Doctrine mappings |
| `agent-waves` | Building several checklist items in parallel with agents | The orchestrator's procedure: round folder, briefs, wave launch, review loop, a serial land queue (`scripts/landq.sh`, `scripts/land.sh`) with a post-merge gate, ledger and handoff |
| `new-react-app` | Adding a frontend | Production stack: Webpack 5, React 19, TanStack Query, Bootstrap + `react-form-components`, SCSS, base64-JSON runtime config |

## Canonical Reference Repos

- The production reference app — private; named only in the untracked `~/.claude/private-references.md`; **ground truth** where templates lag
- [go-clean-arch](https://github.com/pascalallen/go-clean-arch) — Go template the scaffold skill clones
- [es-go](https://github.com/pascalallen/es-go) — event sourcing reference
- [pubsub](https://github.com/pascalallen/pubsub) — channel-based pub/sub library (the async escape hatch)
- [Astral](https://github.com/pascalallen/Astral) / [DockerSymfony](https://github.com/pascalallen/DockerSymfony) — PHP pattern + base

## Repo layout

```
CLAUDE.md            global config → ~/.claude/CLAUDE.md
settings.json        user settings: permissions + hooks → ~/.claude/settings.json
hooks/               hook scripts → ~/.claude/hooks/<name>.sh
agents/<name>.md     subagent templates → ~/.claude/agents/<name>.md
skills/<name>/       SKILL.md + references/ (+ scripts/) → ~/.claude/skills/<name>
docs/adr/            architecture decision records
install.sh           idempotent symlink install (prunes stale links)
check.sh             pre-commit guard: no private names or plugin config in tracked files
uninstall.sh         removes this repo's links
```
