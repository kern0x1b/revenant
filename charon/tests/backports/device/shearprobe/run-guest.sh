#!/bin/sh
# run-guest.sh - the emulator run of the shear probe, and nothing else.
#
# IT IS A SEPARATE SCRIPT BECAUSE IT IS THE ONLY HEAVY PART of this case. Configure, build and install are a
# package build and a few seconds of compile; the run boots a guest and holds a slot of the machine for a minute
# or two (AGENTS.md section 8). The whole procedure stays runnable as one command (`sh run.sh`, which calls
# this), and the guest alone can be queued:
#
#   $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/shearprobe/run-guest.sh
#
# The LC_UUID gate is in run.sh and has already passed by the time this runs; this script re-checks nothing and
# re-installs nothing, so it must not be run against an image the gate has not cleared.
#
# `xmake emulate run` is given a BARE PATH and no arguments: with arguments it answers "fail(spawn error 2)"
# even for a system binary (coordinator, measured on the v-crutch5 runs of 2026-10-04).
#
# THE EXIT STATUS IS NOT THE VERDICT. `xmake emulate run` exits non-zero on a failed verdict BY DESIGN - a FAIL
# is a result - so `|| true` keeps that exit from stopping the script before the output is read, and what is
# decided here is the probe's own last line and the emulator's own word on the line that names the device.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out="$here/run"
device=${SHEARPROBE_DEVICE:-iPhone3,1}
release=${SHEARPROBE_RELEASE:-6.1.3}
xmake=/opt/homebrew/bin/xmake
mkdir -p "$out"
cd "$here"

"$xmake" emulate -d "$device" -r "$release" -t 900 -s 300 run "/usr/libexec/shear-probe" > "$out/run.log" 2>&1 || true
"$xmake" emulate log > "$out/guest.log" 2>&1 || true

summary=$(grep -a '^shearprobe: ' "$out/run.log" | tail -1 || true)
verdict_line=$(grep -a 'on iPhone' "$out/run.log" | tail -1 || true)
if [ -z "$summary" ]; then
  echo "run-guest.sh: the run left no summary line, so the probe did not finish; the log is $out/run.log"
  exit 1
fi
printf 'run-guest.sh: %s\n' "$summary"
if [ -n "$verdict_line" ]; then
  printf 'run-guest.sh: the emulator says: %s\n' "$verdict_line"
fi
echo "run-guest.sh: the full log is $out/run.log and the guest's own output $out/guest.log"

# The probe's own last line counts its cases and how many ended on a signal. A run where a case ended on a
# signal has NOT measured that case, whatever else it measured, and this is where that is said rather than in a
# file for a reader to find.
case "$summary" in
  *", 0 ended on a signal"*) exit 0 ;;
  *) echo "run-guest.sh: NOT a clean measurement - a case ended on a signal, so its answer is not here"; exit 1 ;;
esac