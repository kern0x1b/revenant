#!/bin/sh
# The port's UIFocusUpdateContext, UICollectionViewFocusUpdateContext and UITableViewFocusUpdateContext against Mac
# Catalyst's own classes, one source for both sides.
#
# matrix.m is built twice: plain, against the host's UIKit, and with the port's three classes compiled beside it under
# CharonHost names (the renames of uikit2/renames.sh), so both live in one process. Each build prints one line per
# measurement, and the two outputs must be equal line for line.
#
# The planted control: the port's init asserts on a non-nil focus system, in a scratch copy of UIFocusUpdateContext.m.
# The comparison must then go red, or it cannot tell a port that raises wrongly.
#
#   sh tests/backports/host/uikit-focuscontext/run.sh
#
# Not run through heavy.sh: it compiles four files and runs two small binaries.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/a/apple-backports/UIKit
build=${BUILD:-$tree/.agent-work/runs/focuscontext/run}
sdk=$(xcrun --sdk macosx --show-sdk-path)
ios=$sdk/System/iOSSupport/System/Library/Frameworks
. "$here/../uikit2/renames.sh"
rm -rf "$build"
mkdir -p "$build/host" "$build/port" "$build/plant"

FLAGS="-fobjc-arc -w -target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $ios"
LINK="-F $ios -framework Foundation -framework UIKit"
CLASSES="UIFocusUpdateContext UICollectionViewFocusUpdateContext UITableViewFocusUpdateContext"

# the host: matrix.m as it is, against the system's own classes
xcrun clang $FLAGS $LINK "$here/matrix.m" -o "$build/host/matrix" 2> "$build/host/build.log" || {
    echo "the host build did not link:"; sed 's/^/    /' "$build/host/build.log" | head -8; exit 1; }

# the port: its three classes, compiled plain to learn the names they define, then renamed beside the system's
for file in $CLASSES; do
    xcrun clang $FLAGS -c "$port/$file.m" -o "$build/port/$file.plain.o" 2> "$build/port/$file.plain.log" || {
        echo "the port's $file.m did not compile:"; sed 's/^/    /' "$build/port/$file.plain.log" | head -8; exit 1; }
done
names=$(renames "$build/port/UIFocusUpdateContext.plain.o $build/port/UICollectionViewFocusUpdateContext.plain.o $build/port/UITableViewFocusUpdateContext.plain.o")

# builds matrix.m and the port's objects with $1 as the port's UIFocusUpdateContext.m, runs it into $2
renamed() {
    src=$1
    out=$2
    xcrun clang $FLAGS $names -c "$src" -o "$out.base.o"
    xcrun clang $FLAGS $names -c "$port/UICollectionViewFocusUpdateContext.m" -o "$out.collection.o"
    xcrun clang $FLAGS $names -c "$port/UITableViewFocusUpdateContext.m" -o "$out.table.o"
    xcrun clang $FLAGS $names -c "$here/matrix.m" -o "$out.matrix.o"
    xcrun clang $FLAGS $LINK "$out.base.o" "$out.collection.o" "$out.table.o" "$out.matrix.o" -o "$out.bin" 2> "$out.link.log" || {
        echo "the renamed build did not link:"; sed 's/^/    /' "$out.link.log" | head -8; return 1; }
    "$out.bin" > "$out.txt"
}

renamed "$port/UIFocusUpdateContext.m" "$build/port/run" || exit 1
"$build/host/matrix" > "$build/host/out.txt"
echo "== host lines: $(grep -c . "$build/host/out.txt"), port lines: $(grep -c . "$build/port/run.txt")"

echo "== the port against the host, line by line"
if diff "$build/host/out.txt" "$build/port/run.txt" > "$build/diff.txt"; then
    echo "SAME: the port's answers equal the host's on every line"
else
    echo "DIFFERENT: $(grep -c '^[<>]' "$build/diff.txt") lines differ; the first ones:"
    head -12 "$build/diff.txt" | sed 's/^/    /'
    exit 1
fi

echo
echo "== the planted control: the init's focus system made non-nil in a scratch copy of the port's UIFocusUpdateContext.m"
sed 's/id focusSystem = nil;/id focusSystem = @"system";/' "$port/UIFocusUpdateContext.m" > "$build/plant/UIFocusUpdateContext.m"
cmp -s "$port/UIFocusUpdateContext.m" "$build/plant/UIFocusUpdateContext.m" && {
    echo "PLANT: the sed changed nothing, so the control proves nothing"; exit 1; }
renamed "$build/plant/UIFocusUpdateContext.m" "$build/plant/run" || exit 1
if diff "$build/host/out.txt" "$build/plant/run.txt" > "$build/plant/diff.txt"; then
    echo "PLANT: the comparison passed a planted port, so it is not discriminating"; exit 1
fi
echo "PLANT: noticed, $(grep -c '^[<>]' "$build/plant/diff.txt") lines differ, the first:"
head -2 "$build/plant/diff.txt" | sed 's/^/    /'
echo
echo "uikit-focuscontext: the port's three focus update contexts answer as the host on every measured line; the planted control is red"
