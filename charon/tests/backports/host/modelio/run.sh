#!/bin/sh
# Two processes, one probe, the same inputs: the system's ModelIO and the port's own sources built
# for macOS, each run separately over the input files the probe itself writes, each writing what it
# computed as canonical text. The two files are then compared line by line.
#
# The port process links the port's own sources and NOT the system ModelIO, so the two never meet in
# one runtime; port-support.m supplies the handful of symbols ModelIO itself exports that a release
# without it has to carry. Nothing in the comparison is tuned: a line that differs is reported.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
MODELIO=${MODELIO:-$here/../../../../packages/a/apple-backports/ModelIO}
BUILD=${BUILD:-$here/../../../../.agent-work/runs/modelio-diff}
# CHARON_HOST_BUILD: this is a host differential - the port's process links no framework of the name it
# measures, so there is no release class for a charon_alias.h proxy to stand in for, nothing for the
# library's loader to re-parent and no name to export. The header's own comment gives the two
# measurements: the macOS linker refuses the metaclass alias ("ld: null objc class data for
# '_OBJC_METACLASS_$_Charon<Name>'", from the smallest file that carries nothing but CHARON_ALIAS), and
# a name built by ## cannot be renamed the way this harness renames classes. What the alias is FOR is a
# device band; here the class of the release's name is the class and every member of it is measured.
quiet="-DCHARON_HOST_BUILD -Wno-unknown-pragmas -Wno-unused-value -Wno-nonnull -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-availability -Wno-objc-missing-property-synthesis -Wno-incomplete-implementation"
VERTICES=${VERTICES:-$here/../../../../packages/a/apple-backports/MetalKit/MDLVertexDescriptor9.m}
carried="MDLAnimatedValue11.m MDLAnimatedValue16.m MDLAssetResolver11.m MDLMaterial101.m MDLMeshBuffer11.m MDLTransformStack11.m MDLTransformStack16.m MDLTransform9.m MDLObject9.m MDLMeshBuffer9.m MDLSubmesh9.m MDLMesh9.m MDLMeshGenerators9.m MDLMaterial9.m MDLTexture9.m MDLVoxelArray9.m MDLAsset9.m"
rm -rf "$BUILD/host" "$BUILD/port"
mkdir -p "$BUILD/host" "$BUILD/port"

# The system answers: the probe alone, against the framework the host carries.
xcrun clang -fobjc-arc $quiet -DMDL_TEXTURE_TAKES_IS_CUBE=1 -DMDL_PLANE_TAKES_INWARD_NORMALS=0 "$here/probe.m" -framework ModelIO -framework CoreGraphics -framework ImageIO \
    -framework CoreServices -framework Foundation -o "$BUILD/host/probe"

# The port answers: the probe, the port's own sources, and the symbols ModelIO would have exported.
# The readers live in a category of MDLAsset, so MDLAsset9.m is compiled with the rest.
for file in $carried; do
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$MODELIO/$file" -o "$BUILD/port/${file%.m}.o"
done
# The vertex descriptor and its attribute and layout are the port's too, and live beside the port's
# other sources in the MetalKit library, which libModelIOBackports.dylib therefore needs.
xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$VERTICES" -o "$BUILD/port/MDLVertexDescriptor9.o"
xcrun clang -fobjc-arc $quiet -c "$here/port-support.m" -o "$BUILD/port/port-support.o"
xcrun clang -fobjc-arc $quiet -DMDL_TEXTURE_TAKES_IS_CUBE=0 -DMDL_PLANE_TAKES_INWARD_NORMALS=1 -I"$here" "$here/probe.m" "$BUILD/port"/*.o -framework CoreGraphics -framework ImageIO \
    -framework CoreServices -framework Foundation -o "$BUILD/port/probe"

mkdir -p "$BUILD/host/in" "$BUILD/port/in"
"$BUILD/host/probe" "$BUILD/host/in" > "$BUILD/host/answers.txt" 2> "$BUILD/host/err.txt" || {
    echo "the system probe failed:"; tail -5 "$BUILD/host/err.txt"; exit 1; }
cp "$BUILD/host/in"/* "$BUILD/port/in/" 2>/dev/null || true
"$BUILD/port/probe" "$BUILD/port/in" > "$BUILD/port/answers.txt" 2> "$BUILD/port/err.txt" || {
    echo "the port probe failed:"; tail -5 "$BUILD/port/err.txt"; exit 1; }

# The inputs are the same files: the port reads the ones the system wrote, so both are measured over
# byte-identical inputs rather than over two runs of the same generator.
if ! cmp -s "$BUILD/host/in/cube.obj" "$BUILD/port/in/cube.obj"; then
    echo "the two processes were not given the same inputs"; exit 1
fi

# WHICH IMAGE ANSWERED. The port process does not link the system ModelIO, which already means the two
# never meet in one runtime - but that is a fact about the LINK, and a link can be edited. Every answer now
# carries the Mach-O that defined the class it came from, and these two assertions turn it into a runtime
# fact: a host answer that did not come from ModelIO, or a port answer that did, fails the run instead of
# passing on the link being right for a reason nobody looked at.
python3 - "$BUILD/host/err.txt" "$BUILD/port/err.txt" <<'PY'
import sys
def images(path):
    out = {}
    for line in open(path, errors="replace"):
        if line.startswith("image "):
            parts = line.split()
            if len(parts) >= 4:
                out.setdefault(parts[1], set()).add(parts[3])
    return out
host, port = images(sys.argv[1]), images(sys.argv[2])
if not host or not port:
    print("FAIL  no image lines: the probe did not report which image answered")
    sys.exit(1)
for cls, kinds in sorted(host.items()):
    for kind in kinds:
        if kind != "system-modelio":
            print("FAIL  the host answered %s from %s, not from the system ModelIO" % (cls, kind)); sys.exit(1)
for cls, kinds in sorted(port.items()):
    for kind in kinds:
        if kind != "port":
            print("FAIL  the port answered %s from %s - it does not link ModelIO" % (cls, kind)); sys.exit(1)
common = set(host) & set(port)
print("  images: %d classes on both sides (%d host, %d port); host from the system ModelIO,"
      " port from its binary and band objects" % (len(common), len(host), len(port)))
PY

# THE KNOWN-OPEN COUNT IS CHECKED, not remembered. compare.py prints every difference and a summary line, so
# the number of "different:" lines above IS the tally; this checks it against known-open.txt and fails if they
# differ, in either direction. A run carrying differences nobody recorded is a FAIL, and so is a recorded
# difference the run no longer produces: the two cannot drift apart, and the number of open differences is
# on the output rather than only in a message somebody has to remember to write.
output=$(python3 "$here/compare.py" "$BUILD/host/answers.txt" "$BUILD/port/answers.txt" "${1:-0.0005}" 2>&1) || true
printf '%s\n' "$output"
actual=$(printf '%s\n' "$output" | grep -c '^different:')
recorded=$(grep -c '^[^#]' "$here/known-open.txt" || true)
echo "  KNOWN OPEN: $actual differing, $recorded recorded in known-open.txt"
[ "$actual" = "$recorded" ] || {
    echo "FAIL  the run reports $actual differences and known-open.txt records $recorded; update one of them"
    exit 1; }
status=$?
# A DIFFERING LINE MUST FAIL THE RUN, not be reported and passed over. compare.py s status is kept, and a
# non-zero from the image check above already exits; this makes the intent explicit at the call site.
if [ "$status" -ne 0 ]; then
    echo "answers differ: see $BUILD/host/answers.txt and $BUILD/port/answers.txt"
fi
echo "answers: $BUILD/host/answers.txt $BUILD/port/answers.txt"
exit $status
