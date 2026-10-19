#!/bin/bash
# device-shots.sh [--live] SCENARIO...: install the demo on a phone, have the app render SCENARIOs to PNG in its own process, fetch them.
# Needs local.env: DEVICE_ROOT (a Revenant port directory whose device.env names the phone), REVENANT_DEVICE_HOLDER; the phone
# must be claimed by that holder (xmake device claim). Results go to device-shots/ (git-ignored). Nothing here holds a secret.
set -u
cd "$(dirname "$0")"
[ -f local.env ] && . ./local.env
: "${DEVICE_ROOT:?set DEVICE_ROOT in local.env}" "${REVENANT_DEVICE_HOLDER:?set REVENANT_DEVICE_HOLDER in local.env}"
export REVENANT_DEVICE_HOLDER
on_device() { revenant --root "$DEVICE_ROOT" device run "${SECS:-60}" "$1"; }
app=SwiftUI/out/SwiftUIDemo.app
out=${OUT:-device-shots}; mkdir -p "$out"
tar_file=$(mktemp -t swiftui-demo).tgz
(cd SwiftUI/out && COPYFILE_DISABLE=1 tar czf "$tar_file" --exclude SwiftUITests --exclude SwiftUIProbe SwiftUIDemo.app)
revenant --root "$DEVICE_ROOT" device copy "$tar_file" /var/tmp/swiftui-demo.tgz >/dev/null
on_device "cd /Applications && tar xzf /var/tmp/swiftui-demo.tgz 2>/dev/null; chmod -R 755 SwiftUIDemo.app; su mobile -c uicache" >/dev/null
live=false; gesture=false
[ "${1:-}" = --live ] && { live=true; shift; }
[ "${1:-}" = --gesture ] && { gesture=true; shift; }
for scenario in "$@"; do
  if $gesture; then
    # show the scenario, run its real touches (see runDeviceGesture in the demo), picture the screen when the row is open
    on_device "killall SwiftUIDemo 2>/dev/null; sleep 1; rm -f /var/revenant/snapshots.on /var/revenant/snapshots.png /var/revenant/snapshots.only /var/tmp/swiftui-demo.log; printf %s $scenario > /var/revenant/show; printf %s $scenario > /var/revenant/gesture; chmod 666 /var/revenant/show /var/revenant/gesture; ${SBLAUNCH:-sblaunch} space.kern0x1b.swiftui.demo" >/dev/null
    for i in $(seq 1 60); do
      SECS=20 on_device "grep -a 'gesture: opened' /var/tmp/swiftui-demo.log" >/dev/null 2>&1 && break
      sleep 1
    done
    SECS=30 on_device "shot" >/dev/null
    revenant --root "$DEVICE_ROOT" device fetch /tmp/screenshot.png "$out/gesture-$scenario-open.png" >/dev/null 2>&1
    for i in $(seq 1 30); do
      SECS=20 on_device "grep -a 'gesture: done' /var/tmp/swiftui-demo.log" >/dev/null 2>&1 && break
      sleep 1
    done
    SECS=30 on_device "shot" >/dev/null
    revenant --root "$DEVICE_ROOT" device fetch /tmp/screenshot.png "$out/gesture-$scenario-after.png" >/dev/null 2>&1
    SECS=30 on_device "grep -a 'gesture\|swipe\|backports' /var/tmp/swiftui-demo.log; rm -f /var/revenant/show /var/revenant/gesture"
    echo "$scenario (gesture): $out/gesture-$scenario-open.png, $out/gesture-$scenario-after.png"
    continue
  fi
  if $live; then
    # keep the scenario on the real screen and take a picture of the screen itself
    on_device "killall SwiftUIDemo 2>/dev/null; sleep 1; rm -f /var/revenant/snapshots.on /var/revenant/snapshots.png /var/revenant/snapshots.only; printf %s $scenario > /var/revenant/show; chmod 666 /var/revenant/show; ${SBLAUNCH:-sblaunch} space.kern0x1b.swiftui.demo" >/dev/null
    sleep 8
    SECS=30 on_device "shot" >/dev/null
    revenant --root "$DEVICE_ROOT" device fetch /tmp/screenshot.png "$out/live-$scenario.png" >/dev/null 2>&1
    on_device "rm -f /var/revenant/show" >/dev/null
    echo "$scenario (live screen): $out/live-$scenario.png"
    continue
  fi
  on_device "killall SwiftUIDemo 2>/dev/null; sleep 1; rm -rf /var/revenant/swiftui-snapshots /var/tmp/swiftui-demo.log; touch /var/revenant/snapshots.on /var/revenant/snapshots.png; printf %s $scenario > /var/revenant/snapshots.only; chmod 666 /var/revenant/snapshots.*; ${SBLAUNCH:-sblaunch} space.kern0x1b.swiftui.demo" >/dev/null
  for i in $(seq 1 40); do
    log=$(SECS=20 on_device "grep -a 'snapshots done' /var/tmp/swiftui-demo.log" 2>/dev/null)
    [ -n "$log" ] && break
    sleep 3
  done
  if [ -z "$log" ]; then echo "$scenario: the app did not finish (crash report: /var/mobile/Library/Logs/CrashReporter/LatestCrash-SwiftUIDemo.plist)"; continue; fi
  for ext in png txt; do revenant --root "$DEVICE_ROOT" device fetch /var/revenant/swiftui-snapshots/$scenario.$ext "$out/$scenario.$ext" >/dev/null 2>&1; done
  echo "$scenario: $out/$scenario.png"
done
