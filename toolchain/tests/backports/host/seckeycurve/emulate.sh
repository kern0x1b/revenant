#!/bin/sh
# tests/backports/device/seckey-ecraw.m in the emulator: what the release's own Security does with an
# elliptic key, which is the release side of facts/Security/SecKeyElliptic.md. One heavy job - a build
# and an emulated boot of 6.1.3 - so it runs in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/seckeycurve/emulate.sh
# The log is left in $SECKEYECRAW_BUILD - the script prints where - and the lines that matter are the
# ones that begin "release ". It has not run: nothing in this tree holds a run of it, and a path quoted
# for a run that never happened is a claim the tree cannot support.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
export SECKEYECRAW_ROOT=$(cd "$here/../../../.." && pwd)
build=${SECKEYECRAW_BUILD:-$(runs_folder charon-seckeyecraw)}
device=${SECKEYECRAW_DEVICE:-iPhone4,1}
release=${SECKEYECRAW_RELEASE:-6.1.3}
rm -rf "$build"
mkdir -p "$build"
cp "$here/emulate/xmake.lua" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
xmake emulate -d "$device" -r "$release" install > install.log 2>&1
xmake emulate -d "$device" -r "$release" run /usr/libexec/seckeyecraw > run.log 2>&1 || true
sed 's/\x1b\[[0-9;]*m//g' run.log | grep -E '^(release|done)' || { echo "the probe answered nothing:"; tail -20 run.log; exit 1; }
if ! grep -Eq 'pass.{0,12} on iPhone' run.log; then
    echo "the run was not a pass:"; sed 's/\x1b\[[0-9;]*m//g' run.log | tail -8; exit 1
fi
echo "logs=$build"
