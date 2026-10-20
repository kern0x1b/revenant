#!/bin/sh
# Two processes, one probe, the same script, compared as rendered bytes.
#
# The port's CIImageAccumulator re-implements a class the framework already has, so a process that
# linked both would get the framework's. The port's copy is therefore built here under a name of its
# own and linked beside the framework: the framework's accumulator is in the process and is never
# asked, and the two never touch the same object. The pixel formats and the parameter names come from
# the framework in the port process - the same values the port's own constants carry, over 136 of them
# measured equal to the host's.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../../packages/frameworks/apple-backports/Graphics}
TOLERANCE=${1:-0.0005}
BUILD=${BUILD:-$(runs_fresh revenant-pixel)}
quiet="-Wno-nonnull -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-availability -Wno-objc-missing-property-synthesis -Wno-incomplete-implementation"
rm -rf "$BUILD"
mkdir -p "$BUILD/host" "$BUILD/port"
# The port's classes under the names its build gives them; the sed below renames both the sources and
# the header, so the two always agree.
sed -e 's/CIImageAccumulator/RevenantCIImageAccumulator/g' -e 's/RevenantRevenant/Revenant/g' "$GRAPHICS/CIImageAccumulator9.m" > "$BUILD/port/CIImageAccumulator.m"
sed -e 's/CIFilterShape/RevenantCIFilterShape/g' -e 's/RevenantRevenant/Revenant/g' "$GRAPHICS/CIFilterShape9.m" > "$BUILD/port/CIFilterShape.m"
# The colour-space and the representation methods are categories on classes the framework already has,
# so the port's copies attach to the framework's objects and need no rename: two processes, one set of
# objects each, and the two never meet.
cp "$GRAPHICS/CIColor10.m" "$BUILD/port/CIColor.m"
cp "$GRAPHICS/CIContextRepresentations10.m" "$BUILD/port/CIContextRepresentations.m"
cp "$GRAPHICS/CIImageAlgebra10.m" "$BUILD/port/CIImageAlgebra.m"
sed -e 's/RevenantGOCtxContext/RevenantGGCtxContext/g' -e 's/RevenantRevenant/Revenant/g' "$GRAPHICS/CIContextGCOwner11.m" > "$BUILD/port/CIContextGCOwner.m"
# The port's classes, under names of their own. The renamed support header is what the probe imports,
# so it goes where the import finds it and the include path is given - not -include, which would put a
# second copy of the same declarations in front of it.
sed -e 's/\bCIImageAccumulator\b/RevenantCIImageAccumulator/g' -e 's/\bCIFilterShape\b/RevenantCIFilterShape/g' -e 's/\bRevenantGOCtxContext\b/RevenantGGCtxContext/g' -e 's/RevenantRevenant/Revenant/g' "$here/port-support.h" > "$BUILD/port/port-support.h"
sed -e 's/CIImageAccumulator/RevenantCIImageAccumulator/g' -e 's/RevenantRevenant/Revenant/g' "$GRAPHICS/CIImageAccumulator9.m" > "$BUILD/port/CIImageAccumulator.m"
sed -e 's/CIFilterShape/RevenantCIFilterShape/g' -e 's/RevenantRevenant/Revenant/g' "$GRAPHICS/CIFilterShape9.m" > "$BUILD/port/CIFilterShape.m"
# The colour-space and the representation methods, the drawing, the kernel and the algebra are
# categories on classes the framework already has, so the port's copies attach to the framework's
# objects and need no rename: two processes, one set of objects each, and the two never meet.
cp "$GRAPHICS/CIColor10.m" "$BUILD/port/CIColor.m"
cp "$GRAPHICS/CIContextRepresentations10.m" "$BUILD/port/CIContextRepresentations.m"
cp "$GRAPHICS/CIImageAlgebra10.m" "$BUILD/port/CIImageAlgebra.m"
sed -e 's/RevenantGOCtxContext/RevenantGGCtxContext/g' -e 's/RevenantRevenant/Revenant/g' "$GRAPHICS/CIContextGCOwner11.m" > "$BUILD/port/CIContextGCOwner.m"

# The system answers: the probe alone, against the framework the host carries.
xcrun clang -fobjc-arc $quiet "${CH_PROBE:-$here/probe.m}" -framework CoreImage -framework CoreGraphics -framework ImageIO -framework Foundation -o "$BUILD/host/probe"

# The port answers: the same probe, built with the macro the support header actually tests, so it is
# the port's classes it asks and it says so.
objects=""
for piece in CIImageAccumulator CIFilterShape CIColor CIContextRepresentations CIImageAlgebra \
            CIContextGCOwner; do
    # The port's classes are declared in the renamed support header, so their own sources see their
    # own names; CIContextGCOwner declares its class itself and is given the header only for the rest.
    if [ "$piece" = CIContextGCOwner ]; then
        xcrun clang -fobjc-arc $quiet -DREVENANT_PORT -c "$BUILD/port/$piece.m" -o "$BUILD/port/$piece.o"
    else
        xcrun clang -fobjc-arc $quiet -DREVENANT_PORT -include "$BUILD/port/port-support.h" -c "$BUILD/port/$piece.m" -o "$BUILD/port/$piece.o"
    fi
    objects="$objects $BUILD/port/$piece.o"
done
xcrun clang -fobjc-arc $quiet -DREVENANT_PORT -I"$BUILD/port" -c "${CH_PROBE:-$here/probe.m}" -o "$BUILD/port/probe.o"
xcrun clang -fobjc-arc $quiet "$BUILD/port/probe.o" $objects -framework CoreImage -framework CoreGraphics \
    -framework ImageIO -framework CoreServices -framework Foundation -o "$BUILD/port/probe"

"$BUILD/host/probe" > "$BUILD/host/answers.txt"
"$BUILD/port/probe" > "$BUILD/port/answers.txt"
# The port process must be asking the port's classes. If it is asking the framework's, the two answers
# would be identical whatever the port does, and every line below would be the framework measured
# against itself.
if [ "$(head -1 "$BUILD/port/answers.txt")" != "probe port" ]; then
    echo "the port probe is not the port: it says '$(head -1 "$BUILD/port/answers.txt")'"
    exit 2
fi
runs_xmake l "$here/../../modelio/compare.lua" compare "$BUILD/host/answers.txt" "$BUILD/port/answers.txt" "$TOLERANCE" ciimage
status=$?
echo "answers: $BUILD/host/answers.txt $BUILD/port/answers.txt"
exit $status
