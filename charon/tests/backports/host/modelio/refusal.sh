#!/bin/sh
# The refusal test: a face index past the end of the points.
#
# What the system does was measured first, and it is NOT a throw. It logs
#   <file>: face vertex index out of bound.
# and LOADS the asset, with the mesh carrying no submeshes. So this asserts THAT on the port, and the red
# control is the same script with the port's refusal removed: if it still passed without the refusal, it would
# not be testing the refusal at all.
#
# Both outcomes are printed, not just the log line, because a reader that logs loudly and returns nil and a
# reader that loads a mesh look identical on stderr unless the result is stated too.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
pkg=$root/packages/a/apple-backports/ModelIO
build=${BUILD:-$root/.agent-work/runs/modelio-refusal}
# The build directory is CLEARED, not added to. Every earlier attempt at this script appeared to do nothing
# because a stale MDLVertexDescriptor9.o from the previous attempt was still in $build and was linked
# alongside the one the current attempt compiled, giving a duplicate symbol that named a file no longer in
# the script. A refusal test that reuses yesterday s objects is not testing today's code.
rm -rf "$build"
mkdir -p "$build/in"
cat > "$build/in/bad.usda" <<'EOF'
#usda 1.0
(
    defaultPrim = "Bad"
    metersPerUnit = 1
    upAxis = "Y"
)
def Mesh "Bad"
{
    int[] faceVertexCounts = [3]
    int[] faceVertexIndices = [0, 1, 99]
    point3f[] points = [(0, 0, 0), (1, 0, 0), (1, 1, 0)]
}
EOF
SDK=${CHARON_SDK_DIR:-$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk 2>/dev/null | head -1)}
[ -d "$SDK" ] || { echo "FAIL  no iPhoneOS 16.4 SDK; set CHARON_SDK_DIR"; exit 1; }

# THE SAME NAMED LIST the differential builds, not a glob over the package. A glob also compiles
# MDLVertexAttributes9.m, which defines MDLVertexAttributeShadingBasisU - the same symbol the MetalKit file
# defines - and the link fails on a duplicate that names a file this script never mentions. That is the
# whole of what the previous six attempts of this script were fighting.
carried="MDLAnimatedValue11.m MDLAnimatedValue16.m MDLAssetResolver11.m MDLMaterial101.m MDLMeshBuffer11.m \
MDLTransformStack11.m MDLTransformStack16.m MDLTransform9.m MDLObject9.m MDLMeshBuffer9.m MDLSubmesh9.m \
MDLMesh9.m MDLMeshGenerators9.m MDLMaterial9.m MDLTexture9.m MDLVoxelArray9.m MDLAsset9.m"
quiet="-Wno-unknown-pragmas -Wno-unused-value -Wno-nonnull -Wno-deprecated-declarations \
-Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation \
-Wno-nullability-completeness -Wno-unguarded-availability"
for f in $carried; do
    f="$pkg/$f"
    xcrun clang -fobjc-arc -fvisibility=hidden $quiet -c "$f" -o "$build/$(basename "$f" .m).o" 2>"$build/cc.log" || {
        echo "BUILD  $(basename "$f")"; head -3 "$build/cc.log" | sed 's/^/    /'; exit 1; }
done
# The same three objects the differential links, in the same order: port-support for the symbols ModelIO
# itself exports and the port does not, the MetalKit file for the MDLVertexAttribute class, and the
# ModelIO package itself. MDLVertexAttributes9.o defines the NAME constants and no class, which is why
# linking it alone left _OBJC_CLASS_$_MDLVertexAttribute undefined.
xcrun clang -fobjc-arc -fvisibility=hidden -w -I "$pkg" -c "$here/port-support.m" -o "$build/port-support.o" \
    2>"$build/cc.log" || { echo "BUILD  port-support"; head -3 "$build/cc.log" | sed 's/^/    /'; exit 1; }
# MDLVertexAttribute is a CLASS and none of the ModelIO package defines it: MDLVertexAttributes9.m defines
# the three name constants, and the class lives in the MetalKit file the differential links for exactly this
# reason. It is compiled here into the cleared build directory and linked once.
xcrun clang -fobjc-arc -fvisibility=hidden $quiet \
    -c "$root/packages/a/apple-backports/MetalKit/MDLVertexDescriptor9.m" -o "$build/MetalKit.o" \
    2>"$build/cc.log" || { echo "BUILD  the vertex descriptor"; head -3 "$build/cc.log" | sed 's/^/    /'; exit 1; }
xcrun clang -fobjc-arc $quiet -DMDL_TEXTURE_TAKES_IS_CUBE=0 -DMDL_PLANE_TAKES_INWARD_NORMALS=1 \
    -I"$here" -framework CoreServices -framework Foundation -framework CoreGraphics -framework ImageIO \
    "$build"/MDL*.o "$build"/MetalKit.o "$build"/port-support.o "$here/throw.m" -o "$build/throw" 2>"$build/cc.log" || {
    echo "BUILD  the port probe"; head -3 "$build/cc.log" | sed 's/^/    /'; exit 1; }

"$build/throw" "$build/in/bad.usda" > "$build/out.txt" 2> "$build/err.txt" || true
sed 's/^/    /' "$build/err.txt"
sed 's/^/    /' "$build/out.txt"
grep -q 'face vertex index out of bound' "$build/err.txt" || {
    echo "FAIL  the port did not report the bad index by name"; exit 1; }
grep -q 'LOADED' "$build/out.txt" || {
    echo "FAIL  the port did not load the asset, and the system does"; exit 1; }
grep -q 'THREW' "$build/out.txt" && {
    echo "FAIL  the port raised, and the system does not"; exit 1; }
echo "refusal: the port logs the bad index by name and loads the asset, as the system does"
