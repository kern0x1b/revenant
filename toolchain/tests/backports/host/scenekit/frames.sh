#!/bin/sh
# frames.sh <scenes> <frames> : the port's SCNView frames of Telegram's star2 and coin against macOS SceneKit's.
# <scenes> holds star2.scn and coin.scn (Telegram's PremiumUI resources, decompressed) with their images. <frames>
# holds, for each scene S, what device/scenekit-frames.m wrote on a device at 256 points:
#   S-full.png          scenekit-frames S.scn 256 S-full.png noparticles
#   S-drawn.png         ... noparticles nosubdiv noclearcoat nonormal
#   S-wrongD.png        ... noparticles roughness+D, D = 0.02, 0.05, 0.1 (a renderer a little wrong)
# It prints, in compare.py's terms (IoU, mean, p95): what the switches cost on macOS alone; S-drawn against macOS's
# frame of the same switched scene, which holds nothing the port does not draw; S-full against macOS's frame of the
# scene as it is; each S-wrongD against macOS's switched frame. It checks one thing: S-full and S-drawn are identical,
# the switches taking away nothing the port draws. No bound on the frames is set yet (facts/SceneKit/SCNView.md,
# "The frame tolerance"). Run it through coordination/heavy.sh (it renders with Metal).
set -eu
echo "FAIL host/scenekit/frames.sh: its Python steps are gone and not yet ported to Lua: compare.py" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
SCENES=$1
FRAMES=$2
BUILD=${BUILD:-$(runs_fresh revenant-scenekit)}
undrawn="nosubdiv noclearcoat nonormal"
xcrun swiftc -O "$here/render.swift" -o "$BUILD/render"
status=0
for scene in star2 coin; do
    "$BUILD/render" "$SCENES/$scene.scn" 256 0 "$BUILD/$scene-full.png" noparticles
    "$BUILD/render" "$SCENES/$scene.scn" 256 0 "$BUILD/$scene-drawn.png" noparticles $undrawn
    echo "$scene: cost of what the port does not draw, on macOS: $(python3 "$here/compare.py" "$BUILD/$scene-full.png" "$BUILD/$scene-drawn.png")"
    same=$(python3 "$here/compare.py" "$FRAMES/$scene-full.png" "$FRAMES/$scene-drawn.png")
    case "$same" in
        "iou=1.0000 mean=0.00 p95=0 "*) echo "$scene same: $same" ;;
        *) echo "$scene same: $same (not identical)"; status=1 ;;
    esac
    echo "$scene drawn: $(python3 "$here/compare.py" "$BUILD/$scene-drawn.png" "$FRAMES/$scene-drawn.png")"
    echo "$scene full: $(python3 "$here/compare.py" "$BUILD/$scene-full.png" "$FRAMES/$scene-full.png")"
    for d in 0.02 0.05 0.1; do
        echo "$scene wrong $d, drawn: $(python3 "$here/compare.py" "$BUILD/$scene-drawn.png" "$FRAMES/$scene-wrong$d.png")"
    done
done
exit $status
