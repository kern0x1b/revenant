#!/bin/bash
# surface-swiftui.sh [SDK26] > apple-26-surface.tsv
# Apple's 26.2 surface, for the gate in api-invented.lua: the interfaces of the modules Eidolon declares
# against, and of every module those reach through their `@_exported import` lines, which the walker
# follows itself. The entry list is where the walk starts, not what it reads: a module SwiftUI
# re-exports and the list does not name is walked anyway.
#
# The output is a data file. api-invented.lua is an error without it — a gate that quietly swapped its
# own oracle would be a gate nobody could trust — and this script is how it is written.
set -e
cd "$(dirname "$0")"
SDK26=${1:-${APPLE_26_SDK:-$HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk}}
ENTRY=${APPLE_26_MODULES:-"Swift SwiftUI SwiftUICore Foundation CoreFoundation Combine Observation CoreGraphics UIKit"}
paths=()
for m in $ENTRY; do
  d=$(find "$SDK26" -name "$m.swiftmodule" -type d 2>/dev/null | head -1)
  [ -n "$d" ] && for i in "$d"/*.swiftinterface; do [ -f "$i" ] && paths+=("$i"); done
done
if [ ! -d tools/surftool/swift-syntax ]; then
  git clone --depth 1 -b swift-DEVELOPMENT-SNAPSHOT-2026-09-21-a \
    https://github.com/swiftlang/swift-syntax tools/surftool/swift-syntax
fi
(cd tools/surftool && swift build -c release >/dev/null)
"tools/surftool/.build/release/surftool" "$SDK26" "${paths[@]}"
