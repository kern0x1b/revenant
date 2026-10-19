#!/bin/sh
# run.sh — is this port's convolutional MPS the same arithmetic as the system's own?
#
# cnn-cases.m is compiled twice and run twice: once against the system's MPS, once against this port's
# classes with the MPS names mapped to Charon names and their selectors prefixed, so the port's
# implementations are reached under names of their own and cannot replace the system's. Every case
# prints the result the kernel wrote, as text, and the two runs are compared against a written-down
# float tolerance rather than bit for bit, because a convolution accumulates in a different order on a
# GPU than on a CPU. See TOLERANCE below.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mps=${MPS:-$here/../../../../packages/a/apple-backports/MetalPerformanceShaders}
build=${BUILD:-$here/../../../../.agent-work/runs/host/mpscnn}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness -Wno-objc-protocol-method-implementation"
xcrun clang -fobjc-arc $target $quiet "$here/cnn-cases.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/system"
"$build/system" > "$build/system.txt" 2> "$build/system.err" || true
echo "system: $(wc -l < "$build/system.txt") lines"

# The names this library carries, each under a name of its own. The list is every class the port
# *defines*, read out of its compiled objects and not the subset a case happens to reach: the host's
# MPS framework defines nearly all of them, so a class left unrenamed is two classes of one name in
# the port's process, and which one a superclass pointer or a message reaches is then decided by load
# order rather than by anything here. The same shape of defect ba5df243 found in NetworkExtension.
rm -rf "$build/plain"
mkdir -p "$build/plain"
for source in "$mps"/*.m; do
    xcrun clang -fobjc-arc -w $target -c "$source" -o "$build/plain/$(basename "$source" .m).o" 2>/dev/null
done
for object in "$build/plain"/*.o; do xcrun nm -g --defined-only "$object"; done \
    | grep -oE '_OBJC_CLASS_\$_[A-Za-z0-9_]+' | sed 's/_OBJC_CLASS_\$_//' | sort -u > "$build/port-defines.txt"
python3 - "$build/port-defines.txt" "$build/rename.h" <<'PY'
import sys
names = [line.strip() for line in open(sys.argv[1]) if line.strip()]
with open(sys.argv[2], 'w') as out:
    for name in names:
        out.write("#define %s Charon%s\n" % (name, name))
print("classes the port defines: %d" % len(names))
PY
echo "renamed: $(grep -c define "$build/rename.h") classes"

printf '#import <MetalPerformanceShaders/MetalPerformanceShaders.h>\n#import "CharonMPSCnn.h"\n#import <objc/runtime.h>\n#include <stdio.h>\n' > "$build/declarations.h"
objects=""
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$source" -o "$build/$name.plain.o"
    python3 "$here/../prefix_selectors.py" "$source" "$build/$name.m" ccharonHost_ \
        --declarations="$build/declarations.h" -fobjc-arc $target $quiet -I"$mps" -include "$build/rename.h" -- "$build/$name.plain.o"
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -include "$build/rename.h" \
        -include "$build/declarations.h" -c "$build/$name.m" -o "$build/$name.o"
    objects="$objects $build/$name.o"
done
echo "compiled: $(echo "$objects" | wc -w) objects"

# -DCHARON_PORT_BUILD: this is the port's own build, and the guard below is a statement about it. The
# system build has no rename header and no port classes, and there is nothing for the guard to ask of it.
xcrun clang -fobjc-arc $target $quiet -DCHARON_PORT_BUILD=1 -include "$build/rename.h" "$here/cnn-cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/port"
"$build/port" > "$build/port.txt" 2> "$build/port.err" || true

# TOLERANCE, written down before the numbers were compared: a convolution and a normalisation
# accumulate in a different order on the GPU than on the CPU, so the two are not expected to agree to
# the bit. A case passes when every element differs by no more than TOLERANCE, absolute or relative,
# whichever is larger, with TOLERANCE = 1e-4 for a single precision result. Pooling, which sums at
# most nine values with no division of magnitudes, is compared exactly: its cases are named
# "exact" below and must agree bit for bit.
TOLERANCE=1e-4
python3 - "$build/system.txt" "$build/port.txt" "$TOLERANCE" <<'PY'
import sys
system_path, port_path, tolerance = sys.argv[1], sys.argv[2], float(sys.argv[3])
def read(path):
    """The transcript's cases, and the cases that were not compared.

    A line that names a class the port does not have is a case the harness refused to compare, and it
    is a result: the run said so instead of printing an answer. It is collected here and fails the
    comparison below, because a case that did not run is not a case that passed.
    """
    cases, name, values = {}, None, []
    skipped = []
    for line in open(path):
        if line.startswith("image "):
            continue
        if " NOT COMPARED:" in line:
            if name: cases[name] = values
            name, values = None, []
            parts = line.split()
            skipped.append((parts[1] if len(parts) > 1 else "?", line.strip().split("NOT COMPARED:", 1)[1].strip()))
            continue
        if line.startswith("compared: "):
            if name: cases[name] = values
            name, values = None, []
            continue
        parts = line.split()
        if len(parts) == 2 and parts[1].isdigit():
            if name: cases[name] = values
            name, values = parts[0], []
        elif parts and name is not None:
            values.extend(float(v) for v in parts)
    if name: cases[name] = values
    return cases, skipped
a, a_skipped = read(system_path)
b, b_skipped = read(port_path)
if a_skipped or b_skipped:
    print("cases the harness refused to compare: %d" % len({n for n, _ in a_skipped} | {n for n, _ in b_skipped}))
    for who, skipped in (("system", a_skipped), ("port", b_skipped)):
        for name, why in skipped:
            print("  %s side: %s: %s" % (who, name, why))
    print("a case that did not run is not a case that passed; this comparison is red")
    raise SystemExit(1)
if not a:
    print("the system answered no case at all:", open(system_path).read()[:200], open(system_path + ".err").read()[:200] if __import__('os').path.exists(system_path + ".err") else "")
    raise SystemExit(1)
if sorted(a) != sorted(b):
    print("the two runs reached different cases: system %s, port %s" % (sorted(a), sorted(b)))
    raise SystemExit(1)
print("cases: %d, tolerance %g absolute or relative" % (len(a), tolerance))
bad = 0
# The largest distance each case came to, as a fraction of the tolerance it was allowed, so the
# number the tolerance is compared against is printed rather than implied: a case that lands at a
# thousandth of the bound and a case that lands on it read the same in "differing cases: 0".
worst = []
for name in sorted(a):
    exact = name.startswith("pooling-")
    limit = 0.0 if exact else tolerance
    used = 0.0
    for index, (x, y) in enumerate(zip(a[name], b[name])):
        if limit == 0.0:
            close = x == y
            used = 0.0 if close else float("inf")
        else:
            close = abs(x - y) <= limit * max(1.0, abs(x), abs(y))
            used = max(used, abs(x - y) / (limit * max(1.0, abs(x), abs(y))))
        if not close:
            print("  DIFFERS %-28s [%d] system %.9g port %.9g" % (name, index, x, y))
            bad += 1
            break
    if not exact:
        worst.append((used, name))
worst.sort(reverse=True)
print("closest to the tolerance, as a fraction of it:")
for used, name in worst[:5]:
    print("  %-28s %.3g" % (name, used))
print("differing cases: %d" % bad)
raise SystemExit(1 if bad else 0)
PY
cnn_status=$?
# Every claim the facts page makes about this run, checked against this run: which cases are
# bit-identical, and the largest distance the page quotes. Wired here because a page that names a case
# among the identical ones and prints that case's differing element lower down is a page written from
# memory, and this is the transcript that says otherwise. The page is named, not globbed.
FACTS_CNN=$here/../../../../packages/a/apple-backports/facts/MetalPerformanceShaders/Cnn.md
page_status=0
python3 "$here/page-check.py" "$build" "$FACTS_CNN" || page_status=$?
if [ "$page_status" -ne 0 ]; then
    echo "a claim in $FACTS_CNN is not what this run produced"
    exit 1
fi
echo "page: the CNN facts page agrees with this run, claim for claim"
echo "port: within the tolerance, case for case"
