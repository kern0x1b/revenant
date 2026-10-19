#!/bin/sh
# run.sh - the ARSCNView view: the pairing and the geometry sources, measured on the host.
#
# The host has SceneKit and it has no ARKit - ARKit has never shipped on macOS, and the SDK declaring
# these classes is the iPhoneOS one, whose headers cannot be compiled into a macOS build. So the harness
# supplies the declarations of the port's own classes (`ARKitShim.h`, the same names, selectors and
# property types) and the port supplies the implementation, which is the half under test. The port's
# own sources are compiled *into* the harness, so what runs is the port's code and not a
# re-implementation of it.
#
# What is measured, both of which SceneKit can see:
#   the pairing - a node added for an anchor, a child walking up to its parent's anchor, a node
#   following an anchor that replaced it, and an anchor going away on removal; and
#   the geometry sources - read back through SceneKit's own accessors, not through anything this
#   package declares.
#
# What stays out: the frame's own projection and unprojection, which the view forwards to the camera.
# SceneKit cannot observe those, and they are carried as `documented` on their rows rather than
# measured here.
#
# `--mutants` changes one thing at a time in a *copy* of the port's sources under .agent-work and
# requires the run to go red. The tree is never touched: a mutant that edited the checkout would leave
# the band holding mutated source, and one that restored through git would take out whatever else was
# uncommitted - which is what the first version of this did, and why the copy is the rule now.

set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
ARKit=$repo/packages/a/apple-backports/ARKit
SceneKit=$repo/packages/a/apple-backports/SceneKit
runs=${RUNS:-$repo/.agent-work/runs/arkit-host}
mkdir -p "$runs"

# the declarations the port's own ARKit classes need, and the UIKit types CharonSCN.h:2 imports. They
# are force-included rather than imported through <ARKit/…>, because a shim that re-declares what the
# host's own AppKit and SceneKit already declare collides with them.
shim="$runs/shim"
mkdir -p "$shim/UIKit" "$shim/ARKit"
# the port's files import <ARKit/ARKit.h> and <ARKit/ARSCNView.h> by those names, so the shim has to
# answer to them; they forward to the one header that declares the classes
for header in ARKit ARSCNView ARSCNPlaneGeometry; do
    printf '#import <ARKitShim.h>\n' > "$shim/ARKit/$header.h"
done
cat > "$shim/UIKit/UIKit.h" <<'EOF'
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
@interface UIView : NSView
@property (nonatomic, readonly, nullable) CALayer *layer;
@end
@interface UIColor : NSColor
+ (UIColor *)clearColor;
+ (UIColor *)whiteColor;
+ (UIColor *)blackColor;
@end
EOF

# $1 is the directory holding the port's sources to build against
port() {
    src=$1
    clang -fobjc-arc -w -O1 \
        -include "$here/ARKitShim.h" -I "$here" -I "$shim" -I "$src" -I "$SceneKit" \
        "$here/arkit-scnview-diff.m" \
        "$src/ARSCNView11.m" "$src/ARSCNView12.m" "$src/ARSCNPlaneGeometry.m" \
        "$SceneKit/SCNGeometry.m" "$SceneKit/SCNGeometrySource.m" \
        "$SceneKit/SCNGeometryElement.m" "$SceneKit/CharonSCNCoding.m" \
        -framework Foundation -framework SceneKit -framework AppKit -framework CoreGraphics \
        -o "$runs/diff"
}

# The second differential: a reference image's physical size and the reading of a group. Both are
# arithmetic over a picture and the reading of a folder, so neither needs a frame - which is the only
# part of this family a host can answer at all. One file of the port is compiled into it, and only
# that one: ARReferenceImage.m imports no private header, which is what lets it be compiled here.
port_image() {
    src=$1
    clang -fobjc-arc -w -O1 \
        -include "$here/ARKitShim.h" -I "$here" -I "$shim" -I "$src" \
        "$here/arkit-image-diff.m" "$src/ARReferenceImage.m" \
        -framework Foundation -framework CoreGraphics -framework CoreVideo -framework ImageIO \
        -o "$runs/image-diff"
}

# ---- the plain run ----
port "$ARKit"
"$runs/diff" | tee "$runs/plain.txt"
grep -q '^VERDICT ok' "$runs/plain.txt" || { echo "FAIL: the differential is not green"; exit 1; }
port_image "$ARKit"
# the bundle is named by a path relative to the repository root, because that is how the fixture is
# found on disk and a path built out of the run's own directory would only be right here
(cd "$repo" && "$runs/image-diff") | tee "$runs/image-plain.txt"
grep -q '^VERDICT ok' "$runs/image-plain.txt" || { echo "FAIL: the image differential is not green"; exit 1; }
[ "${1:-}" = "--mutants" ] || { echo "ok the pairing answers both ways, the geometry sources are SceneKit's, and a reference image's size and group are read from a file"; exit 0; }

# ---- the mutants ----
survived=0
mutant() {
    label=$1; file=$2; from=$3; to=$4
    copy="$runs/mutant"
    rm -rf "$copy"; mkdir -p "$copy"
    cp "$ARKit/ARSCNView11.m" "$ARKit/ARSCNView12.m" "$ARKit/ARSCNPlaneGeometry.m" \
       "$ARKit/CharonARKitPrivate.h" "$ARKit/CharonARTracker.h" "$copy/"
    python3 "$here/mutate.py" "$copy/$file" "$from" "$to" || { echo "MUTANT NOT APPLIED: $label"; survived=$((survived + 1)); return; }
    if port "$copy" >/dev/null 2>&1 && "$runs/diff" > "$runs/mutant.txt" 2>&1 && grep -q '^VERDICT ok' "$runs/mutant.txt"; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "ok mutant killed: $label"
        grep 'FAIL$' "$runs/mutant.txt" 2>/dev/null | sed 's/^/    /' | head -2
    fi
}

# The two directions of the pairing swapped, so an anchor is looked up as though it were a node. The
# view's own lookup, in the view's own file.
mutant "nodeForAnchor: reads the node-keyed map" ARSCNView11.m \
    '    SCNNode *node = [self.nodesByAnchor objectForKey:anchor];
    if (node)
        return node;' \
    '    SCNNode *node = [self.anchorsByNode objectForKey:anchor];
    if (node)
        return node;'
mutant "the geometry update drops its coordinate source" ARSCNPlaneGeometry.m \
    '[self charon_replaceSources:@[ positionsSource, textureSource ] elements:@[ element ]];' \
    '[self charon_replaceSources:@[ positionsSource ] elements:@[ element ]];'

# The `willUpdateNode:` message dropped: the pairing is still made, still moved and still broken, and
# the only thing wrong is that the renderer is not told the change is coming. That is a mutation rather
# than a different implementation, which is why it has to be listed: the view is right and the delegate
# is under-told, and only the call order can see it.
mutant "the willUpdateNode: call is skipped" ARSCNView11.m \
    'if ([self.delegate respondsToSelector:@selector(renderer:willUpdateNode:forAnchor:)])' \
    'if (NO && [self.delegate respondsToSelector:@selector(renderer:willUpdateNode:forAnchor:)])'

# And one for the image differential, because a second check that cannot fail is the same evidence
# nothing. The mutation is the ratio written the other way round, which is the one mistake this
# arithmetic can make: a physical size that is still a size, still uses the picture, and is wrong.
mutant_image() {
    label=$1; file=$2; from=$3; to=$4
    copy="$runs/mutant-image"
    rm -rf "$copy"; mkdir -p "$copy"
    cp "$ARKit/ARReferenceImage.m" "$copy/"
    python3 "$here/mutate.py" "$copy/$file" "$from" "$to" || { echo "MUTANT NOT APPLIED: $label"; survived=$((survived + 1)); return; }
    if port_image "$copy" >/dev/null 2>&1 && (cd "$repo" && "$runs/image-diff") > "$runs/image-mutant.txt" 2>&1 && grep -q '^VERDICT ok' "$runs/image-mutant.txt"; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "ok mutant killed: $label"
        grep 'FAIL$' "$runs/image-mutant.txt" 2>/dev/null | sed 's/^/    /' | head -2
    fi
}
mutant_image "the physical size multiplies by the picture's other ratio" ARReferenceImage.m \
    '    return CGSizeMake(physicalWidth, physicalWidth * pixels.height / pixels.width);' \
    '    return CGSizeMake(physicalWidth, physicalWidth * pixels.width / pixels.height);'
if [ "$survived" -eq 0 ]; then
    echo "ok every mutant is killed: the differential can fail, and it fails for the right reason"
else
    echo "FAIL: $survived mutant(s) survived"
fi
exit "$survived"
