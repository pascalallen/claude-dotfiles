#!/usr/bin/env bash
# Usage: land.sh <pr> <worktree>   (reads round.env from $ROUND_DIR; see SKILL.md)
set -euo pipefail

pr="$1"
wt="$2"
round="${ROUND_DIR:?set ROUND_DIR to the round folder}"
if [ -f "$round/round.env" ]; then
    # shellcheck disable=SC1091
    . "$round/round.env"
fi
log="$round/land-$pr.log"
ci_register="${CI_REGISTER_SECONDS:-180}"
ci_timeout="${CI_TIMEOUT_SECONDS:-3600}"

cd "$wt"
branch="$(git rev-parse --abbrev-ref HEAD)"
base="$(gh pr view "$pr" --json baseRefName -q .baseRefName)"
default="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
if [ "$base" != "$default" ]; then
    echo "HOLD $pr: base is $base, not $default. Land the base PR first, then: gh pr edit $pr --base $default"
    exit 2
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "DIRTY $pr: uncommitted changes in $wt"
    exit 2
fi

git fetch -q origin
if ! git merge-base --is-ancestor "origin/$base" HEAD; then
    if ! git merge -q --no-edit "origin/$base" >"$log" 2>&1; then
        git diff --name-only --diff-filter=U
        git merge --abort
        echo "CONFLICT $pr: resolve in $wt as $base's version plus this branch's own change, commit, re-add"
        exit 3
    fi
fi

if [ -n "${VERIFY_CMD:-}" ]; then
    if ! bash -c "$VERIFY_CMD" >>"$log" 2>&1; then
        echo "VERIFY-FAILED $pr: see $log"
        exit 4
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "VERIFY-CHANGED-FILES $pr: generated or formatted files differ; commit them in $wt, re-add"
        git status --porcelain
        exit 4
    fi
fi

git push -q origin "HEAD:$branch"
sha="$(git rev-parse HEAD)"
echo "PUSHED $pr $sha"

if [ "${REQUIRE_CI:-1}" = 1 ]; then
    waited=0
    while true; do
        runs="$(gh api "repos/{owner}/{repo}/commits/$sha/check-runs" -q '[.check_runs[] | {s: .status, c: .conclusion}]')"
        total="$(jq length <<<"$runs")"
        pending="$(jq '[.[] | select(.s != "completed")] | length' <<<"$runs")"
        bad="$(jq '[.[] | select(.s == "completed" and (.c | IN("success", "skipped", "neutral") | not))] | length' <<<"$runs")"
        if [ "$bad" -gt 0 ]; then
            echo "CI-FAILED $pr on $sha"
            exit 5
        fi
        if [ "$total" -gt 0 ] && [ "$pending" -eq 0 ]; then
            break
        fi
        if [ "$total" -eq 0 ] && [ "$waited" -ge "$ci_register" ]; then
            echo "CI-MISSING $pr: no check registered on $sha after ${ci_register}s (set REQUIRE_CI=0 only when CI is off and VERIFY_CMD mirrors it)"
            exit 5
        fi
        if [ "$waited" -ge "$ci_timeout" ]; then
            echo "CI-TIMEOUT $pr on $sha"
            exit 5
        fi
        sleep 30
        waited=$((waited + 30))
    done
    echo "CI-GREEN $pr $sha"
fi

gh pr merge "$pr" "--${MERGE_METHOD:-merge}" --match-head-commit "$sha" >>"$log" 2>&1 || true
state="$(gh pr view "$pr" --json state -q .state)"
if [ "$state" != MERGED ]; then
    echo "NOT-MERGED $pr: state $state, see $log"
    exit 6
fi
echo "MERGED $pr $sha"

children="$(gh pr list --base "$branch" --state open --json number -q length)"
if [ "$children" -eq 0 ]; then
    git push -q origin --delete "$branch" || echo "branch $branch already gone"
else
    echo "KEPT branch $branch: base of $children open PR(s)"
fi
