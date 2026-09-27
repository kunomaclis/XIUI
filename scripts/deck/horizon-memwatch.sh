#!/usr/bin/env bash
# Samples the HorizonXI client's memory once a minute while it runs.
# One CSV per day: ~/HorizonLogs/memwatch-YYYY-MM-DD.csv
# Columns: time,pid,vmsize_kb,vmrss_kb,vmpeak_kb,threads
# The client is 32-bit LAA: VmSize near 4,194,304 kB means address-space exhaustion.
# Run by the horizon-memwatch systemd user service.

LOGDIR="${HORIZON_LOGDIR:-$HOME/HorizonLogs}"
INTERVAL="${MEMWATCH_INTERVAL:-60}"
mkdir -p "$LOGDIR"

while :; do
    # Several wine/proton processes match; the game is the one with the largest VmSize.
    pid=$(for p in $(pgrep -f horizon-loader.exe); do
        awk -v p="$p" '/^VmSize/{print $2, p}' "/proc/$p/status" 2>/dev/null
    done | sort -rn | awk 'NR==1{print $2}')

    if [ -n "$pid" ]; then
        f="$LOGDIR/memwatch-$(date +%F).csv"
        [ -s "$f" ] || echo "time,pid,vmsize_kb,vmrss_kb,vmpeak_kb,threads" > "$f"
        awk -v t="$(date +%T)" -v p="$pid" '
            /^VmSize/{s=$2} /^VmRSS/{r=$2} /^VmPeak/{k=$2} /^Threads/{h=$2}
            END{if (s) print t "," p "," s "," r "," k "," h}' "/proc/$pid/status" 2>/dev/null >> "$f"
    fi
    sleep "$INTERVAL"
done
