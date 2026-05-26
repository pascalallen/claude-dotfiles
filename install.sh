#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"

mkdir -p "$SKILLS_DIR"

# Symlink CLAUDE.md
ln -sf "$DOTFILES_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "linked CLAUDE.md -> $CLAUDE_DIR/CLAUDE.md"

# Symlink each skill
for skill in "$DOTFILES_DIR/skills/"*.md; do
    [ -e "$skill" ] || continue
    skill_name=$(basename "$skill")
    ln -sf "$skill" "$SKILLS_DIR/$skill_name"
    echo "linked $skill_name -> $SKILLS_DIR/$skill_name"
done

echo ""
echo "Claude dotfiles installed. Restart Claude Code to pick up changes."
