#!/bin/sh
# The GENERIC host-inventory differential, for any framework with a spec. It sits beside the per-framework
# harnesses rather than in place of them: FileProvider has its own differential.m/run.sh on main and that
# work is not replaced by this, only joined.
#
#   ./run.sh FRAMEWORK
#
# Three controls, each of which exists because the version without it reported a clean run over nothing:
#   1. a class prefix that matches nothing exits 3 and the run FAILS - an empty comparison is not green;
#   2. the host's class count is compared with the count the spec expects, so a host that answers less is
#      visible instead of merely smaller;
#   3. every `never_call` name is checked against the BUILT OBJECT, not the source tree: the port does not
#      keep .o files in its source tree, so a check that read $pkg/*.o was reading an empty set and passing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
spec=${1:?usage: run.sh FRAMEWORK}
json=$root/packages/a/apple-backports/spec/$spec/bands.json
[ -f "$json" ] || { echo "FAIL  no spec at $json"; exit 1; }
prefix=$(jq -r '.class_prefix // empty' "$json")
expect=$(jq -r '.expect_classes // empty' "$json")
package=$(jq -r '.package // empty' "$json")
pkg=$root/packages/a/apple-backports/$package
# the band objects of the spec are generated into .gen/<package> by tools/gen (gen --all, the package build's first step)
gen=$root/packages/a/apple-backports/.gen/$package
build=${BUILD:-$root/.agent-work/runs/inventory}
mkdir -p "$build"
[ -n "$prefix" ] || { echo "FAIL  the spec has no class_prefix, so the probe would match every class on the host"; exit 1; }
link=""
for fw in $(jq -r '.frameworks[]?' "$json"); do
  [ -n "$fw" ] || { echo "FAIL  the spec names no frameworks, so the host cannot be asked about them"; exit 1; }
  link="$link -framework $fw"
done
xcrun clang -w -fobjc-arc "$here/inventory.m" -framework Foundation $link -o "$build/inventory" 2>"$build/c.log" || {
  echo "BUILD  the inventory probe"; head -3 "$build/c.log" | sed 's/^/    /'; exit 1; }
"$build/inventory" "$prefix" "$spec" > "$build/host.txt" 2>&1 || {
  echo "FAIL  the host registers nothing under $prefix, so this comparison would be empty"; exit 1; }
got=$(sed -n 's/^TOTALS.*classes=\([0-9]*\).*/\1/p' "$build/host.txt")
gotp=$(sed -n 's/^TOTALS.*protocols=\([0-9]*\).*/\1/p' "$build/host.txt")
echo "  HOST: $prefix -> $got classes, $gotp protocols"
[ "$got" -gt 0 ] || { echo "FAIL  the host answered 0 classes"; exit 1; }
if [ -n "$expect" ]; then
  [ "$got" -eq "$expect" ] || { echo "FAIL  the spec expects $expect classes and the host answered $got"; exit 1; }
  echo "  COUNT: $got classes, as the spec expects"
fi
# the port's objects are BUILT here, so the never_call check reads symbols rather than an empty set
rm -rf "$build/obj"; mkdir -p "$build/obj"
n=0
for f in "$pkg"/${prefix#NS}*.m "$pkg"/[A-Z]*.m "$gen"/*.m; do
  [ -f "$f" ] || continue
  xcrun clang -fobjc-arc -w -I "$pkg" -c "$f" -o "$build/obj/$(basename "$f" .m).o" 2>"$build/o.log" || {
    echo "BUILD  $(basename "$f")"; head -3 "$build/o.log" | sed 's/^/    /'; exit 1; }
  n=$((n+1))
done
[ "$n" -gt 0 ] || { echo "FAIL  no object was built, so a never_call check would compare nothing"; exit 1; }
echo "  PORT: $n objects built and read"
set -- $(ls "$build"/obj/*.o 2>/dev/null)
[ "$#" -gt 0 ] || { echo "FAIL  no object to read"; exit 1; }
nm -a "$@" > "$build/nm.txt"
# a name is present when its line ends with " NAME" once trailing blanks are gone, as an exact symbol and not a longer one
missing=""
total=0
jq -r '.pieces[].never_call[]?' "$json" > "$build/never.txt"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  total=$((total + 1))
  awk -v s=" $name" '{ l = $0; sub(/[ \t]+$/, "", l); if (length(l) >= length(s) && substr(l, length(l) - length(s) + 1) == s) found = 1 }
    END { exit !found }' "$build/nm.txt" || missing="$missing, $name"
done < "$build/never.txt"
if [ -n "$missing" ]; then
  echo "FAIL  carried-for-callable but NOT in the built object: ${missing#, }"; exit 1
fi
echo "  CARRIED: $total never_call names present as an exact nm symbol in the built object"
echo "  NOT CHECKED: whether any harness calls them - see the comment above, that half is not implemented"
echo "inventory: $spec green"
