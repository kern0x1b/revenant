#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
export SWIFTUI_ROOT=${SWIFTUI_ROOT:-$(cd "$here/../../.." && pwd)}
. "$here/../../backports/common/runs.sh" "$here"
build=${SWIFTUI_BUILD:-$(runs_folder swiftui-consumer)}
mkdir -p "$build"
if ! mkdir "$build/run.lock" 2>/dev/null; then
    echo "consumer: another run of this test is in $build (its lock is $build/run.lock, from $(stat -f %Sm "$build/run.lock"))" >&2
    exit 1
fi
trap 'rmdir "$build/run.lock" 2>/dev/null || true' EXIT INT TERM
echo "consumer: one run at a time, this one holds $build/run.lock"
if [ ! -d "$build/project/.xmake" ]; then
    mkdir -p "$build"
    cp -R "$here" "$build/project"
    echo "consumer: configured a project in $build/project"
else
    echo "consumer: resuming the configured project in $build/project"
fi
for lock in "$build/project/xmake-addons.lock" "$build/project/.xmake"/*/*/project.lock; do
    [ -e "$lock" ] || continue
    kept="$build/stopped-run-locks/$(date +%Y%m%d-%H%M%S)-$(basename "$lock")"
    mkdir -p "$(dirname "$kept")"
    mv "$lock" "$kept"
    echo "consumer: the lock of a stopped run is kept aside, not waited on: $kept"
done
cd "$build/project"
xmake f -y -c < /dev/null > "$build/configure.log" 2>&1 || { tail -40 "$build/configure.log"; exit 1; }
xmake -y < /dev/null >"$build/build.log" 2>&1 || { tail -40 "$build/build.log"; exit 1; }

binary=$(find "$build/project/build" -name consumer -type f -perm -u+x 2>/dev/null | head -1)
[ -n "$binary" ] || { echo "consumer: the build produced no binary"; tail -40 "$build/build.log"; exit 1; }

store=${XMAKE_GLOBALDIR:-$HOME/.xmake}
library=$(find "$store/packages/frameworks/swiftui" -name libRevenantSwiftUI.a 2>/dev/null | head -1)
[ -n "$library" ] || { echo "consumer: revenant@swiftui installed no libRevenantSwiftUI.a under $store"; exit 1; }
installdir=$(dirname "$(dirname "$library")")
module=$installdir/lib/swift/iphoneos/SwiftUI.swiftmodule
[ -f "$module/armv7-apple-ios.swiftmodule" ] || { echo "consumer: no armv7 module in $module"; exit 1; }
[ -f "$module/SwiftUI.swiftinterface" ] || { echo "consumer: no interface in $module"; exit 1; }

if ! nm -gU "$binary" 2>/dev/null | grep -q '\$s7SwiftUI'; then
    echo "consumer: the binary carries nothing of the SwiftUI module"; exit 1
fi
grep -q "public struct VStack" "$module/SwiftUI.swiftinterface" || {
    echo "consumer: the interface names no VStack"; exit 1; }

echo "consumer: the resolution said"
sed -n '1,20p' "$build/configure.log"
echo "consumer: built against the module, linked the library, read the interface"
echo "  library:  $library"
echo "  module:   $module"
echo "  binary:   $binary"
