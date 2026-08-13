#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"

# Iterate what is actually installed (not this repo's skill list) so links left
# behind by moved/deleted checkouts and removed skills get cleaned up too.
# Remove a symlink if it points into any claude-dotfiles checkout or dangles.
# Never touches real files or symlinks owned by anything else.
for link in "$SKILLS_DIR"/* "$CLAUDE_DIR/CLAUDE.md"; do
    [ -L "$link" ] || continue
    target="$(readlink "$link")"
    if [[ "$target" == */claude-dotfiles/* ]] || [ ! -e "$link" ]; then
        rm "$link"
        echo "removed $link -> $target"
    fi
done

echo ""
echo "Claude dotfiles uninstalled."
