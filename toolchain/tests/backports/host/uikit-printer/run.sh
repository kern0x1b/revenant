#!/bin/sh
# The port's UIPrinter, UIPrintServiceExtension, UIPrinterDestination and UIPrinterPickerController against Mac Catalyst's
# own classes, one source
# for both sides.
#
# matrix.m is built twice: plain, against the host's UIKit, and with the port's classes compiled beside it under a
# RevenantHost name (the renames of uikit2/renames.sh), so both live in one process. Each build prints one line per
# measurement, and the two outputs must be equal line for line, except the lines that start with `open:`: those name a
# difference the port does not match on purpose (the host's own archive does not decode, facts/UIKit/UIPrinterDestination.md).
# They are printed from both sides instead.
#
# The planted control: the port's failed-connection answer is forced to YES in a scratch copy of UIPrinter.m, so every
# unreachable URL answers YES. It does not depend on the Mac's CUPS being up. The comparison must then go red, or it
# cannot tell a port that answers wrongly.
#
#   sh tests/backports/host/uikit-printer/run.sh
#
# Not run through heavy.sh: it compiles a few files and runs two small binaries; the contact cases wait at most 35 s each.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/a/apple-backports/UIKit
build=${BUILD:-$tree/.agent-work/runs/printer/run}
sdk=$(xcrun --sdk macosx --show-sdk-path)
ios=$sdk/System/iOSSupport/System/Library/Frameworks
. "$here/../uikit2/renames.sh"
rm -rf "$build"
mkdir -p "$build/host" "$build/port" "$build/plant"

FLAGS="-fobjc-arc -w -target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $ios"
LINK="-F $ios -framework Foundation -framework UIKit -framework CFNetwork"
ports="UIPrinter UIPrintServiceExtension UIPrinterDestination UIPrinterPickerController"

# the host: matrix.m as it is, against the system's own classes
xcrun clang $FLAGS $LINK "$here/matrix.m" -o "$build/host/matrix" 2> "$build/host/build.log" || {
    echo "the host build did not link:"; sed 's/^/    /' "$build/host/build.log" | head -8; exit 1; }

# the port: each class compiled plain to learn the names it defines, then renamed beside the system's
for p in $ports; do
    xcrun clang $FLAGS -c "$port/$p.m" -o "$build/port/$p.plain.o" 2> "$build/port/$p.plain.log" || {
        echo "the port's $p.m did not compile:"; sed 's/^/    /' "$build/port/$p.plain.log" | head -8; exit 1; }
done
names=$(for p in $ports; do renames "$build/port/$p.plain.o"; done | sort -u)

# builds matrix.m and the port's objects, from the sources given ($2 onward) in place of the port's own, and runs
# them into $1.txt
renamed() {
    out=$1
    shift
    list=""
    for src in "$@"; do
        obj="$out.$(basename "$src" .m).o"
        xcrun clang $FLAGS $names -c "$src" -o "$obj" || return 1
        list="$list $obj"
    done
    xcrun clang $FLAGS $names -c "$here/matrix.m" -o "$out.matrix.o"
    xcrun clang $FLAGS $LINK $list "$out.matrix.o" -o "$out.bin" 2> "$out.link.log" || {
        echo "the renamed build did not link:"; sed 's/^/    /' "$out.link.log" | head -8; return 1; }
    "$out.bin" > "$out.txt"
}

renamed "$build/port/run" "$port/UIPrinter.m" "$port/UIPrintServiceExtension.m" "$port/UIPrinterDestination.m" "$port/UIPrinterPickerController.m" || exit 1
"$build/host/matrix" > "$build/host/out.txt"
grep -v '^open:' "$build/host/out.txt" > "$build/host/same.txt"
grep -v '^open:' "$build/port/run.txt" > "$build/port/same.txt"
echo "== host lines: $(grep -c . "$build/host/same.txt"), port lines: $(grep -c . "$build/port/same.txt") (open: lines not counted)"

echo "== the port against the host, line by line"
if diff "$build/host/same.txt" "$build/port/same.txt" > "$build/diff.txt"; then
    echo "SAME: the port's answers equal the host's on every line"
else
    echo "DIFFERENT: $(grep -c '^[<>]' "$build/diff.txt") lines differ; the first ones:"
    head -12 "$build/diff.txt" | sed 's/^/    /'
    exit 1
fi

echo
echo "== open differences, not compared: the host's own archive does not decode"
echo "host:"; grep '^open:' "$build/host/out.txt" | sed 's/^/    /'
echo "port:"; grep '^open:' "$build/port/run.txt" | sed 's/^/    /'

echo
echo "== the planted control: a failed connection forced to YES in a scratch copy of the port's UIPrinter.m"
sed '/int fd = revenant_connect(host, port, deadline);/{n;n;s/return NO;/return YES;/;}' "$port/UIPrinter.m" > "$build/plant/UIPrinter.m"
cmp -s "$port/UIPrinter.m" "$build/plant/UIPrinter.m" && {
    echo "PLANT: the sed changed nothing, so the control proves nothing"; exit 1; }
renamed "$build/plant/run" "$build/plant/UIPrinter.m" "$port/UIPrintServiceExtension.m" "$port/UIPrinterDestination.m" "$port/UIPrinterPickerController.m" || exit 1
grep -v '^open:' "$build/plant/run.txt" > "$build/plant/same.txt"
if diff "$build/host/same.txt" "$build/plant/same.txt" > "$build/plant/diff.txt"; then
    echo "PLANT: the comparison passed a planted port, so it is not discriminating"; exit 1
fi
echo "PLANT: noticed, $(grep -c '^[<>]' "$build/plant/diff.txt") lines differ, the first:"
head -2 "$build/plant/diff.txt" | sed 's/^/    /'
echo
echo "uikit-printer: the port's classes answer as the host on every compared line; the planted control is red"
