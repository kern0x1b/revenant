#!/bin/sh
# run.sh - the three MPSImage kernels SDK 16.4's headers mark ios(9.0), measured against a CPU
# reference written from the release's own header formulas.
#
# ONE build of one case file covers all three kernels; nothing here is built per row. Three builds in
# all, the same file with a plant compiled in, and the comparison has to pass once and fail twice.
#
# There is NO system build, and that is deliberate rather than a gap: this host's AGX family does not
# implement computeCommandEncoderWithDispatchType:, and the release's own MPSImage kernels die encoding
# with '-[AGXG16XFamilyCommandBuffer mtlnext computeCommandEncoderWithDispatchType:]': unrecognized
# selector. The release answers nothing on this machine. The oracle is the header's formula, computed
# in the case file's own process, and every registry row for these three says so in its reason. A
# comparison against an empty set of release answers is what this family keeps having to undo.
#
# The port's classes are renamed through a header generated from the classes THIS build's objects
# actually define, so the MPSImage and the answer are the port's own and not the release's class
# reached by accident.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
mps=${MPS:-$root/packages/a/apple-backports/MetalPerformanceShaders}
build=${BUILD:-$root/.agent-work/runs/host/mpsimage9}
mkdir -p "$build"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation"
# A HOST harness: it links the host frameworks and runs here, so it is for the host target and the host
# SDK. The library's own armv7 build is the device check and is a separate command.
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"

# ---- the objects, once, and the rename header from what they define.
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
echo "renamed: $(grep -c define "$build/rename.h") classes of $(wc -l < "$build/port-defines.txt" | tr -d ' ')"

# ---- the plant has to be compiled into the OBJECTS, not only into the case file. The sibling harness
# had it passed only on the case file's own compile line while the library objects were built once
# without it, so the -D reached nothing that mattered and both planted binaries produced byte-identical
# correct output. Each build therefore gets its own object directory.
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
        -include "$build/rename.h" "$here/mps9-cases.m" $_objects \
        -framework Metal -framework MetalPerformanceShaders -o "$build/$_name" 2>/dev/null || return 1
    "$build/$_name" > "$build/$_name.txt" 2> "$build/$_name.err"
    echo $? > "$build/$_name.status"
    echo "  $_name: $(grep -c '^case ' "$build/$_name.txt") case lines, $(cat "$build/$_name.status") objects=$(echo "$_objects" | wc -w | tr -d ' ') planted"
}

build_one 0 port        || { echo "mps9: the port build FAILED"; exit 1; }
build_one 1 port-plant1 || { echo "mps9: the all-wrong plant build FAILED"; exit 1; }
build_one 2 port-plant2 || { echo "mps9: the one-wrong plant build FAILED"; exit 1; }

# What each side said on stderr is reported, not merged into the data: a Metal assertion is written to
# stderr by the driver and lands mid-line in a merged stream, where it becomes a "value" of the case
# being printed - a harness failure reported as a data failure.
for _n in port port-plant1 port-plant2; do
    if [ -s "$build/$_n.err" ]; then
        echo "  $_n stderr: $(wc -l < "$build/$_n.err" | tr -d ' ') line(s)"
        sed -n '1,3p' "$build/$_n.err" | cut -c1-150 | sed 's/^/    /'
    fi
done

# ---- THE RED CONTROL. Each binary's OWN exit status is the verdict, because the case file compares
# every element against the CPU reference in the same process and returns non-zero on any mismatch.
#   port        must exit 0 and report no mismatch - the kernels agree with the header
#   plant 1     must exit non-zero and report at least one - every element wrong, and it is noticed
#   plant 2     must exit non-zero and report at least one - one element wrong, and it is noticed
# A control that cannot fail is not a control, so these are assertions about the harness as much as
# about the port.
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
[ "$ok" = 1 ] || { echo "mps9: THE RED CONTROL DID NOT HOLD"; exit 1; }
echo "mps9: the red control holds - the port agrees with the header and both plants are caught"

# ---- which classes each build resolved, printed rather than assumed: a case that ran against the
# RELEASE's MPSImageIntegral would compare the release with itself, and the class lines say which.
grep '^class ' "$build/port.txt" | sed 's/^/  /'
echo "mps9: compared against the CPU reference in the case file; no release-side build exists in this script"
exit 0
