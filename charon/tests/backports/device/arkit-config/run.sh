#!/bin/sh
# tests/backports/device/arkit-config/arkit-config.m on an emulated 4S under 6.1.3, with charon@apple-backports linked, so the
# configurations are the library's own. One heavy job (a package build and an emulated boot), so run it in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/arkit-config/run.sh
# ARKITCONFIG_DEVICE and ARKITCONFIG_RELEASE name the device and release (iPhone4,1 and 6.1.3 by default: the fleet's 4S); the
# build and the logs go to ARKITCONFIG_BUILD (default .agent-work/runs/arkit-config under the checkout).
# Exits 1 on a configure, build or install failure, on a run that printed no verdict, and on any FAIL line.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=${ARKITCONFIG_ROOT:-$(cd "$here/../../../.." && pwd)}
export ARKITCONFIG_ROOT=$root
device=${ARKITCONFIG_DEVICE:-iPhone4,1}
release=${ARKITCONFIG_RELEASE:-6.1.3}
build=${ARKITCONFIG_BUILD:-$root/.agent-work/runs/arkit-config}

rm -rf "$build"
mkdir -p "$build"
cp "$here/xmake.lua" "$here/control" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1 || { echo "configure failed:"; tail -20 configure.log; exit 1; }
xmake build -y > build.log 2>&1 || { echo "the build failed:"; tail -20 build.log; exit 1; }
xmake emulate -d "$device" -r "$release" install > install.log 2>&1 || { echo "the install failed:"; tail -20 install.log; exit 1; }
xmake emulate -d "$device" -r "$release" run /usr/libexec/arkitconfig > "$release.log" 2>&1 || true

# The verdict line is `pass` or `fail` between colour codes; the checks are printed one per line.
sed 's/\x1b\[[0-9;]*m//g' "$release.log" > "$release.plain"
if grep -q '^FAIL' "$release.plain"; then
    echo "$release: failures"
    grep '^FAIL' "$release.plain"
    exit 1
fi
if ! grep -qx 'pass' "$release.plain"; then
    echo "$release: no pass verdict"
    tail -20 "$release.plain"
    exit 1
fi
grep 'arkitconfig: [0-9]* checks' "$release.plain" | tail -1
