#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"

# Remove CLAUDE.md symlink only if it points to this repo
target="$CLAUDE_DIR/CLAUDE.md"
if [ -L "$target" ] && [ "$(readlink "$target")" = "$DOTFILES_DIR/CLAUDE.md" ]; then
    rm "$target"
    echo "removed CLAUDE.md symlink"
fi

# Remove skill symlinks only if they point to this repo
for skill in "$DOTFILES_DIR/skills/"*.md; do
    [ -e "$skill" ] || continue
    skill_name=$(basename "$skill")
    link="$SKILLS_DIR/$skill_name"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$skill" ]; then
        rm "$link"
        echo "removed $skill_name symlink"
    fi
done

echo ""
echo "Claude dotfiles uninstalled."
