#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
HOOKS_DIR="$CLAUDE_DIR/hooks"

mkdir -p "$SKILLS_DIR" "$HOOKS_DIR"

# 1. Prune stale links: anything dangling, or pointing into any claude-dotfiles
#    checkout (old ~/projects path, legacy flat *.md skill links, this repo —
#    relinked fresh below). Never touches real files or unrelated symlinks.
for link in "$SKILLS_DIR"/* "$HOOKS_DIR"/* "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/settings.json"; do
    [ -L "$link" ] || continue
    target="$(readlink "$link")"
    if [ ! -e "$link" ] || [[ "$target" == */claude-dotfiles/* ]]; then
        rm "$link"
        echo "pruned $link -> $target"
    fi
done

# 2. CLAUDE.md — back up a pre-existing real file (never a symlink) first.
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ ! -L "$CLAUDE_DIR/CLAUDE.md" ]; then
    backup="$CLAUDE_DIR/CLAUDE.md.bak.$(date +%Y%m%d%H%M%S)"
    mv "$CLAUDE_DIR/CLAUDE.md" "$backup"
    echo "backed up existing CLAUDE.md -> $backup"
fi
ln -sfn "$DOTFILES_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "linked CLAUDE.md -> $CLAUDE_DIR/CLAUDE.md"

# 3. settings.json — same backup-then-link treatment. Because the installed
#    file is a symlink, anything Claude Code writes to user settings lands in
#    this repo's copy, so config drift shows up in git status.
if [ -f "$CLAUDE_DIR/settings.json" ] && [ ! -L "$CLAUDE_DIR/settings.json" ]; then
    backup="$CLAUDE_DIR/settings.json.bak.$(date +%Y%m%d%H%M%S)"
    mv "$CLAUDE_DIR/settings.json" "$backup"
    echo "backed up existing settings.json -> $backup"
fi
ln -sfn "$DOTFILES_DIR/settings.json" "$CLAUDE_DIR/settings.json"
echo "linked settings.json -> $CLAUDE_DIR/settings.json"

# 4. Hooks — link each script individually (settings.json references them by
#    their stable ~/.claude/hooks/ path) so a pre-existing real hooks dir is
#    never clobbered.
for hook in "$DOTFILES_DIR/hooks/"*.sh; do
    [ -f "$hook" ] || continue
    chmod +x "$hook"
    name="$(basename "$hook")"
    ln -sfn "$hook" "$HOOKS_DIR/$name"
    echo "linked hook $name -> $HOOKS_DIR/$name"
done

# 5. Skills — link each skill DIRECTORY (Claude Code discovers
#    ~/.claude/skills/<name>/SKILL.md). -n so re-runs replace the link instead
#    of descending into it.
for skill_dir in "$DOTFILES_DIR/skills/"*/; do
    [ -f "$skill_dir/SKILL.md" ] || continue
    name="$(basename "$skill_dir")"
    ln -sfn "${skill_dir%/}" "$SKILLS_DIR/$name"
    echo "linked skill $name -> $SKILLS_DIR/$name"
done

echo ""
echo "Claude dotfiles installed. Restart Claude Code to pick up changes."
