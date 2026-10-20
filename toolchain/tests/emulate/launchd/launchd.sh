#!/bin/bash
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../backports/common/runs.sh" "$here"
device=${1:-iPhone4,1}
release=${2:-6.1.3}
out=${OUT_DIR:-$(runs_folder emulate-launchd)}
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
