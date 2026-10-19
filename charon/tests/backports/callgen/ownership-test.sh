#!/bin/sh
# ownership-test.sh - the copy's ownership decision, against properties declared the way the SDK's
# headers declare them, and the behaviour that decision produces.
#
# This is the negative control for the guard that matches a property to its backing ivar. That
# guard missed twice - a property's V_ field carries the ivar name without its leading underscore
# and ivar_getName() carries it with - and each time the effect was that every object ivar was
# copied, which no gate and no registry entry can see.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
root=$(cd "$here/../../.." && pwd)
build=${BUILD:-$(runs_fresh charon-callgen)}
mkdir -p "$build"
xcrun clang -target arm64-apple-macos26.0 -isysroot "$(xcrun --show-sdk-path)" -fobjc-arc -O0 -Wall \
    -I"$root/packages/a/apple-backports/Intents" \
    "$here/ownership-test.m" "$root/packages/a/apple-backports/Foundation/CharonCoding.m" \
    -framework Foundation -framework CoreLocation -o "$build/ownership" 2>"$build/build.log" || {
        echo "the ownership test did not build; $build/build.log says why" >&2
        tail -20 "$build/build.log" >&2
        exit 1
    }
"$build/ownership"
