#!/bin/sh
# run.sh - which of the remaining Intents members the host RUNTIME carries (probe.m), measured on the Catalyst host
# and on macOS, and compared with expected.txt, the golden answer for the Catalyst host.
#
# A member the SDK header does not declare is still asked for by name, so this answers the question the headers cannot:
# whether the release carries it. The macOS run must agree with the Catalyst run; if it does not, the difference is
# printed and the script stops.
#
# The plant: one golden line changed must make the diff non-empty, or the comparison cannot fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${REMAINING_BUILD:-$(runs_fresh revenant-intents-remaining)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
xcrun clang -fno-objc-arc -w $target -framework Foundation -framework Intents "$here/probe.m" -o "$build/catalyst"
"$build/catalyst" > "$build/catalyst.txt"
xcrun clang -fno-objc-arc -w -framework Foundation -framework Intents "$here/probe.m" -o "$build/macos"
"$build/macos" > "$build/macos.txt"
if ! diff -u "$build/catalyst.txt" "$build/macos.txt"; then
    echo "FAIL: the macOS runtime answers differently from the Catalyst runtime (lines above)"
    exit 1
fi
if ! diff -u "$here/expected.txt" "$build/catalyst.txt"; then
    echo "FAIL: the Catalyst runtime answers differently from expected.txt (lines above)"
    exit 1
fi
echo "PASS: $(wc -l < "$build/catalyst.txt") lines, macOS and Catalyst alike, the golden answer"
sed '1s/YES/NO/' "$here/expected.txt" > "$build/plant.txt"
if diff -q "$build/catalyst.txt" "$build/plant.txt" >/dev/null; then
    echo "FAIL: the plant agrees with the Catalyst runtime, so the comparison cannot fail"
    exit 1
fi
echo "PLANT: the changed golden differs from the runtime, as it must"
