#!/usr/bin/env bash
# Usage: landq.sh add <pr> <worktree> | landq.sh run | landq.sh status   (ROUND_DIR must be set)
set -uo pipefail

round="${ROUND_DIR:?set ROUND_DIR to the round folder}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
queue="$round/queue.txt"
finished="$round/done.txt"
out="$round/landq.out"
pidfile="$round/landq.pid"
touch "$queue" "$finished"

case "${1:-}" in
add)
    echo "$2 $3 $(date +%s)" >>"$queue"
    echo "queued #$2"
    exit 0
    ;;
status)
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then echo "runner up, pid $(cat "$pidfile")"; else echo "runner down"; fi
    [ -e "$round/STOP" ] && echo "STOP present: gate failed, fix the default branch, then remove $round/STOP"
    echo "waiting:"
    grep -vxF -f "$finished" "$queue" || true
    exit 0
    ;;
run) ;;
*)
    sed -n 2p "${BASH_SOURCE[0]}"
    exit 64
    ;;
esac

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo "runner already up, pid $(cat "$pidfile")"
    exit 1
fi
if [ -z "${LANDQ_AWAKE:-}" ] && command -v caffeinate >/dev/null 2>&1; then
    LANDQ_AWAKE=1 exec caffeinate -i bash "${BASH_SOURCE[0]}" run
fi
echo $$ >"$pidfile"
exec >>"$out" 2>&1
if [ -f "$round/round.env" ]; then
    # shellcheck disable=SC1091
    . "$round/round.env"
fi

while true; do
    if [ -e "$round/STOP" ]; then
        sleep 60
        continue
    fi
    line="$(grep -vxF -f "$finished" "$queue" | head -n 1)"
    if [ -z "$line" ]; then
        sleep 60
        continue
    fi
    read -r pr wt _ <<<"$line"
    echo "=== $(date '+%F %H:%M') #$pr"
    if bash "$here/land.sh" "$pr" "$wt"; then
        if [ -n "${GATE_CMD:-}" ]; then
            if bash -c "$GATE_CMD" >"$round/gate-$pr.log" 2>&1; then
                echo "GATE-OK #$pr"
            else
                echo "GATE-FAILED #$pr: see $round/gate-$pr.log (queue paused)"
                touch "$round/STOP"
            fi
        fi
    else
        echo "FAILED #$pr: fix, then add it again"
    fi
    echo "$line" >>"$finished"
done
