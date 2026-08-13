# claude-dotfiles

Personal Claude Code configuration for Pascal Allen — a global `CLAUDE.md` plus
scaffold/extension skills, symlinked into `~/.claude/`.

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
pre-existing real `~/.claude/CLAUDE.md`, then symlinks `CLAUDE.md` and each
`skills/<name>/` directory into `~/.claude/`. Re-running is idempotent. Restart
Claude Code after installing.

```bash
./uninstall.sh   # removes only links owned by a claude-dotfiles checkout
```

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
| `new-react-app` | Adding a frontend | Production carline stack: Webpack 5, React 19, TanStack Query, Bootstrap + `react-form-components`, SCSS, base64-JSON runtime config |

## Canonical Reference Repos

- [carline](https://github.com/pascalallen/carline) — production SaaS (private); **ground truth** where templates lag
- [go-clean-arch](https://github.com/pascalallen/go-clean-arch) — Go template the scaffold skill clones
- [es-go](https://github.com/pascalallen/es-go) — event sourcing reference
- [pubsub](https://github.com/pascalallen/pubsub) — channel-based pub/sub library (the async escape hatch)
- [Astral](https://github.com/pascalallen/Astral) / [DockerSymfony](https://github.com/pascalallen/DockerSymfony) — PHP pattern + base

## Repo layout

```
CLAUDE.md            global config → ~/.claude/CLAUDE.md
skills/<name>/       SKILL.md + references/ → ~/.claude/skills/<name>
docs/adr/            architecture decision records
install.sh           idempotent symlink install (prunes stale links)
uninstall.sh         removes this repo's links
```
