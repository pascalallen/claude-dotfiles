#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
refs="${CLAUDE_PRIVATE_REFS:-$HOME/.claude/private-references.md}"
fail=0

jq empty settings.json

if git grep -n -I 'pluginConfigs' -- . ':!check.sh' ':!README.md'; then
    echo "check: plugin config belongs in a settings.local.json, not here" >&2
    fail=1
fi

if [ -f "$refs" ]; then
    # shellcheck disable=SC2016
    terms="$( { grep -oE '^- (\*\*Name:\*\* )?`pascalallen/[A-Za-z0-9_.-]+`' "$refs" | grep -oE 'pascalallen/[A-Za-z0-9_.-]+' | cut -d/ -f2 || true; grep -iE '^- \*\*Private terms:\*\*' "$refs" | grep -oE '`[^`]+`' | tr -d '`' || true; } | sort -u )"
    for t in $terms; do
        if git grep -n -I -i -w -F -e "$t" -- . ; then
            echo "check: private name '$t' found in a tracked file" >&2
            fail=1
        fi
    done
else
    echo "check: $refs not found, private-name check skipped" >&2
fi

for s in ./*.sh hooks/*.sh skills/*/scripts/*.sh .githooks/*; do
    [ -f "$s" ] || continue
    bash -n "$s"
done
if command -v shellcheck >/dev/null 2>&1; then
    scripts=(./*.sh hooks/*.sh .githooks/*)
    for s in skills/*/scripts/*.sh; do
        [ -f "$s" ] && scripts+=("$s")
    done
    shellcheck "${scripts[@]}"
fi

exit "$fail"
