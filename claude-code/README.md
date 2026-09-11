# claude-code/ — canonical project Claude Code kit

Copied into a target repo by the `claude-code-repo-setup` skill; these files
ARE the convention, not a template to regenerate from memory.

| File | Goes to |
|------|---------|
| `settings.json` | `.claude/settings.json` |
| `rules/go.md`, `rules/frontend.md` | `.claude/rules/` |
| `skills/verify/SKILL.md` | `.claude/skills/verify/SKILL.md` |
| `workflows/ci.yml` | `.github/workflows/ci.yml` |
| `workflows/claude.yml` | `.github/workflows/claude.yml` |
| `workflows/claude-review.yml` | `.github/workflows/claude-review.yml` |

`settings.json` is the team-shared, committed permissions + hooks file.
`.claude/settings.local.json` (personal overrides) and `.mcp.json` (may carry
local server config) stay **gitignored** in every target repo — never copy
those in, and never commit secrets into `settings.json` itself.

Adapt `rules/frontend.md`'s `paths` and drop the `yarn` job from `ci.yml` and
the prettier hook from `settings.json` when the repo has no `web/app`
frontend. `workflows/claude.yml` and `workflows/claude-review.yml` both
require an `ANTHROPIC_API_KEY` repository secret.
