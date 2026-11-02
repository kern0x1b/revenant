#!/bin/bash
set -u
ENGINE="$1"
RUN="$2"
BUNDLE="$3"
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
OUT="$ROOT/.cache/scratch/rn-bench/runs/$ENGINE-$RUN"
WAIT="${WAIT:-40}"
DEVICE="${REVENANT_DEVICE:-iphone}"
export REVENANT_CACHE="${REVENANT_CACHE:-$ROOT/.cache}"
export REVENANT_DEVICE="$DEVICE"
TOUCH=frameworks/ReactNative/tools/touch.lua
mkdir -p "$OUT"
cd "$ROOT" || exit 1
./xmakew device -d "$DEVICE" -s 150 run "printf 'engine=$ENGINE\nbundle=$BUNDLE\nmodule=bench\n' > /var/tmp/rnhost.conf; killall RNHost 2>/dev/null; sleep 3; rm -f /var/tmp/rnhost.log; /usr/libexec/revenant-sblaunch org.revenant.rnhost.hermes; sleep $WAIT" > "$OUT/launch.txt" 2>&1
for i in 1 2 3 4 5; do
    ./xmakew l -P . "$TOUCH" --wait 1 tap 120 110 2>&1 | tail -1 >> "$OUT/touch.txt"
    sleep 2
done
./xmakew l -P . "$TOUCH" --wait 1 swipe 160 420 160 150 600 2>&1 | tail -1 >> "$OUT/touch.txt"
sleep 6
./xmakew device -d "$DEVICE" run '/usr/libexec/revenant-shot /tmp/screenshot.png' >> "$OUT/launch.txt" 2>&1
./xmakew l -P . frameworks/SwiftUI/tools/device.lua fetch /tmp/screenshot.png "$OUT/screen.png" >> "$OUT/launch.txt" 2>&1
./xmakew l -P . frameworks/SwiftUI/tools/device.lua fetch /var/tmp/rnhost.log "$OUT/host.log" >> "$OUT/launch.txt" 2>&1
echo "$OUT"
