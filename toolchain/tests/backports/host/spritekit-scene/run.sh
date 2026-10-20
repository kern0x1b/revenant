#!/bin/sh
# run.sh - the host differential of the SKScene surface (iOS 7 and 8) and SKNode's scene, and the control that says it
# can fail.
#
# differential.m is built twice from one source: against the host's own SpriteKit framework (the oracle), and against
# the port's SpriteKit7.o, SpriteKit8.o, SpriteKit9.o, SpriteKitScene7.o and SpriteKitScene8.o, with no SpriteKit
# framework linked. The stdout of the two runs must be identical line by line. The refusals the framework logs (NSLog,
# on stderr) must be the same once the timestamp and process are removed.
#
# The control is the same differential linked against a copy of SpriteKitScene7.m in which the frame's anchor point
# moves the origin the wrong way. The run passes only when the port matches the host and the control's output differs.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
src=${SPRITEKIT_SRC:-$root/packages/frameworks/apple-backports/SpriteKit}
build=${SPRITEKIT_SCENE_BUILD:-$(runs_folder spritekit-scene)}
rm -rf "$build"
mkdir -p "$build/control"

xcrun clang -fobjc-arc -framework Foundation -framework SpriteKit "$here/differential.m" -o "$build/oracle"
for object in SpriteKit7 SpriteKit8 SpriteKit9 SpriteKitScene7 SpriteKitScene8; do
    xcrun clang -fobjc-arc -Wall -Wextra -Werror -I "$src" -c "$src/$object.m" -o "$build/$object.o"
done
xcrun clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework AppKit "$here/differential.m" \
    "$build/SpriteKit7.o" "$build/SpriteKit8.o" "$build/SpriteKit9.o" "$build/SpriteKitScene7.o" "$build/SpriteKitScene8.o" \
    -o "$build/differential-port"

# The control: the anchor's sign reversed in the frame, one line, so the control has the same number of lines.
sed 's|CGRectMake(-_anchorPoint.x|CGRectMake(_anchorPoint.x|; s|, -_anchorPoint.y|, _anchorPoint.y|' "$src/SpriteKitScene7.m" > "$build/control/SpriteKitScene7.m"
cmp -s "$src/SpriteKitScene7.m" "$build/control/SpriteKitScene7.m" && { echo "FAIL the control mutation did not apply"; exit 1; }
xcrun clang -fobjc-arc -I "$src" -c "$build/control/SpriteKitScene7.m" -o "$build/control-scene7.o"
xcrun clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework AppKit "$here/differential.m" \
    "$build/SpriteKit7.o" "$build/SpriteKit8.o" "$build/SpriteKit9.o" "$build/control-scene7.o" "$build/SpriteKitScene8.o" \
    -o "$build/differential-control"

status=0
"$build/oracle" > "$build/log-host" 2> "$build/err-host" || status=1
"$build/differential-port" > "$build/log-port" 2> "$build/err-port" || status=1
"$build/differential-control" > "$build/log-control" 2> "$build/err-control" || status=1
for side in host port; do
    sed 's/^.*\] //' "$build/err-$side" > "$build/refusals-$side"
done

if cmp -s "$build/log-host" "$build/log-port" && cmp -s "$build/refusals-host" "$build/refusals-port"; then
    echo "ok SKScene port matches the host: $(wc -l < "$build/log-host" | tr -d ' ') lines, $(wc -l < "$build/refusals-host" | tr -d ' ') refusals"
else
    echo "FAIL SKScene port differs from the host:"
    diff "$build/log-host" "$build/log-port" || status=1
    diff "$build/refusals-host" "$build/refusals-port" || status=1
fi
if [ "$(wc -l < "$build/log-control")" -ne "$(wc -l < "$build/log-host")" ]; then
    echo "FAIL the control did not print every line: its log is not comparable"
    status=1
elif cmp -s "$build/log-host" "$build/log-control"; then
    echo "FAIL the control matched the host: the differential cannot tell the mutated frame apart"
    status=1
else
    echo "control differs from the host (must): $(diff "$build/log-host" "$build/log-control" | grep -c '^>') line(s)"
fi
echo "logs=$build"
exit $status
