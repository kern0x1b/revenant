#!/bin/sh
# run.sh - what a temporary IMAGE's read count does when a kernel reads it.
#
# ONE case file, compiled twice. The first build is the system's own MetalPerformanceShaders; the
# second is this port's classes with their MPS names mapped to Charon names, so the port's own
# MPSTemporaryImage and its own threshold kernel are the ones being asked and cannot be answered by
# the host's class reached by accident.
#
# THE TWO TRANSCRIPTS ARE NOT COMPARED, and that is the finding rather than a gap: on this host the
# release's own MPS cannot make an MPSTemporaryImage at all, so it has no answer for this decrement to
# be compared with. The case prints the selector it raises. What IS checked is the port's own
# contract, written down in cases.m from MPSImage.h:1030-1036, and a plant of that contract has to
# turn the run red.
#
# Not a differential and not a claim about Apple's arithmetic: nothing here measures Apple's code.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
mps=${MPS:-$here/../../../../packages/a/apple-backports/MetalPerformanceShaders}
build=${BUILD:-$here/../../../../.agent-work/runs/host/mpstemporary}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness"

# ---- build one: the system's own MPS. Nothing of the port's is linked in, so every line it prints
# is Apple's.
xcrun clang -fobjc-arc $target $quiet "$here/cases.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/system"
"$build/system" > "$build/system.txt" 2> "$build/system.err" || true
echo "system: $(wc -l < "$build/system.txt" | tr -d ' ') lines"
sed 's/^/  /' "$build/system.txt"

# ---- build two: the port's own objects, under Charon names. The rename header is generated from
# what the objects below actually DEFINE, read out of their symbols, so a class this subset happens
# not to carry is not renamed and the case cannot ask for it.
sources="MPSImageWalk13 MPSImage9 MPSImage13 MPSImageElements10 MPSImageConvolution13 CharonMPSTemporaryImage"
plain=""
for name in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -c "$mps/$name.m" -o "$build/$name.plain.o"
    plain="$plain $build/$name.plain.o"
done
for object in $plain; do xcrun nm -g --defined-only "$object"; done \
    | grep -oE '_OBJC_CLASS_\$_[A-Za-z0-9_]+' | sed 's/_OBJC_CLASS_\$_//' | sort -u > "$build/port-defines.txt"
python3 - "$build/port-defines.txt" "$build/rename.h" <<'PY'
import sys
names = [line.strip() for line in open(sys.argv[1]) if line.strip()]
with open(sys.argv[2], 'w') as out:
    for name in names:
        out.write("#define %s Charon%s\n" % (name, name))
print("classes the port's subset defines, renamed: %d" % len(names))
PY

# The classes this harness is about, named here so the run FAILS if one is missing from the objects.
# Without this the harness would compile, run and compare, and every check would be about an object
# that was never linked in - a green run that measured nothing.
python3 - "$build/port-defines.txt" <<'PY'
import sys
defined = {line.strip() for line in open(sys.argv[1]) if line.strip()}
wanted = ["MPSImage", "MPSTemporaryImage", "MPSImageConvolution", "CharonMPSTemporaryImageAllocator"]
missing = [name for name in wanted if name not in defined]
if missing:
    print("the port's objects do not define: %s" % ", ".join(missing))
    raise SystemExit(1)
print("the port's subset defines all %d classes this case asks for" % len(wanted))
PY

# The port's objects are REBUILT with the rename header, which is what makes the port's classes the
# ones the case links against: compiled without it they would define MPSImage while the case asks for
# CharonMPSImage, and the link would fail rather than silently reach the host's class.
objects=""
for name in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -include "$build/rename.h" \
        -c "$mps/$name.m" -o "$build/$name.o"
    objects="$objects $build/$name.o"
done
xcrun clang -fobjc-arc $target $quiet -DCHARON_PORT_BUILD=1 -include "$build/rename.h" \
    "$here/cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/port"
if ! "$build/port" > "$build/port.txt" 2> "$build/port.err"; then
    echo "port: FAILED"
    sed 's/^/  /' "$build/port.txt"
    sed 's/^/  /' "$build/port.err" | tail -5
    exit 1
fi
echo "port: $(wc -l < "$build/port.txt" | tr -d ' ') lines"
sed 's/^/  /' "$build/port.txt"

# ---- the plant: the same build with MPSTemporaryImage out of the shared helper, which is what the
# state of this tree was before the fix. Check 2 is the one that has to notice, so if this passes the
# comparison cannot fail and the run above proved nothing.
mkdir -p "$build/plant/MPS"
# The sources are COPIED, not compiled in place with a different -I: an #import "CharonMPS.h" resolves in
# the including file's own directory first, so patching a header in another directory would be silently
# ignored and the plant would build the very code it is meant to remove. The copy is what makes the plant
# real, and the header diff below is what proves it.
cp "$mps"/*.h "$mps"/*.m "$build/plant/MPS/"
sed '/if (\[object isKindOfClass:\[MPSTemporaryImage class\]\]) {/,/^    }$/d' \
    "$build/plant/MPS/CharonMPS.h" > "$build/plant/CharonMPS.h.patched"
if cmp -s "$build/plant/MPS/CharonMPS.h" "$build/plant/CharonMPS.h.patched"; then
    echo "the plant changed nothing: CharonMPS.h no longer has the case this harness removes"
    exit 1
fi
mv "$build/plant/CharonMPS.h.patched" "$build/plant/MPS/CharonMPS.h"
echo "plant removed $(( $(grep -c MPSTemporaryImage "$mps/CharonMPS.h") - $(grep -c MPSTemporaryImage "$build/plant/MPS/CharonMPS.h") )) MPSTemporaryImage mentions from the helper"
for name in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$build/plant/MPS" \
        -include "$build/rename.h" -c "$build/plant/MPS/$name.m" -o "$build/plant/$name.o"
done
xcrun clang -fobjc-arc $target $quiet -DCHARON_PORT_BUILD=1 -include "$build/rename.h" \
    "$here/cases.m" "$build/plant"/*.o \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/planted"
if "$build/planted" > "$build/plant.txt" 2>&1; then
    echo "the plant PASSED, so the comparison cannot fail and the run above proved nothing"
    sed 's/^/  /' "$build/plant.txt"
    exit 1
fi
echo "plant: caught (as it must be)"
grep '^FAIL' "$build/plant.txt" | sed 's/^/  /' || true

echo "verdict: PASS"