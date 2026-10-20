#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=${ARKITCONFIG_ROOT:-$(cd "$here/../../../.." && pwd)}
export ARKITCONFIG_ROOT=$root
device=${ARKITCONFIG_DEVICE:-iPhone4,1}
release=${ARKITCONFIG_RELEASE:-6.1.3}
build=${ARKITCONFIG_BUILD:-$(runs_folder arkit-config)}

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
