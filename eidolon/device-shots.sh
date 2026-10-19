#!/bin/bash
# device-shots.sh [--live] SCENARIO...: install the demo on a phone, have the app render SCENARIOs to PNG in its own process, fetch them.
# Needs local.env: DEVICE_ROOT (a Charon port directory whose device.env names the phone), CHARON_DEVICE_HOLDER; the phone
# must be claimed by that holder (xmake device claim). Results go to device-shots/ (git-ignored). Nothing here holds a secret.
set -u
cd "$(dirname "$0")"
[ -f local.env ] && . ./local.env
: "${DEVICE_ROOT:?set DEVICE_ROOT in local.env}" "${CHARON_DEVICE_HOLDER:?set CHARON_DEVICE_HOLDER in local.env}"
export CHARON_DEVICE_HOLDER
on_device() { charon --root "$DEVICE_ROOT" device run "${SECS:-60}" "$1"; }
app=eidolon/out/EidolonDemo.app
out=${OUT:-device-shots}; mkdir -p "$out"
tar_file=$(mktemp -t eidolon-demo).tgz
(cd eidolon/out && COPYFILE_DISABLE=1 tar czf "$tar_file" --exclude EidolonTests --exclude EidolonProbe EidolonDemo.app)
charon --root "$DEVICE_ROOT" device copy "$tar_file" /var/tmp/eidolon-demo.tgz >/dev/null
on_device "cd /Applications && tar xzf /var/tmp/eidolon-demo.tgz 2>/dev/null; chmod -R 755 EidolonDemo.app; su mobile -c uicache" >/dev/null
live=false; gesture=false
[ "${1:-}" = --live ] && { live=true; shift; }
[ "${1:-}" = --gesture ] && { gesture=true; shift; }
for scenario in "$@"; do
  if $gesture; then
    # show the scenario, run its real touches (see runDeviceGesture in the demo), picture the screen when the row is open
    on_device "killall EidolonDemo 2>/dev/null; sleep 1; rm -f /var/charon/snapshots.on /var/charon/snapshots.png /var/charon/snapshots.only /var/tmp/eidolon-demo.log; printf %s $scenario > /var/charon/show; printf %s $scenario > /var/charon/gesture; chmod 666 /var/charon/show /var/charon/gesture; ${SBLAUNCH:-sblaunch} space.kern0x1b.eidolon.demo" >/dev/null
    for i in $(seq 1 60); do
      SECS=20 on_device "grep -a 'gesture: opened' /var/tmp/eidolon-demo.log" >/dev/null 2>&1 && break
      sleep 1
    done
    SECS=30 on_device "shot" >/dev/null
    charon --root "$DEVICE_ROOT" device fetch /tmp/screenshot.png "$out/gesture-$scenario-open.png" >/dev/null 2>&1
    for i in $(seq 1 30); do
      SECS=20 on_device "grep -a 'gesture: done' /var/tmp/eidolon-demo.log" >/dev/null 2>&1 && break
      sleep 1
    done
    SECS=30 on_device "shot" >/dev/null
    charon --root "$DEVICE_ROOT" device fetch /tmp/screenshot.png "$out/gesture-$scenario-after.png" >/dev/null 2>&1
    SECS=30 on_device "grep -a 'gesture\|swipe\|backports' /var/tmp/eidolon-demo.log; rm -f /var/charon/show /var/charon/gesture"
    echo "$scenario (gesture): $out/gesture-$scenario-open.png, $out/gesture-$scenario-after.png"
    continue
  fi
  if $live; then
    # keep the scenario on the real screen and take a picture of the screen itself
    on_device "killall EidolonDemo 2>/dev/null; sleep 1; rm -f /var/charon/snapshots.on /var/charon/snapshots.png /var/charon/snapshots.only; printf %s $scenario > /var/charon/show; chmod 666 /var/charon/show; ${SBLAUNCH:-sblaunch} space.kern0x1b.eidolon.demo" >/dev/null
    sleep 8
    SECS=30 on_device "shot" >/dev/null
    charon --root "$DEVICE_ROOT" device fetch /tmp/screenshot.png "$out/live-$scenario.png" >/dev/null 2>&1
    on_device "rm -f /var/charon/show" >/dev/null
    echo "$scenario (live screen): $out/live-$scenario.png"
    continue
  fi
  on_device "killall EidolonDemo 2>/dev/null; sleep 1; rm -rf /var/charon/eidolon-snapshots /var/tmp/eidolon-demo.log; touch /var/charon/snapshots.on /var/charon/snapshots.png; printf %s $scenario > /var/charon/snapshots.only; chmod 666 /var/charon/snapshots.*; ${SBLAUNCH:-sblaunch} space.kern0x1b.eidolon.demo" >/dev/null
  for i in $(seq 1 40); do
    log=$(SECS=20 on_device "grep -a 'snapshots done' /var/tmp/eidolon-demo.log" 2>/dev/null)
    [ -n "$log" ] && break
    sleep 3
  done
  if [ -z "$log" ]; then echo "$scenario: the app did not finish (crash report: /var/mobile/Library/Logs/CrashReporter/LatestCrash-EidolonDemo.plist)"; continue; fi
  for ext in png txt; do charon --root "$DEVICE_ROOT" device fetch /var/charon/eidolon-snapshots/$scenario.$ext "$out/$scenario.$ext" >/dev/null 2>&1; done
  echo "$scenario: $out/$scenario.png"
done
