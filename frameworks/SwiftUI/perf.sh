#!/bin/bash
# perf.sh: run the in-app timing scenarios (deep nested stacks, with colours and with text) in iLEmu and print them
set -u
cd "$(dirname "$0")"
name=perf-$(date +%H%M%S)
export PREPARE='install -d -m 0777 "$ROOTFS/private/var/revenant"; : > "$ROOTFS/private/var/revenant/perf.on"'
DONE="perf done" DONE_LOG=private/var/tmp/swiftui-demo.log DEV=iPod4,1 SRC=$HOME/.revenant/firmware/rootfs/iPod4,1/6.0_10A403 \
  ./run-app.sh $name SwiftUI/out/SwiftUIDemo.app ${SECONDS_BUDGET:-900} >/dev/null
grep -a "perf" runs.noindex/$name/swiftui-demo.log 2>/dev/null || echo "no timings were written"
