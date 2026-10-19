#!/bin/sh
# run.sh - does this port's MPSNDArray hold the same shapes, the same views and the same bytes as the
# release's own MPSNDArray?
#
# WHAT THIS SETTLES, and what it does not. The descriptor's own arithmetic, the order a view is built
# in, the element order a packed read and write walk, and the width of a row are THIS OBJECT's work
# and nothing else in the package reaches them. So every shared case here is a question about storage,
# and storage is the one part of MPS the release's own framework answers on this host - which is why
# there are TWO builds and a comparison rather than a build against a CPU reference.
# tests/backports/host/mpsimage9/run.sh records the other half of this: that this host's AGX family
# lacks computeCommandEncoderWithDispatchType: and the release's own MPSImage kernels die encoding, so
# for the KERNELS a reference is the header's formula and nothing here claims a kernel.
#
# WHAT THE RELEASE CANNOT ANSWER HERE, measured and not assumed. Two cases are port-only and live in
# export-cases.m: the export/import pair, and a ShallNotAlias copy. The release's own
# -exportDataWithCommandBuffer:toBuffer:... and its ShallNotAlias path both die with
# '-[AGXG16XFamilyCommandBuffer_mtlnext retainedReferences]: unrecognized selector', raised inside
# MPSCore's MPSNewBufferForTexture on its way to MPSDecrementReadCount - the same AGX-family
# limitation the image family records, reached here through a STORAGE path rather than a compute one.
# Those two state their own expectations in their own file, and the rows that rest on them say so.
#
# THE RENAME, and it is the mechanism mpsimage9's and mpscnn's harnesses already use rather than a
# copy of it: a header built from the classes the port's objects DEFINE, applied to BOTH the objects
# and the case file. The host's MPS framework defines every class this object defines, so unrenamed
# the process holds two classes of each name and whichever loaded first answers the case - a
# difference the comparison could never see, because it would be comparing the release with itself.
# The rename is the mechanism; the plants below are the receipt.
#
# A PLANT in the port's own COPY path, and it is this object's own rather than the family-wide
# CharonMPSStore one - which measurably does not reach here, because -readBytes:strideBytes: and
# -writeBytes:strideBytes: copy bytes and never call the store, so a plant on that path produces a
# byte-identical binary and a green run it did not earn. Two plants, first and last byte, so a
# comparison that reads only one end of each case cannot see one of them. The run has to pass once and
# fail twice, or the comparison is not looking at the thing it claims to.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
mps=${MPS:-$root/packages/a/apple-backports/MetalPerformanceShaders}
build=${BUILD:-$root/.agent-work/runs/host/mpsndarray}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness"
sources="MPSNDArray13 MPSNDArrayKernel13 MPSNDArrayOps13"

# ---- pass one: the objects unrenamed, and the rename header from what THEY define. This pass's only
# job is to name the classes; nothing links against it.
for name in $sources; do
    xcrun clang -fno-objc-arc -fvisibility=hidden $target $quiet -I"$mps" \
        -c "$mps/$name.m" -o "$build/$name.plain.o" || exit 1
done
xcrun nm -gU $build/*.plain.o | awk '$3 ~ /^_OBJC_CLASS_\$_/ { print $3 }' | sort -u > "$build/port-defines.txt"
python3 - "$build/port-defines.txt" "$build/rename.h" <<'PY'
import sys
names = sorted(line.strip()[len("_OBJC_CLASS_$_"):] for line in open(sys.argv[1]) if line.strip())
with open(sys.argv[2], "w") as out:
    for name in names:
        out.write("#define %s Charon%s\n" % (name, name))
print("classes the port defines: %d" % len(names))
PY

# build_one <plant> <name> <case file> - every object AND the case file renamed together, so the two
# sides of the comparison are the port's own classes and the release's own and never a mixture.
build_one() {
    _plant=$1
    _name=$2
    _cases=$3
    _objdir="$build/obj-p$_plant"
    rm -rf "$_objdir"
    mkdir -p "$_objdir"
    # The plant macro is DEFINED only for a planted build. Defining it as 0 would still select the
    # planted path - `#if defined(CHARON_NDARRAY_PLANT)` is true for a 0 - and the "unplanted" build
    # would then be plant 2, which is what happened the first time this ran: the comparison was red
    # by exactly the +0x08 the second plant adds, on every case.
    _plantflag=""
    [ "$_plant" -ne 0 ] && _plantflag="-DCHARON_NDARRAY_PLANT=$_plant"
    _objects=""
    for name in $sources; do
        xcrun clang -fno-objc-arc -fvisibility=hidden $target $quiet -I"$mps" -include "$build/rename.h" \
            $_plantflag -c "$mps/$name.m" -o "$_objdir/$name.o" || return 1
        _objects="$_objects $_objdir/$name.o"
    done
    xcrun clang -fobjc-arc $target $quiet -include "$build/rename.h" "$_cases" $_objects \
        -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/$_name" || return 1
    "$build/$_name" > "$build/$_name.txt" 2> "$build/$_name.err" && _status=0 || _status=$?
    echo "$_status" > "$build/$_name.status"
    echo "  $_name: $(wc -l < "$build/$_name.txt" | tr -d ' ') lines, exit $_status"
}

# ---- build one: the system's own MPS. Nothing of the port's is linked in, so every answer is Apple's.
xcrun clang -fobjc-arc $target $quiet "$here/ndarray-cases.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$build/release" || exit 1
"$build/release" > "$build/release.txt"
echo "  release: $(wc -l < "$build/release.txt" | tr -d ' ') lines"

# ---- build two: the port's own classes, under names of their own. The same case file, so the two
# runs differ only in whose objects answered.
build_one 0 port "$here/ndarray-cases.m" || { echo "mpsndarray: the port build FAILED"; exit 1; }

# ---- the comparison, line by line, so a difference names the case that made it.
python3 - "$build/release.txt" "$build/port.txt" <<'PY'
import sys
def read(path):
    return [l.rstrip("\n") for l in open(path) if l.strip() and not l.startswith("commit:")]
a, b = read(sys.argv[1]), read(sys.argv[2])
bad = [(x, y) for x, y in zip(a, b) if x != y]
if len(a) != len(b):
    print("compared: the release printed %d lines, the port %d" % (len(a), len(b)))
    bad += [("<missing>", ">") for _ in range(abs(len(a) - len(b)))]
print("compared: %d lines" % min(len(a), len(b)))
if bad:
    print("MISMATCHES: %d" % len(bad))
    for x, y in bad:
        print("  release: %s\n  port:    %s" % (x, y))
    sys.exit(1)
print("MISMATCHES: 0")
PY

# ---- the plants: the port's own store path, so the comparison is shown a port that writes the wrong
# value. Both of these MUST fail the comparison, or the comparison is not looking at the port.
for plant in 1 2; do
    build_one $plant port-plant$plant "$here/ndarray-cases.m"
    if python3 - "$build/port.txt" "$build/port-plant$plant.txt" <<'PY'
import sys
def read(path):
    return [l.rstrip("\n") for l in open(path) if l.strip() and not l.startswith("commit:")]
sys.exit(0 if read(sys.argv[1]) == read(sys.argv[2]) else 1)
PY
    then
        echo "PLANT $plant SURVIVED: the comparison cannot see a port that writes the wrong value"
        exit 1
    fi
    echo "  plant $plant caught: the comparison is looking at the port's own writes"
done

# ---- the port-only cases: the export/import pair and a ShallNotAlias copy, which the release cannot
# answer on this host. Their expectations are stated in their own file and printed here.
build_one 0 export "$here/export-cases.m" || { echo "mpsndarray: the export build FAILED"; exit 1; }
echo "export cases (port only: the release dies on this host, see the header of export-cases.m):"
sed 's/^/  /' "$build/export.txt"

# ---- the three kernels, against the plain C reference IN kernel-cases.m. There is no release build of
# these, and the header of that file says why: this host cannot commit the command buffer a kernel
# encodes into, so the reference is the header's own wording computed in the same process.
build_one 0 kernel "$here/kernel-cases.m" || { echo "mpsndarray: the kernel build FAILED"; exit 1; }
echo "kernel cases (port only: the release cannot commit a command buffer on this host):"
sed 's/^/  /' "$build/kernel.txt"
# The kernels' verdict is the CASE FILE'S OWN exit status, because it is what compared its numbers.
if [ "$(cat "$build/kernel.status" 2>/dev/null || echo missing)" != "0" ]; then
    echo "verdict: FAIL"
    exit 1
fi
# And the plants must reach the kernels too, or the comparison above is not looking at them.
for plant in 1 2; do
    build_one $plant kernel-plant$plant "$here/kernel-cases.m"
    if [ "$(cat "$build/kernel-plant$plant.status" 2>/dev/null || echo 0)" = "0" ]; then
        echo "PLANT $plant SURVIVED the kernels: the kernel comparison cannot see a port that computes the wrong value"
        exit 1
    fi
    echo "  plant $plant caught by the kernels as well"
done

echo "verdict: PASS"
