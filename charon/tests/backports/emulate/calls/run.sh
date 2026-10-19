#!/bin/sh
# run.sh — the generated call test on the port, in the emulator, against libIntentsBackports.
#
# The same generated file the host runs (tools/callgen/run-host.sh runs the system's own
# Intents.framework, this runs the port's), so the two digests are the same measurement of the
# same registry: compare.py puts them side by side.
#
# Usage: sh tests/backports/emulate/calls/run.sh [--minimum 6.1.3] [--no-package]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
callgen=$(cd "$here/../../callgen" && pwd)
root=$(cd "$here/../../../.." && pwd)
minimum=6.1.3
package=1
while [ $# -gt 0 ]; do
    case "$1" in
        --minimum) minimum=$2; shift 2 ;;
        --no-package) package=0; shift ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done
work=${WORK:-$here/.agent-work}
generated=$work/generated
mkdir -p "$generated" "$work/runs"

# The generated file the port builds, from the registry of the framework under test.
registry=${REGISTRY:-$root/packages/a/apple-backports/registry/${FRAMEWORK:-Intents}}
port_sdk=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/*/*/iPhoneOS*.sdk 2>/dev/null | head -1)
[ -d "$port_sdk" ] || { echo "no iphoneos-sdk in the store" >&2; exit 1; }
python3 "$callgen/gen-calls.py" --sdk "$port_sdk" --registry "$registry" \
        --dump "$work/ast.json" --out "$generated/Calls.m" --manifest "$generated/calls.json"

stamp=$(date +%Y%m%d-%H%M%S)
out=$work/runs/calls-$minimum-$stamp
mkdir -p "$out"
cd "$here"
xmake f -p iphoneos -a armv7 -y >"$out/configure.log" 2>&1 || {
    echo "the call test port did not configure; $out/configure.log says why" >&2
    tail -20 "$out/configure.log" >&2
    exit 1
}
xmake emulate -r "$minimum" install >"$out/install.log" 2>&1 || {
    echo "the call test did not install; $out/install.log says why" >&2
    tail -20 "$out/install.log" >&2
    exit 1
}
# The command is where the port's daemon rule installs it: /usr/libexec/<name>, which is what
# the tree's other emulator checks run (tests/backports/device/display-probe/run.sh runs
# /usr/libexec/display-probe). An install that does not put the binary there is
# `fail(spawn error 2)`, and it is the install that is wrong, not the release.
CHARCALLS_ROOT=$root CHARCALLS_MINIMUM=$minimum CHARCALLS_GENERATED=$generated \
CHARCALLS_PACKAGE=$package xmake emulate -r "$minimum" run /usr/libexec/charoncalls \
    port "$out/calls.log" >"$out/run.log" 2>&1 || echo "the port run has findings; $out/calls.log is what it found" >&2
xmake emulate -r "$minimum" log >"$out/emulate.log" 2>&1 || true
echo "port digest: $out/calls.log"
echo "port run log: $out/run.log"
