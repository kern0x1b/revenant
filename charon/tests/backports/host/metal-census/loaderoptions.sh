#!/bin/sh
# loaderoptions.sh - the value of every MetalKit texture-loader option key, against Apple's own
# framework.
#
#     sh tests/backports/host/metal-census/loaderoptions.sh
#
# It exists because a key's value IS its contract: an application passes the NSString it read out of
# the header, so the port's spelling and Apple's have to be the same object or the option is silently
# ignored. Every sibling key already in the tree spells itself, and this harness is what says that is
# Apple's own value rather than a habit - it reads all eight out of Apple's framework and fails if
# any of them reads nil or reads as something other than its own name.
#
# MTKTextureLoaderOptionLoadAsArray is the one the port defines itself (the 16.4 SDK this package
# builds against does not declare it), so the port's copy is compiled under another name and the two
# are compared. NO DEVICE IS CREATED: these are strings.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/loaderoptions}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work"

S="$root/packages/a/apple-backports"
sdk=$(xcrun --show-sdk-path --sdk macosx)
# The macabi slice, not a macOS one: MetalKit's headers are iOSSupport headers here, and a macOS
# target brings AppKit's in beside them (measured: NSParagraphStyle.h redeclares a Foundation
# constant with a different constness and the build stops). run.sh builds the MetalKit case the same
# way and for the same reason. iOS 17.0, not 15.0, because MTKTextureLoaderOptionLoadAsArray is
# NS_AVAILABLE(14_0, 17_0) and the case reads it; at a 15.0 target it is an unguarded-availability
# warning, and a warning is not silenced with -Wno to make a number look better.
target="-target arm64-apple-ios17.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
common="$target -fobjc-arc"
frameworks="-framework Foundation -framework UIKit -framework CoreGraphics -framework Metal -framework MetalKit"

renames="-DMTKTextureLoaderOptionLoadAsArray=charonHost_MTKTextureLoaderOptionLoadAsArray"

# ALWAYS REBUILDS, and removes the binary first: a link that fails must not leave the previous run's
# binary behind to be read as this run's answer. That is the same defect descriptors16.sh guards.
build() {   # $1 output name, $2 port source
    rm -f "$work/$1" "$work/$1-port.o"
    # shellcheck disable=SC2086
    xcrun clang $common $renames -c "$2" -o "$work/$1-port.o" > "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the port, renamed) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common -c "$here/loaderoptions.m" -o "$work/$1-case.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the case) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common $frameworks -o "$work/$1" \
        "$work/$1-case.o" "$work/$1-port.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 does not link" >&2
        sed -n '/Undefined symbols/,$p' "$work/$1.log" | sed -n '2,5p' | sed 's/^/    /' >&2
        exit 1
    }
}

echo "the port's key, against Apple's own framework:"
build real "$S/MetalKit/MTKTextureLoaderOptionLoadAsArray17.m"

# THE PORT'S OBJECT MUST CARRY ITS SYMBOL UNDER THE RENAMED NAME, or the case is reading Apple's
# framework for the port's answer and would agree with itself.
if ! nm -g "$work/real" 2>/dev/null | grep -q "_charonHost_MTKTextureLoaderOptionLoadAsArray"; then
    echo "FAIL: the binary does not define _charonHost_MTKTextureLoaderOptionLoadAsArray" >&2
    echo "  the case would then be reading Apple's own framework and calling it the port's" >&2
    exit 1
fi
echo "  the port's key is DEFINED in the binary: _charonHost_MTKTextureLoaderOptionLoadAsArray"
timeout 120 "$work/real" || { echo "FAIL: the option-key differential failed" >&2; exit 1; }

# THE MUTATION the case has to notice: a key whose value is not its own name. If the case could not
# see this, it would agree with any value and its green would be worth nothing.
echo "the mutation: the port's key with a value that is not its own name"
sed 's|@"MTKTextureLoaderOptionLoadAsArray"|@"MTKTextureLoaderOptionLoadAsArraysCharonMutant"|' \
    "$S/MetalKit/MTKTextureLoaderOptionLoadAsArray17.m" > "$work/mutant.m"
build mutant "$work/mutant.m"
if timeout 120 "$work/mutant" > "$work/mutant.out" 2>&1; then
    echo "FAIL  the mutation is NOT red - this key is measured by nothing" >&2
    exit 1
fi
line=$(grep -m1 'FAIL' "$work/mutant.out" | sed 's/^ *FAIL /  /')
if [ -z "$line" ]; then
    echo "FAIL  the mutation produced no assertion line - see $work/mutant.out" >&2
    exit 1
fi
echo "  red  $line"

echo "loaderoptions: the differential is green and the mutation is red"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"