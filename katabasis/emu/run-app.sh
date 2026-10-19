#!/bin/sh
# run-app.sh NAME APP SECONDS [TAP_AFTER] — boots iPhone3,1 iOS 6.0 with APP installed and launched.
set -eu
LAB=$HOME/Git/projects/ios/emulator-lab
name=$1 app=$2 seconds=$3 tap_after=${4:-0}
identifier=$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")
source=$HOME/.charon/firmware/rootfs/iPhone3,1/6.0_10A403
export ENVJSON='{"DYLD_INSERT_LIBRARIES":"/usr/local/lib/charon-inject.dylib"'
[ -n "${XL_ENV:-}" ] && ENVJSON="$ENVJSON,$XL_ENV"
ENVJSON="$ENVJSON}"
PREPARE='"$LAB/scripts/prepare-home.sh" "$ROOTFS"; install -d -m 0777 "$ROOTFS/private/var/charon"; "$LAB/scripts/install-app-test.sh" "$ROOTFS" "'"$app"'" "'"$identifier"'" '"$seconds"'; plutil -replace EnvironmentVariables -json "$ENVJSON" "$ROOTFS/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"' 
if [ "$tap_after" -gt 0 ]; then
  ( run="$LAB/recompile/emu/runs.noindex/$name"
    until grep -qs "app-alive|did-finish" "$run/rootfs/private/var/charon/uidemo.log" || grep -qs '^exit=' "$run/log" 2>/dev/null; do sleep 1; done
    sleep "$tap_after"; [ -p "$run/control" ] && printf 'snapshot %s\ntap 160 80\n' "$run/before-tap.png" > "$run/control"
    sleep 3; [ -p "$run/control" ] && printf "tap 100 150\n" > "$run/control"; sleep 4; [ -p "$run/control" ] && printf "snapshot %s\n" "$run/after-tap.png" > "$run/control" ) &
fi
PREPARE="$PREPARE" UNLOCK=1 "$LAB/recompile/emu/boot.sh" "$name" iPhone3,1 "$source" "$seconds"
run="$LAB/recompile/emu/runs.noindex/$name"
cat "$run/rootfs/private/var/charon/uidemo.log" 2>/dev/null || true
grep -a -E 'xlate:|\[cpu\] fatal|\[process\] exit .*signal=[1-9]|UIDEMO' "$run/log" | grep -v 'signal=30' | head -40
