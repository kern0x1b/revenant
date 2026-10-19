#!/bin/sh
# The PORT's CIFormat pixel-format codes against the HOST's own, and a mutant per code.
#
# The port's objects are compiled and LINKED into the reader, so the codes compared against Apple's are the
# port's own and not numbers this script already had.  Each mutant changes one code and must be seen to
# change the comparison: a check that cannot go red proves nothing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/Graphics
build=${BUILD:-$root/.agent-work/runs/ciimageformats}
mkdir -p "$build"

objects="$port/CIConstants142.m $port/CIConstants170.m"
n=$(ls $objects | wc -l | tr -d ' ')
[ "$n" -eq 2 ] || { echo "FAIL  expected 2 band objects, found $n"; exit 1; }
# A band object on disk that defines a CIFormat and that this list does not name is invisible to every
# check below, which is how a comparison shrinks quietly.  Only objects that define a CIFormat are in
# scope: the other CIConstants objects hold NSString names, which tests/backports/host/ciimage's
# constvalues.m covers.  Asserted, not assumed.
miss=""
for f in "$port"/CIConstants*.m; do
    grep -q '^const CIFormat ' "$f" || continue
    case " $objects " in
        *" $f "*) ;;
        *) miss="$miss  $f" ;;
    esac
done
[ -z "$miss" ] || { echo "FAIL  a band object is on disk and NOT compared:"; echo "$miss"; exit 1; }
echo "  COVERAGE: every CIConstants object on disk that defines a CIFormat is compared ($n of them)"

# THE HOST S OWN: the reader with no port object linked, so every name resolves to Apple's dylib.
xcrun clang -w -DHOST_ONLY "$here/reader.c" -framework CoreGraphics -framework CoreImage -o "$build/host" 2>"$build/host.log" || {
    echo "BUILD  host reader"; head -3 "$build/host.log" | sed 's/^/    /'; exit 1; }
"$build/host" > "$build/host.txt" || { echo "FAIL  the host reader failed"; exit 1; }

# THE PORT S OWN: the same reader with the band objects compiled and linked into it.
objs=""
for f in $objects; do
    o="$build/$(basename "$f" .m).o"
    xcrun clang -w -I"$port" -c "$f" -o "$o" 2>"$build/port.log" || {
        echo "BUILD  $f"; head -3 "$build/port.log" | sed 's/^/    /'; exit 1; }
    objs="$objs $o"
done
xcrun clang -w "$here/reader.c" $objs -framework CoreGraphics -framework CoreImage -o "$build/port" 2>"$build/link.log" || {
    echo "BUILD  port reader"; head -3 "$build/link.log" | sed 's/^/    /'; exit 1; }
"$build/port" > "$build/port.txt" || { echo "FAIL  the port reader failed"; exit 1; }

count=$(wc -l < "$build/host.txt" | tr -d ' ')
[ "$count" -eq 4 ] || { echo "FAIL  the host reader printed $count codes, not 4"; exit 1; }
agree=0; differ=0
: > "$build/differs.txt"
while read -r name code <&3; do
    p=$(awk -v n="$name" '$1 == n { print $2 }' "$build/port.txt")
    h=$(awk -v n="$name" '$1 == n { print $2 }' "$build/host.txt")
    [ -n "$p" ] || { echo "FAIL  the port reader printed nothing for $name"; exit 1; }
    if [ "$p" = "$h" ]; then agree=$((agree+1)); else differ=$((differ+1)); echo "$name" >> "$build/differs.txt"; fi
done 3< "$build/host.txt"
echo "  GREEN (port vs host): $agree agree, $differ differ"
[ "$differ" -eq 0 ] || { echo "FAIL  the port disagrees with Apple on $(head -1 "$build/differs.txt")"; exit 1; }

# THE CONTROL on the reader itself: a name no object defines must not print as if it did.
cat > "$build/control.c" <<'EOF'
#include <stdio.h>
extern const unsigned kCIFormatNoSuchCodeForTheControl;
int main(void) { printf("%lu\n", (unsigned long)kCIFormatNoSuchCodeForTheControl); return 0; }
EOF
if xcrun clang -w "$build/control.c" -o "$build/control" >/dev/null 2>&1; then
    echo "FAIL  a reader naming a code no object defines linked, so it could print a number it has not got"; exit 1
fi
echo "  CONTROL: a name no object defines does not link, so the reader cannot print a code it has not got"

# THE MUTANTS: one per code, each compiled and linked, and each must be noticed.  Two fields, as above:
# the list holds "name code", and a one-field read would take the whole line as the name and match nothing.
i=0; ran=0; red=0
while read -r name code <&3; do
    i=$((i+1))
    mkdir -p "$build/m$i"
    mutated=""; markers=0
    for f in $objects; do
        b=$(basename "$f" .m)
        # every object of the slice is copied and only the one holding this code is changed, so a mutant
        # still LINKS against the other bands' objects - the defect that made an earlier mutation produce a
        # copy identical to the original
        sed -E "s/^const CIFormat $name = [0-9]+;/const CIFormat $name = 1;/" "$f" > "$build/m$i-$b.m"
        hit=0
        hit=$(grep -c "^const CIFormat $name = 1;$" "$build/m$i-$b.m") || hit=0
        # arithmetic expansion, not expr: expr exits 1 when the result is 0, and with set -e that killed
        # the run on the first mutant, silently, because a marker count of zero is exactly what we check.
        markers=$((markers + hit))
        xcrun clang -w -I"$port" -c "$build/m$i-$b.m" -o "$build/m$i/$b.o" 2>"$build/m$i/$b.log" || {
            echo "BUILD  mutant $i did not compile $b"; head -3 "$build/m$i/$b.log" | sed 's/^/    /'; exit 1; }
        mutated="$mutated $build/m$i/$b.o"
    done
    [ "$markers" -eq 1 ] || { echo "FAIL  mutant $i: the copy carries $markers mutant markers, not 1"; exit 1; }
    xcrun clang -w "$here/reader.c" $mutated -framework CoreGraphics -framework CoreImage -o "$build/m$i/pr" 2>"$build/m$i/link.log" || {
        echo "BUILD  mutant $i did not link"; head -3 "$build/m$i/link.log" | sed 's/^/    /'; exit 1; }
    ran=$((ran+1))
    if [ "$("$build/m$i/pr" | awk -v n="$name" '$1 == n { print $2 }')" = "$(awk -v n="$name" '$1 == n { print $2 }' "$build/host.txt")" ]; then
        echo "  NOT NOTICED  mutant $i changes $name and the comparison did not see it"; exit 1
    fi
    red=$((red+1))
done 3< "$build/host.txt"
echo "ciimageformats: $count codes, $ran mutants run, $red RED"
[ "$ran" -eq "$count" ] && [ "$red" -eq "$count" ] || { echo "  incomplete"; exit 1; }
exit 0