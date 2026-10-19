#!/bin/sh
# run-shots.sh NAME APP SECONDS "S1 S2 ..." [CONTROL_SCRIPT] — boots iPhone3,1 iOS 6.0 with APP launched, snapshots Sn seconds after the launch request.
# CONTROL_SCRIPT lines "<seconds> <control command>" are sent relative to the launch request as well.
set -eu
LAB=$HOME/Git/projects/ios/emulator-lab
name=$1 app=$2 seconds=$3 shots=$4 control=${5:-}
identifier=$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")
source=$HOME/.charon/firmware/rootfs/iPhone3,1/6.0_10A403
run="$LAB/recompile/emu/runs.noindex/$name"
PREPARE='"$LAB/scripts/prepare-home.sh" "$ROOTFS"; install -d -m 0777 "$ROOTFS/private/var/charon"; "$LAB/scripts/install-app-test.sh" "$ROOTFS" "'"$app"'" "'"$identifier"'" '"$seconds"
(
  until grep -qs "launch-requested" "$run/rootfs/private/var/charon/events.log" || grep -qs '^exit=' "$run/log" 2>/dev/null; do sleep 1; done
  mkdir -p "$