#!/bin/bash
for RUNDIR in "$@"; do
    LOG="$RUNDIR/host.log"
    START=$(grep "react start" "$LOG" | head -1 | awk '{split($2,t,":"); print t[1]*3600+t[2]*60+t[3]}')
    MOUNTED=$(grep "bench mounted" "$LOG" | head -1 | awk '{split($2,t,":"); print t[1]*3600+t[2]*60+t[3]}')
    STARTUP=$(awk -v a="$START" -v b="$MOUNTED" 'BEGIN{printf "%.2f", b-a}')
    LATENCY=$(grep -o "touch began [0-9]*\|bench commit [0-9]* [0-9]*" "$LOG" | awk '/touch began/{t=$3} /bench commit/{print $4-t}' | sort -n | tr '\n' ' ')
    MEDIAN=$(echo $LATENCY | awk '{n=NF; if (n%2) print $(int(n/2)+1); else print ($(n/2)+$(n/2+1))/2}')
    FPS=$(grep -o "bench fps [0-9]*" "$LOG" | awk '{n++; s+=$3; if (min=="" || $3<min) min=$3} END {printf "%.1f %s", s/n, min}')
    RSS=$(grep -o "heartbeat rss [0-9.]*" "$LOG" | awk '{v=$3; if (max=="" || v>max) max=v} END {print max}')
    echo "$(basename "$RUNDIR") startup_s=$STARTUP latency_ms=[$LATENCY] median_ms=$MEDIAN fps_mean_min=$FPS rss_max_mb=$RSS"
done
