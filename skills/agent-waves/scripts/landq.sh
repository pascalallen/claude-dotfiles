#!/usr/bin/env bash
# Usage: landq.sh add <pr> <worktree> | landq.sh run | landq.sh status | landq.sh wait [max-seconds]   (ROUND_DIR must be set)
set -uo pipefail

round="${ROUND_DIR:?set ROUND_DIR to the round folder}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
queue="$round/queue.txt"
finished="$round/done.txt"
out="$round/landq.out"
pidfile="$round/landq.pid"
seenfile="$round/landq.seen"
touch "$queue" "$finished"

out_size() {
    if [ -f "$out" ]; then wc -c <"$out" | tr -d ' '; else echo 0; fi
}

runner_up() {
    [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

pending() {
    grep -vxF -f "$finished" "$queue" || true
}

show_status() {
    if runner_up; then echo "runner up, pid $(cat "$pidfile")"; else echo "runner down"; fi
    [ -e "$round/STOP" ] && echo "STOP present: gate failed, fix the default branch, then remove $round/STOP"
    echo "waiting:"
    pending
}

case "${1:-}" in
add)
    [ -f "$seenfile" ] || out_size >"$seenfile"
    echo "$2 $3 $(date +%s)" >>"$queue"
    echo "queued #$2"
    exit 0
    ;;
status)
    show_status
    exit 0
    ;;
wait)
    max="${2:-5400}"
    poll="${LANDQ_WAIT_POLL:-15}"
    touch "$out"
    end="$(out_size)"
    if [ -f "$seenfile" ]; then start="$(cat "$seenfile")"; else start="$end"; fi
    read_new() {
        end="$(out_size)"
        if [ "$end" -lt "$start" ]; then start=0; fi
        if [ "$end" -eq "$start" ]; then
            new=""
        else
            new="$(tail -c +"$((start + 1))" "$out" | head -c "$((end - start))")"
        fi
    }
    finish() {
        [ -n "$new" ] && printf '%s\n' "$new"
        echo "$end" >"$seenfile"
        show_status
        exit "$1"
    }
    waiting="$(pending)"
    read_new
    if [ -e "$round/STOP" ]; then
        finish 3
    fi
    if [ -z "$waiting" ]; then
        [ -n "$new" ] || echo "nothing queued, no new results"
        finish 0
    fi
    first="$(head -n 1 <<<"$waiting")"
    gate="$(
        set +u
        # shellcheck disable=SC1091
        [ -f "$round/round.env" ] && . "$round/round.env" >/dev/null 2>&1
        printf '%s' "${GATE_CMD:-}"
    )"
    if [ -n "$gate" ]; then
        terminal='^(GATE-OK #|GATE-FAILED|FAILED #)'
    else
        terminal='^(MERGED |FAILED #)'
    fi
    waited=0
    while true; do
        isdone=0
        grep -qxF -e "$first" "$finished" && isdone=1
        read_new
        if [ "$isdone" = 1 ] || grep -qE "$terminal" <<<"$new"; then
            finish 0
        fi
        if [ -e "$round/STOP" ]; then
            finish 3
        fi
        if ! runner_up; then
            echo "runner down: start it again with landq.sh run, then wait again"
            finish 2
        fi
        if [ "$waited" -ge "$max" ]; then
            current="$(pending | head -n 1 | cut -d' ' -f1)"
            echo "still running after ${max}s (#${current:-none}); wait again. Tail of its log:"
            [ -n "$current" ] && tail -n 5 "$round/land-$current.log" 2>/dev/null
            finish 4
        fi
        sleep "$poll"
        waited=$((waited + poll))
    done
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
