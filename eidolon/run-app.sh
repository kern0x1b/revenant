#!/bin/bash
# run-app.sh NAME APP SECONDS [CONTROL_FILE]: SpringBoard boot of a rootfs clone with APP launched through the lab's charon-launch.
# DONE_LOG (path inside the rootfs) and DONE (text): quit as soon as DONE appears in DONE_LOG instead of waiting out SECONDS.
# CONTROL_FILE lines "<seconds after launch-requested> <ilemu control command>" (e.g. "20 snapshot shot1.png", "25 tap 160 200").
set -u
[ -f "$(dirname "$0")/local.env" ] && . "$(dirname "$0")/local.env"
LAB=${EMULATOR_LAB:?set EMULATOR_LAB to the emulator lab checkout (see README, Requirements)}
name=$1 app=$2 seconds=$3 control=${4:-}
DEV=${DEV:-iPhone4,1}; SRC=${SRC:-$HOME/.charon/firmware/rootfs/$DEV/6.1.3_10B329}
identifier=$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")
run=$PWD/runs.noindex/$name
[ -e "$run" ] && { echo "run $run exists" >&2; exit 1; }
mkdir -p "$run/tmp"
cp -c -R "$SRC" "$run/rootfs"
"$LAB/scripts/prepare-home.sh" "$run/rootfs"
install -d -m 0777 "$run/rootfs/private/var/charon"
"$LAB/scripts/install-app-test.sh" "$run/rootfs" "$app" "$identifier" "$seconds" >/dev/null
[ -n "${PREPARE:-}" ] && ROOTFS="$run/rootfs" IMAGES="${IMAGES:-}" ONLY="${ONLY:-}" sh -ec "$PREPARE"
build=$(plutil -extract ProductBuildVersion raw "$SRC/System/Library/CoreServices/SystemVersion.plist")
mkfifo "$run/control"
( sleep "$seconds"; echo quit ) > "$run/control" &
budget=$!; disown $budget
[ -n "${DONE:-}" ] && (
  until grep -qs "$DONE" "$run/rootfs/${DONE_LOG:-}" || grep -qs '^exit=' "$run/log" 2>/dev/null; do sleep 2; done
  sleep 2; [ -p "$run/control" ] && printf 'quit\n' > "$run/control"
) &
(
  events="$run/rootfs/private/var/charon/events.log" waited=0
  until grep -qs "did-finish-launching pid=[0-9]* SpringBoard" "$events" || [ "$waited" -ge 400 ]; do sleep 2; waited=$((waited + 2)); done
  until grep -qs "launch-requested" "$events" || grep -qs '^exit=' "$run/log"; do
    [ -p "$run/control" ] && printf 'home\n' > "$run/control"; sleep 3; [ -p "$run/control" ] && printf 'unlock\n' > "$run/control"
    waited=0
    until grep -qs "launch-requested" "$events" || [ "$waited" -ge 20 ]; do sleep 1; waited=$((waited + 1)); done
  done
) &
(
  until grep -qs "launch-requested" "$run/rootfs/private/var/charon/events.log" || grep -qs '^exit=' "$run/log" 2>/dev/null; do sleep 1; done
  date +%s > "$run/launch-requested"
  [ -n "$control" ] && while read -r at cmd; do
    [ -z "$at" ] && continue
    now=$(( $(date +%s) - $(cat "$run/launch-requested") ))
    [ "$at" -gt "$now" ] && sleep $(( at - now ))
    case "$cmd" in snapshot*) cmd="snapshot $run/${cmd#snapshot }";; esac
    [ -p "$run/control" ] && printf '%s\n' "$cmd" > "$run/control"
  done < "$control"
) &
start=$(date +%s)
env TMPDIR="$run/tmp" VK_ICD_FILENAMES="$LAB/deps/build-swiftshader/Darwin/vk_swiftshader_icd.json" \
  "${ILEMU:-$("$LAB/scripts/ilemu.sh")}" boot --rootfs "$run/rootfs" --device "$DEV" --host-cache "${HOSTCACHE:-$LAB/cache/${DEV}_$build}" \
  --display headless --gles-backend software --control-stdin --frame-output "$run/frame.png" < "$run/control" > "$run/log" 2>&1
echo "exit=$? elapsed=$(( $(date +%s) - start ))" >> "$run/log"
pkill -P $budget 2>/dev/null; kill $budget 2>/dev/null
exec 3<> "$run/control"; sleep 1; exec 3<&-; rm -f "$run/control"
cp "$run/rootfs/private/var/charon/events.log" "$run/" 2>/dev/null
cp "$run/rootfs/private/var/tmp/eidolon-demo.log" "$run/" 2>/dev/null
ls "$run/rootfs/private/var/mobile/Library/Logs/CrashReporter/" 2>/dev/null | head > "$run/crashes.txt"
cp -R "$run/rootfs/private/var/mobile/Library/Logs/CrashReporter" "$run/CrashReporter" 2>/dev/null
[ -n "${KEEPROOT:-}" ] || { chmod -R u+w "$run/rootfs" "$run/tmp"; rm -rf "$run/rootfs" "$run/tmp"; }
tail -1 "$run/log"
