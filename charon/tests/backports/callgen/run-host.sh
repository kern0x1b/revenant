#!/bin/sh
# run-host.sh — the generated call test on the host, where it is the oracle.
#
# The host's own Intents.framework answers the same names the registry carries, so this run says
# two things: which of them the system has at all, and what it answers. Run it with
#   sh run-host.sh                       the Intents registry
#   FRAMEWORK=UIKit sh run-host.sh       another one the host carries The port's run says the
# same about libIntentsBackports, and compare.py puts the two side by side. Where they differ the
# registry's own reason is expected to say why - SF Symbols, Siri authorization, the system reading
# a value this port keeps in a store - and every other difference is a finding.
#
# Usage: sh run-host.sh [registry-dir ...]        default: the Intents registry
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
root=$(cd "$here/../../.." && pwd)
registry=${1:-$root/packages/a/apple-backports/registry/${FRAMEWORK:-Intents}}
build=${BUILD:-$(runs_fresh charon-callgen)}
out=${OUT:-$build/calls.log}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)

# The SDK the port compiles against, for the declarations the neutral arguments are read from.
port_sdk=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/*/*/iPhoneOS*.sdk 2>/dev/null | head -1)
if [ ! -d "$port_sdk" ]; then
    echo "no iphoneos-sdk in the store; CHARON_PORT_SDK must name one" >&2
    exit 1
fi
dump=$build/ast.json
if [ ! -d "$registry" ]; then
    echo "no such registry: $registry" >&2
    exit 1
fi
echo "registry: $registry"
python3 "$here/gen-calls.py" --sdk "$port_sdk" --registry "$registry" --dump "$dump" \
        --out "$build/Calls.m" --manifest "$build/calls.json"

# A Mac Catalyst binary binds the Command Line Tools' MacOSX.sdk/System/iOSSupport, and that
# directory carries IntentsUI but **not** Intents (measured 2026-09-27 on the host of that day),
# so a Catalyst run cannot be the oracle for this framework. The host's own Intents.framework -
# the one Siri and Shortcuts are built on, in /System/Library/Frameworks - is a macOS framework
# and is in the macOS SDK, so the oracle is a macOS binary linked against that. What it says
# about a name is about the system's own Intents, which is exactly what an oracle is for; the
# classes it does not carry are the iOS-only ones, and compare.py says so rather than failing.
xcrun clang -target arm64-apple-macos14.0 -isysroot "$sdk" \
    -fobjc-arc -Wall -Wno-unused-function \
    -I"$here" "$here/harness.m" "$here/main.m" "$build/Calls.m" \
    -framework Foundation -framework Intents -o "$build/calls" 2>"$build/build.log" || {
        echo "the call test did not build; $build/build.log says why" >&2
        tail -20 "$build/build.log" >&2
        exit 1
    }
"$build/calls" host "$out" || echo "the host run has findings; $out is what it found" >&2
echo "host digest: $out"
