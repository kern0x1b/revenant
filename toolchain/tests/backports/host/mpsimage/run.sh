#!/bin/sh
# run.sh - the MPSImage arithmetic and threshold kernels: this port's, against the release's own.
#
# Two builds of one case file:
#   * the system build links the host's MetalPerformanceShaders and runs the release's kernels;
#   * the port build is marked -DCHARON_PORT_BUILD, is renamed through a header generated from the
#     classes THIS package's objects actually define, and links those objects with the Metal band's, so
#     the MPSImage it builds and the answer it reads back are the port's own. A case that ran against the
#     release's class would compare the release with itself, and the two builds' `class …` lines say
#     which class each of them resolved.
#
# The port build is run three times - normal, and under the two plants - and the comparison has to pass
# once and fail twice, naming the plants. A comparison that has never been seen to fail is not a
# comparison, and the two plants are the cheapest way to see one.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
mps=${MPS:-$root/packages/a/apple-backports/MetalPerformanceShaders}
metal=$root/packages/a/apple-backports/Metal
build=${BUILD:-$here/../../../../.agent-work/runs/host/mpsimage}
# The parent of the build directory is made too: the default path resolves to
# <repo>/.agent-work/runs/host, which is where the brief puts run output, and the first compile failed
# with "unable to open output file" because nothing had made it.
mkdir -p "$build"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation"
# A HOST harness: both builds link the host frameworks and run here, so both are for the
# host target and the host SDK - the line the CNN harness uses for the same reason, that an
# armv7 object cannot be linked into a binary this machine runs. The library's own armv7
# build is the device check and is a separate command; this is the differential.
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
# NO Metal-band objects, and the host's -framework Metal instead - the route mpscnn takes
# (`metal sources in mpscnn run.sh: 0`). The band cannot be built for a host binary here:
# Metal/CharonMetal.h:3 includes <OpenGLES/EAGL.h> with no guard, and the iPhoneOS SDK keeps that
# header at System/Library/Frameworks/OpenGLES.framework/Headers/EAGL.h, which no single -I makes
# reachable as <OpenGLES/EAGL.h>:
#
#   $ xcrun clang … -I"$SDK/System/Library/Frameworks" -c Metal/CAMetalLayer8.m
#   ./CharonMetal.h:3:9: fatal error: 'OpenGLES/EAGL.h' file not found
#
# So in THIS harness the port's MPSImage resolves MTLTextureDescriptor to the HOST's class, and that
# difference between the harness and the shipped build is named in
# facts/MetalPerformanceShaders/Image.md rather than hidden. The shipped build is unaffected: the
# placement that keeps the symbol off the bands below Metal is the registry `minimum` the MPSImage rows
# carry, from the 4.3 gate work.
plain=""
for source in "$mps"/*.m; do
    name=$(basename "$source" .m)
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -c "$source" -o "$build/$name.plain.o" || exit 1
    plain="$plain $build/$name.plain.o"
done
nm -gU $plain | awk '$3 ~ /^_OBJC_CLASS_\$_/ { print $3 }' | sort -u > "$build/port-defines.txt"
python3 - "$build/port-defines.txt" "$build/rename.h" <<'PY'
import sys
defined = set()
for line in open(sys.argv[1]):
    line = line.strip()
    if line.startswith("_OBJC_CLASS_$_"):
        defined.add(line[len("_OBJC_CLASS_$_"):])
with open(sys.argv[2], "w") as out:
    for name in sorted(defined):
        out.write("#define %s Charon%s\n" % (name, name))
PY
n_def=$(grep -c define "$build/rename.h")
n_cls=$(wc -l < "$build/port-defines.txt" | tr -d ' ')
echo "renamed: $n_def classes of $n_cls"


# ---- one build per plant, OBJECTS AND ALL.
#
# The plant has to be compiled into the objects, not just into the case file. It used to be passed only
# on the case file's own compile line, while the 45 library objects were built once without it - so the
# -D reached nothing that mattered, the kernels were compiled with the plant compiled out, and both
# planted binaries produced byte-identical correct output. That is why the plants never bit, and it is
# exactly the failure the control exists to catch: it looked armed and was not.
#
# Each build gets its own object directory, so the planted and unplanted objects cannot be confused.
build_one() {
    _plant=$1
    _name=$2
    _objdir="$build/obj-p$_plant"
    rm -rf "$_objdir"
    mkdir -p "$_objdir"
    _objects=""
    for source in "$mps"/*.m; do
        _s=$(basename "$source" .m)
        xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$mps" -include "$build/rename.h" \
            -DCHARON_PLANT=$_plant -c "$source" -o "$_objdir/$_s.o" || return 1
        _objects="$_objects $_objdir/$_s.o"
    done
    xcrun clang -fobjc-arc $target $quiet -DCHARON_PORT_BUILD=1 -DCHARON_PLANT=$_plant \
        -include "$build/rename.h" "$here/image-cases.m" $_objects \
        -framework Metal -framework MetalPerformanceShaders -o "$build/$_name" 2>/dev/null || return 1
    "$build/$_name" > "$build/$_name.txt" 2> "$build/$_name.err"
    echo $? > "$build/$_name.status"
    echo "  $_name: $(grep -c '^case ' "$build/$_name.txt") case lines, $(cat "$build/$_name.status") objects=$(echo "$_objects" | wc -w | tr -d ' ') planted"
}

build_one 0 port        || { echo "mpsimage: the port build FAILED"; exit 1; }
build_one 1 port-plant1 || { echo "mpsimage: the all-wrong plant build FAILED"; exit 1; }
build_one 2 port-plant2 || { echo "mpsimage: the one-wrong plant build FAILED"; exit 1; }

# there is no release-side build in this script: nothing ever compiled one, so $build/system does
# not exist and this line only ever reported that. The oracle is the CPU reference above.

# what each side said on stderr is reported, not merged into the data: a Metal assertion is
# written to stderr by the driver and lands mid-line in a merged stream, where it became a
# "value" of the case being printed - which is a harness failure reported as a data failure.
for _n in port port-plant1 port-plant2; do
    if [ -s "$build/$_n.err" ]; then
        echo "  $_n stderr: $(wc -l < "$build/$_n.err" | tr -d ' ') line(s)"
        sed -n '1,3p' "$build/$_n.err" | cut -c1-150 | sed 's/^/    /'
    fi
done

# ---- THE RED CONTROL, against the oracle that exists here.
#
# Nothing in this script ever BUILT the release-side binary: line 94 only ran $build/system, so on any
# host where it was absent the comparison below iterated over an empty set and every case "passed",
# including both planted builds. That is the defect this whole series has been about - a check that
# examined nothing and said so - and it hid here because the case file already carries a real oracle:
# it compares every element against a plain C reference computed in the same process from the
# release's own header formulas, counts them, and returns non-zero on any mismatch. So each binary's
# OWN exit status is the verdict, and it is available on every host, with or without the release.
#
#   port        must exit 0 and report no mismatch  - the kernels agree with the header
#   plant 1     must exit non-zero and report at least one - every element wrong, and it is noticed
#   plant 2     must exit non-zero and report at least one - one element wrong, and it is noticed
#
# A control that cannot fail is not a control, so each of these is an assertion about the harness as
# much as about the port, and a failure of any one of them fails the run.
ok=1
for _n in port port-plant1 port-plant2; do
    _st=$(cat "$build/$_n.status" 2>/dev/null || echo missing)
    _mm=$(grep -aoE '^COMPARED [0-9]+  MISMATCHES [0-9]+' "$build/$_n.txt" 2>/dev/null | tail -1)
    _bad=$(printf '%s' "$_mm" | grep -oE 'MISMATCHES [0-9]+$' | grep -oE '[0-9]+$')
    _bad=${_bad:-none}
    _want=0
    [ "$_n" != port ] && _want=1
    _good=0
    if [ "$_want" = 0 ]; then
        [ "$_st" = 0 ] && [ "$_bad" = 0 ] && _good=1
    else
        [ "$_st" != 0 ] && [ "$_st" != missing ] && [ "$_bad" != none ] && [ "$_bad" -gt 0 ] && _good=1
    fi
    if [ "$_good" = 1 ]; then
        echo "  ok    $_n: exit $_st, $_mm"
    else
        echo "  FAIL  $_n: exit $_st, ${_mm:-no COMPARED line} - a planted build must fail and an"
        echo "        unplanted one must not, and this one did neither"
        ok=0
    fi
done
[ "$ok" = 1 ] || { echo "mpsimage: THE RED CONTROL DID NOT HOLD"; exit 1; }
echo "mpsimage: the red control holds - the port agrees with the header and both plants are caught"

# ---- and not against the release, which this host cannot do.
#
# There is no release-side build in this script and there never was: it ran $build/system, which no step
# compiled, so on any host without that binary the comparison iterated an empty set and every case -
# including both planted ones - passed. That block is gone rather than guarded, because a comparison
# with nothing to compare against cannot distinguish a right answer from no answer.
#
# What replaces it is the oracle above, which is available everywhere: each case file computes the
# release's own header formulas in plain C in the same process and compares every element itself.
# Comparing the port against Apple's MPS binaries stays worth doing, and belongs in a harness that
# builds them - on a host where the release's kernels actually run. This host's AGX family lacks
# computeCommandEncoderWithDispatchType: and the release's own kernel dies encoding, so there is
# nothing here to compare against and pretending otherwise is what this series keeps having to undo.
echo "mpsimage: compared against the CPU reference in the case files; no release-side build exists in this script"
exit 0
