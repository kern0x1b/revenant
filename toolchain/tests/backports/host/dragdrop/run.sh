#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/frameworks/apple-backports/UIKit}
harness=${DRAGDROP_HARNESS:-$here/../../device}
build=${DRAGDROP_BUILD:-$(runs_folder revenant-dragdrop-host)}
# The port files this harness builds. Three of the five that are missing were missing the same way: the
# port reaches across its own files and the harness does not. UIDropSession.m holds RevenantDragSession and
# RevenantDropSession, which UIDragInteraction.m sends to; RevenantDragDrop.m holds
# revenant_set_drag_interaction_enabled_default, which +[UIDragInteraction initialize] calls. A class and a C
# helper are both reached without a symbol the linker can name, so only these sources say whether they
# are there, and the link is the check that the list is complete.
sources="UIDragItem.m UIDropProposal.m UIDragInteraction.m UIDropInteraction.m UIDragDropSession.m UIDropSession.m RevenantDragDrop.m"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
# The renamed names, and the one that was spelt wrong: the port's UIDropSession-conforming class is
# UIDragDropSession (UIDragDropSession.m:20, and registry/UIKit/ios11.json carries the row), so the flag
# renamed RevenantDragDropSession - a name nothing declares - and the differential asked for
# RevenantHostDragDropSession, which no rename ever produced. It read "drop session is constructible" as a
# FAIL because NSClassFromString answered nil. The right-hand side is what the differential asks for and
# is left alone.
renames="-DUIDragItem=RevenantHostUIDragItem -DUIDropProposal=RevenantHostUIDropProposal -DUIDragInteraction=RevenantHostUIDragInteraction -DUIDropInteraction=RevenantHostUIDropInteraction -DUIDragDropSession=RevenantHostDragDropSession"
rm -rf "$build"
mkdir -p "$build"
objects=""
for source in $sources; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden -w $renames -I"$UIKIT" -c "$UIKIT/$source" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
# CoreGraphics is linked because the port calls into it - CGRectIsEmpty in -[UIDragInteraction
# revenant_pictureForView:] - and UIKit does not re-export it, so the linker said `Undefined symbols
# _CGRectIsEmpty` for a function the SDK declares at CGGeometry.h:169.
xcrun clang $target -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework UIKit -framework Foundation -framework CoreGraphics -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
