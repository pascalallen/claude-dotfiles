#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): gofmt any .go file Claude just touched, so
# unformatted Go never survives to a commit — the "run gofmt before finishing"
# rule enforced by the harness instead of remembered by the model.
#
# Exit 0 in every non-Go / no-tooling case: a hook failure here should never
# block an edit.
set -uo pipefail

input="$(cat)"

file_path=""
if command -v jq >/dev/null 2>&1; then
    file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
    file_path="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))' 2>/dev/null)"
fi

[[ "$file_path" == *.go ]] || exit 0
[ -f "$file_path" ] || exit 0
command -v gofmt >/dev/null 2>&1 || exit 0

gofmt -w "$file_path"
