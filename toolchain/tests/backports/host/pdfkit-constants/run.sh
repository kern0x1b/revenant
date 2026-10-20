#!/bin/sh
# The port's PDFKit constants against the host's own, name by name.
#
# The port's side is NOT linked into the differential: its values are the string literals in the
# committed constants object, which this runner reads out of that file.  Nothing has to agree with the
# port's headers, so the two sides cannot collide over them, and the host's answer is proved with
# dladdr - the only image proof there is, because the host framework has no file on disk and lives in
# the dyld shared cache.
#
#   sh tests/backports/host/pdfkit-constants/run.sh
#
# Prints COMPARED <n> MISMATCHES <m> and exits non-zero on any mismatch, on any name the host does not
# answer, or on any name whose host image is not PDFKit.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
tree=$(cd "$here/../../../.." && pwd)
port=$tree/packages/frameworks/apple-backports/PDFKit
build=${BUILD:-$(runs_folder pdfkit-constants)}
mkdir -p "$build"

# the port's own map: name -> literal, out of the committed objects
runs_xmake l "$here/port-map.lua" "$port" "$build/port-map.tsv"

names="$build/names.txt"
cut -f1 "$build/port-map.tsv" > "$names"
n=$(wc -l < "$names" | tr -d ' ')
if [ -s "$build/port-map.tsv.numeric" ]; then
    cut -f1 "$build/port-map.tsv.numeric" > "$build/numeric-names.txt"
    sed 's/^/    /' "$build/port-map.tsv.numeric"
fi
[ "$n" -gt 0 ] || { echo "no names read out of the band's objects"; exit 1; }

xcrun clang -fobjc-arc -w "$here/read-host.m" -framework Foundation -o "$build/read-host" \
    2> "$build/build.log" || {
    echo "BUILD the host reader did not compile:"; head -6 "$build/build.log" | sed 's/^/    /'; exit 1; }
"$build/read-host" "$names" > "$build/host-map.tsv"

# the numeric names, compared as doubles: the same dladdr proof, the host's value read through dlsym
xcrun clang -fobjc-arc -w "$here/read-host-numeric.m" -framework Foundation -o "$build/read-host-numeric" \
    2> "$build/build-numeric.log" || {
    echo "BUILD the numeric reader did not compile:"; head -6 "$build/build-numeric.log" | sed 's/^/    /'; exit 1; }
"$build/read-host-numeric" "$build/numeric-names.txt" > "$build/host-numeric.tsv"

runs_xmake l "$here/compare.lua" "$build/port-map.tsv" "$build/host-map.tsv" "$build/host-numeric.tsv"
