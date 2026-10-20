#!/bin/sh
# braille-differential.sh - the braille translation against the host's own AXBrailleTranslator.
#
# The system builds an AXBrailleTable and an AXBrailleTranslator out of a provider's dot patterns,
# and this port builds the same two out of the published Unified English Braille grade 1 tables
# (RevenantBraille.m). The check is: give both the same text, and the cells must be the same cells.
#
# It runs on the host because the host has the framework - macOS 26 and later carry
# AXBrailleTranslator, and its Accessibility.framework is in the macOS SDK - and the two
# implementations are compiled into one binary, ours under the name the system does not use, so
# neither can answer for the other. Only the three braille classes are compiled: the request and
# the feature-override session have names the host's Accessibility already has, and building them
# here would collide with it.
#
# Usage: sh tests/backports/accessibility/braille-differential.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
root=$(cd "$here/../../.." && pwd)
build=${BUILD:-$(runs_fresh revenant-accessibility)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
if [ ! -f "$sdk/System/Library/Frameworks/Accessibility.framework/Headers/AXBrailleTranslator.h" ]; then
    echo "this host's SDK has no AXBrailleTranslator, so the oracle is not here; the translation is" >&2
    echo "then unmeasured on this host and the port's own check is the call test" >&2
    exit 2
fi
# Two programs, because one binary cannot hold both: the system's three braille classes and
# the port's have the same names by construction, and renaming either renames the system's
# declaration too. Each prints "<direction>\t<text>\t<cells>\t<unmapped>" per case, and the two
# outputs are diffed.
host_build() {
    xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O0 -Wall \
        "$here/braille-differential.m" -framework Foundation -framework Accessibility \
        -o "$build/host"
}
port_build() {
    xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O0 -Wall \
        -DREVENANT_HALF_PORT=1 -DREVENANT_BRAILLE_ONLY=1 \
        -DAXBrailleTable=RevenantPortBrailleTable \
        -DAXBrailleTranslationResult=RevenantPortBrailleTranslationResult \
        -DAXBrailleTranslator=RevenantPortBrailleTranslator \
        -I"$root/packages/frameworks/apple-backports/Accessibility" \
        -I"$root/packages/frameworks/apple-backports/Intents" \
        "$here/braille-differential.m" \
        "$root/packages/frameworks/apple-backports/Accessibility/RevenantBraille.m" \
        "$root/packages/frameworks/apple-backports/Foundation/RevenantCoding.m" \
        -I"$root/packages/frameworks/apple-backports/Intents" \
        -framework Foundation -framework CoreLocation -o "$build/port" 2>>"$build/build.log" || return 1
}
for half in host port; do
    if ! $half"_build"; then
        echo "the $half half did not build; $build/build.log says why" >&2
        tail -20 "$build/build.log" >&2
        exit 1
    fi
    "$build/$half" > "$build/$half.tsv"
done
echo "=== the system's cells and the port's, per case"
if diff -u "$build/host.tsv" "$build/port.tsv" > "$build/diff.txt"; then
    echo "identical: every case translates to the same cells in both"
    cat "$build/port.tsv"
else
    cat "$build/diff.txt"
fi
