# claude-dotfiles

Personal Claude Code configuration for Pascal Allen — a global `CLAUDE.md`,
user `settings.json` (permissions + hooks), and scaffold/extension skills
symlinked into `~/.claude/`, plus a project-level `claude-code/` kit copied
into target repos.

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
  `carline/web/app`) instead of embedding file copies that rot ([ADR 0001](docs/adr/0001-skills-clone-living-templates.md)).
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
symlinks `CLAUDE.md`, `settings.json`, each `hooks/*.sh` script, and each
`skills/<name>/` directory into `~/.claude/`. Re-running is idempotent. Restart
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

This user-level gofmt hook and the project-level gofmt/prettier `PostToolUse`
hooks in `claude-code/settings.json` intentionally overlap. The project-level
copy is what actually runs in Claude Code on the web / remote sessions and on
any machine without these dotfiles installed — exactly the gap the scope
caveat above describes, and exactly why the `claude-code/` kit exists as a
committed, per-repo fallback rather than a dependency on this repo being
installed. See the `claude-code-repo-setup` skill to apply that kit to a repo.

## How skills work

Skills are **model-invoked, not slash commands**: Claude Code reads each
`~/.claude/skills/<name>/SKILL.md` frontmatter description and loads a skill
when the task matches it. Each skill keeps its `SKILL.md` short and puts
authoritative code shapes in `references/` files loaded on demand.

One skill is a special case: `claude-code-repo-setup` doesn't scaffold Go/PHP/
React code — it copies the **project-level** Claude Code kit in
[`claude-code/`](claude-code/) (a committed `.claude/settings.json`, path-scoped
`.claude/rules/`, a `verify` skill, and GitHub Actions workflows) into a target
repo's own `.claude/` and `.github/workflows/`, the same clone-a-living-template
approach as the scaffold skills (ADR 0001).

| Skill | Use when | What it does |
|-------|----------|--------------|
| `new-go-service` | Creating a new Go backend | Clones + renames `go-clean-arch`: DDD/hexagonal/CQRS, Wire, Gin, `database/sql` + `lib/pq`, golang-migrate, synchronous in-process buses, Docker |
| `add-cqrs-feature` | Extending an existing Go service | Adds a command/query/event+listener and optional HTTP route following the grouped-by-domain conventions, with exact insertion points |
| `event-sourcing` | The domain explicitly needs audit/replay/temporal queries | Additively swaps PostgreSQL persistence for EventStoreDB; owns all ES-only conventions |
| `new-php-service` | Creating a new PHP backend | DockerSymfony base + imposed `src/{Domain,Application,Infrastructure}` structure, invokable handlers, ULIDs, XML Doctrine mappings |
| `new-react-app` | Adding a frontend | Production carline stack: Webpack 5, React 19, TanStack Query, Bootstrap + `react-form-components`, SCSS, base64-JSON runtime config, Jest + Testing Library |
| `claude-code-repo-setup` | A repo lacks `.claude/settings.json`/CI, or CLAUDE.md is stale | Copies the canonical kit from [`claude-code/`](claude-code/) — settings, path-scoped rules, the project `verify` skill, and CI + `claude-code-action` workflows |

## Canonical Reference Repos

- [carline](https://github.com/pascalallen/carline) — production SaaS (private); **ground truth** where templates lag
- [go-clean-arch](https://github.com/pascalallen/go-clean-arch) — Go template the scaffold skill clones
- [es-go](https://github.com/pascalallen/es-go) — event sourcing reference
- [pubsub](https://github.com/pascalallen/pubsub) — channel-based pub/sub library (the async escape hatch)
- [Astral](https://github.com/pascalallen/Astral) / [DockerSymfony](https://github.com/pascalallen/DockerSymfony) — PHP pattern + base

## Repo layout

```
CLAUDE.md                    global config → ~/.claude/CLAUDE.md
settings.json                user settings: permissions + hooks → ~/.claude/settings.json
hooks/                       hook scripts → ~/.claude/hooks/<name>.sh
skills/<name>/               SKILL.md + references/ → ~/.claude/skills/<name>
claude-code/                 canonical project-level kit, copied into target
                             repos by claude-code-repo-setup (not symlinked —
                             see its README)
docs/adr/                    architecture decision records
.github/workflows/ci.yml     shellcheck + SKILL.md frontmatter checks for
                             this repo itself
install.sh                   idempotent symlink install (prunes stale links)
uninstall.sh                 removes this repo's links
```
