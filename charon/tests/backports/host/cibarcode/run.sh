#!/bin/sh
# run.sh - the PORT's CIBarcodeDescriptor and its four subclasses against the HOST's own CoreImage, in two
# programs built from the same cases.m, with every name the port defines renamed in the port build.
#
# WHY THE RENAME, because the four ways out of this family's blocker were listed and this is the tree's own:
# the five classes carry the same names on the host and in the port, and on macOS EVERY process that uses
# Foundation has CoreImage loaded (DYLD_PRINT_LIBRARIES on a program that links Foundation alone prints
# CoreImage arriving through DataDetection and AppleNeuralEngine), so a port build is a duplicate class and
# the runtime answers a duplicate with whichever registered first. Measured: two builds of this harness
# printed identical answers for all 140338 combinations because only one was running the code under test.
# Renaming the port's five classes in THIS BUILD ONLY - the same -include rename.h the MLCompute and
# metal-census harnesses use, with the names read out of the port's own sources rather than listed here -
# makes them two names in one process, so nothing a caller sees changes, no load order decides anything, and
# the dladdr binding record can say which of the two answered.
#
# THE HOST DOES NOT SURVIVE EVERY GROUP, and that is the host's crash, not a difference: qr, aztec,
# pdf417-rows, pdf417-columns, matrix, payload and copy each print their first record and then exit 133,
# and the host's own CIPDF417CodeDescriptor dies in its own dealloc. Those groups are compared on the records
# the host printed before it died, and the count it never reached is printed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/Graphics
build=${BUILD:-$root/.agent-work/runs/cibarcode}
rm -rf "$build"
mkdir -p "$build"

CASE_GROUPS="sweep-qr sweep-aztec sweep-pdf417 sweep-matrix qr aztec pdf417-rows pdf417-columns matrix payload payload-no-pdf417 copy copy-no-pdf417"
common="-fobjc-arc -w -I$here"

# Every name the port's own sources define, read out of the sources so a class the port adds cannot be missed
python3 - "$port/CIBarcodeDescriptor11.m" "$build/rename.h" <<'PY'
import re, sys
source, out = sys.argv[1], sys.argv[2]
names = set(re.findall(r"^@implementation\s+(CI\w+)", open(source).read(), re.M))
assert names, "no class found in the port's source: the rename would leave the port's classes colliding"
with open(out, "w") as handle:
    for name in sorted(names):
        handle.write("#define %s Charon%s\n" % (name, name))
print("  RENAMED: %d names the port defines, in this build only" % len(names))
PY

# THE HOST'S BUILD: CoreImage answers every case.
if ! xcrun clang $common -DCHARON_HOST "$here/cases.m" -framework Foundation -framework CoreImage -o "$build/host" 2>"$build/host.log"; then
  echo "BUILD  host"
  head -5 "$build/host.log" | sed 's/^/    /'
  exit 1
fi
# THE PORT'S BUILD: the same cases.m with the port's object, and every name of it renamed, and CoreImage
# linked too - which is safe now precisely because the names differ.
if ! xcrun clang $common -DCHARON_PORT -include "$build/rename.h" -I"$port" "$here/cases.m" \
    "$port/CIBarcodeDescriptor11.m" -framework Foundation -framework CoreImage -o "$build/port" 2>"$build/port.log"; then
  echo "BUILD  port"
  head -5 "$build/port.log" | sed 's/^/    /'
  exit 1
fi

compared=0
unreachable=0
trapped=0
for g in $CASE_GROUPS; do
  "$build/host" "$g" 2>/dev/null | sed "s/^/$g\t/" > "$build/host-$g.tsv" || true
  if "$build/host" "$g" >/dev/null 2>&1; then host_status=0; else host_status=$?; fi
  "$build/port" "$g" 2>/dev/null | grep -v '^PORTONLY' | sed "s/^/$g\t/" > "$build/port-$g.tsv" || true
  host_records=$(grep -c . "$build/host-$g.tsv" || true)
  port_records=$(grep -c . "$build/port-$g.tsv" || true)
  if [ "$host_records" -gt 0 ]; then
    if ! diff -q "$build/host-$g.tsv" "$build/port-$g.tsv" > /dev/null; then
      echo "FAIL  the port answers differently from the host in group $g:"
      diff "$build/host-$g.tsv" "$build/port-$g.tsv" | head -10 | sed 's/^/    /'
      exit 1
    fi
    compared=$((compared + host_records))
  fi
  [ "$host_status" -eq 0 ] || trapped=$((trapped + 1))
  if [ "$port_records" -gt "$host_records" ]; then
    unreachable=$((unreachable + port_records - host_records))
  fi
  printf '  %-18s host %s record(s) exit %s, port %s record(s)\n' "$g" "$host_records" "$host_status" "$port_records"
done
echo "  COMPARED: $compared records against the host's own answers"
echo "  HOST CRASH: $trapped of the $(echo $CASE_GROUPS | wc -w | tr -d ' ') groups end the host with a trap, and $unreachable records are ones the host never reached"

# THE BINDING: the port's renamed class must be the one that answered, and Apple's must be the host's.
binding=$("$build/port" sweep-qr 2>/dev/null | sed -n 's/^PORTONLY binding\t//p')
[ "$binding" = "port" ] || { echo "FAIL  the port build answered with Apple's class (binding=$binding)"; exit 1; }
apples=$("$build/host" sweep-qr 2>/dev/null | grep -c '^PORTONLY' || true)
[ "$apples" -eq 0 ] || { echo "FAIL  the host build printed $apples port-only records"; exit 1; }
echo "  BINDING: the port's renamed class answered every case above, and the host build has no port object in it"

# THE MUTATIONS: the port's own source changed, and the comparison has to notice. Three plants for three
# kinds of answer: a boundary, the payload, and a number that travels.
plant=$build/plant
mkdir -p "$plant"
cp "$here/cases.m" "$plant/cases.m"
cp "$port/CIBarcodeDescriptor11.m" "$plant/CIBarcodeDescriptor11.m"

notices() {  # does the mutated port differ from the host where the host is reachable?
  for g in $CASE_GROUPS; do
    [ -s "$build/host-$g.tsv" ] || continue
    "$build/plantbin" "$g" 2>/dev/null | grep -v '^PORTONLY' | sed "s/^/$g\t/" > "$build/plant-$g.tsv" || true
    diff -q "$build/host-$g.tsv" "$build/plant-$g.tsv" > /dev/null 2>&1 || return 0
  done
  return 1
}
plant() {  # $1 = label; $2 = the pattern that must have changed
  if ! xcrun clang $common -DCHARON_PORT -include "$build/rename.h" -I"$port" "$plant/cases.m" \
      "$plant/CIBarcodeDescriptor11.m" -framework Foundation -framework CoreImage -o "$build/plantbin" 2>"$build/plant.log"; then
    echo "BUILD  the mutated port ($1)"
    head -3 "$build/plant.log" | sed 's/^/    /'
    exit 1
  fi
  notices || { echo "  NOT NOTICED  $1 and no record moved"; exit 1; }
  echo "  MUTATION: $1 moves a record, so that check can go red"
}

sed -i '' 's/if (symbolVersion < 1 || symbolVersion > 40)/if (symbolVersion < 0 || symbolVersion > 40)/' "$plant/CIBarcodeDescriptor11.m"
hit=$(grep -c 'symbolVersion < 0' "$plant/CIBarcodeDescriptor11.m" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the first mutation changed nothing (the pattern is stale)"; exit 1; }
plant "a symbol version floor of 0"

cp "$port/CIBarcodeDescriptor11.m" "$plant/CIBarcodeDescriptor11.m"
sed -i '' 's/_errorCorrectedPayload = errorCorrectedPayload;/_errorCorrectedPayload = [errorCorrectedPayload copy];/' "$plant/CIBarcodeDescriptor11.m"
hit=$(grep -c '_errorCorrectedPayload = \[errorCorrectedPayload copy\];' "$plant/CIBarcodeDescriptor11.m" || true)
[ "$hit" -eq 4 ] || { echo "FAIL  the second mutation changed nothing (the pattern is stale)"; exit 1; }
plant "copying a payload the caller keeps mutating"

cp "$port/CIBarcodeDescriptor11.m" "$plant/CIBarcodeDescriptor11.m"
sed -i '' 's/if (rowCount < 3 || rowCount > 90 || columnCount < 1 || columnCount > 30)/if (rowCount < 2 || rowCount > 90 || columnCount < 1 || columnCount > 30)/' "$plant/CIBarcodeDescriptor11.m"
hit=$(grep -c 'rowCount < 2' "$plant/CIBarcodeDescriptor11.m" || true)
[ "$hit" -eq 1 ] || { echo "FAIL  the third mutation changed nothing (the pattern is stale)"; exit 1; }
plant "a PDF417 row floor of 2"

echo "cibarcode: $compared records compared against the host's own answers, mutation RED"
exit 0
