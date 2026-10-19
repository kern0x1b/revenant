#!/bin/sh
# run.sh - the host differential of SKShapeNode (and its iOS 8 points form), SKLabelNode, SKCropNode and SKEffectNode, and
# the control that says it can fail.
#
# differential.m is built twice from one source: against the host's own SpriteKit framework (the oracle), and against the
# port's SpriteKit7.o, SpriteKitShape7.o, SpriteKitLabel7.o, SpriteKitCrop7.o, SpriteKitEffect7.o, SpriteKit8.o,
# SpriteKitTexture7.o and SpriteKitSprite7.o, with no SpriteKit framework linked (CoreImage is linked on both sides, for the
# filter). The stdout of the two runs must be identical line by line.
#
# The control is the same differential linked against a copy of SpriteKitShape7.m in which the default stroke width is
# moved. The run passes only when the port matches the host and the control's output differs.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
src=${SPRITEKIT_SRC:-$root/packages/a/apple-backports/SpriteKit}
build=${SPRITEKIT_SHAPE_BUILD:-$root/.agent-work/runs/spritekit-shape-label}
rm -rf "$build"
mkdir -p "$build/control"

xcrun clang -fobjc-arc -framework Foundation -framework AppKit -framework CoreImage -framework SpriteKit "$here/differential.m" -o "$build/oracle"
for object in SpriteKit7 SpriteKit8 SpriteKitShape7 SpriteKitLabel7 SpriteKitCrop7 SpriteKitEffect7 SpriteKitTexture7 SpriteKitSprite7; do
    xcrun clang -fobjc-arc -Wall -Wextra -Werror -I "$src" -c "$src/$object.m" -o "$build/$object.o"
done
objects="$build/SpriteKit7.o $build/SpriteKit8.o $build/SpriteKitShape7.o $build/SpriteKitLabel7.o $build/SpriteKitCrop7.o $build/SpriteKitEffect7.o $build/SpriteKitTexture7.o $build/SpriteKitSprite7.o"
xcrun clang -fobjc-arc -framework Foundation -framework AppKit -framework CoreImage "$here/differential.m" $objects -o "$build/differential-port"

# The control: the default stroke width of a shape moved from 1 to 2.
sed 's|_lineWidth = 1;|_lineWidth = 2;|' "$src/SpriteKitShape7.m" > "$build/control/SpriteKitShape7.m"
cmp -s "$src/SpriteKitShape7.m" "$build/control/SpriteKitShape7.m" && { echo "FAIL the control mutation did not apply"; exit 1; }
xcrun clang -fobjc-arc -I "$src" -c "$build/control/SpriteKitShape7.m" -o "$build/control-shape.o"
control_objects=$(echo $objects | sed "s|$build/SpriteKitShape7.o|$build/control-shape.o|")
xcrun clang -fobjc-arc -framework Foundation -framework AppKit -framework CoreImage "$here/differential.m" $control_objects -o "$build/differential-control"

status=0
"$build/oracle" > "$build/log-host" 2> "$build/err-host" || status=1
"$build/differential-port" > "$build/log-port" 2> "$build/err-port" || status=1
"$build/differential-control" > "$build/log-control" 2> "$build/err-control" || status=1

if cmp -s "$build/log-host" "$build/log-port"; then
    echo "ok SKShapeNode, SKLabelNode, SKCropNode and SKEffectNode port match the host: $(wc -l < "$build/log-host" | tr -d ' ') lines"
else
    echo "FAIL the port differs from the host:"
    diff "$build/log-host" "$build/log-port" || status=1
fi
if [ "$(wc -l < "$build/log-control")" -ne "$(wc -l < "$build/log-host")" ]; then
    echo "FAIL the control did not print every line: its log is not comparable"
    status=1
elif cmp -s "$build/log-host" "$build/log-control"; then
    echo "FAIL the control matched the host: the differential cannot tell the mutated stroke width apart"
    status=1
else
    echo "control differs from the host (must): $(diff "$build/log-host" "$build/log-control" | grep -c '^>') line(s)"
fi
echo "logs=$build"
exit $status
