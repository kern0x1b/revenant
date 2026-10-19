#!/bin/bash
# launchd.sh [DEVICE] [RELEASE]: the order of a run, measured on a real guest. The program
# (main.c) runs as the guest's test and asks launchd for the Mach services of the firmware's
# LaunchDaemons at its first instruction; it exits 0 when each of them was already registered. The
# run's own verdict is the check:
#
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/emulate/launchd/launchd.sh iPhone4,1 6.1.3
#
# CHARON_REPO names the checkout whose emulator-guest package (the runner) is run, CHARON_ADDON
# the addon whose emulator module installs it. A runner that starts the program before launchd has
# loaded the daemons fails, and the lines it prints name the services that were not there.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
device=${1:-iPhone4,1}
release=${2:-6.1.3}
out=${OUT_DIR:-$here/../../../.agent-work/runs/emulate-launchd}
rm -rf "$out"
mkdir -p "$out"
cp "$here/xmake.lua" "$here/control" "$here/main.c" "$out/"
cd "$out"
xmake f -c -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
xmake emulate -d "$device" -r "$release" install > install.log 2>&1
ran=0
xmake emulate -d "$device" -r "$release" -s 240 -t 1500 run /usr/libexec/emulatelaunchd > run.log 2>&1 || ran=$?
grep -a "^probe:" run.log || echo "the run printed no probe line: the program did not run, see $out/run.log" >&2
echo "the run itself exited $ran"
exit "$ran"
