#!/bin/sh
# run.sh - VideoToolbox's pixel rotation, held to what this Mac's own VTPixelRotationSession does AND to an
# expectation computed from the source pattern alone.
#
#   1. probe.m asks the host for 320 cells - ten source shapes x two pixel formats x sixteen operations, four
#      rotations crossed with the two flips alone and together - and compares each against pixels derived
#      from the source alone. All four channels of every pixel are compared, and so are the bytes between
#      the end of each row and the start of the next.
#   2. probe.m checks its own expectation against a HAND-WRITTEN 180 PER SHAPE before the host is asked for
#      that shape, so a wrong expectation cannot hide behind a matching host. The 2x4 shape whose display
#      channel runs 1 11 / 21 31 / 41 51 / 61 71 must come back upside down, 71 61 / 51 41 / 31 21 / 11 1;
#      the 3x5 and the 1-wide shapes have theirs written out the same way, ten of them.
#   3. A forced padded bytesPerRow is ASSERTED, not hoped for: there is no public CVPixelBufferAttributeKey
#      for a bytes per row, so the padded stride comes from an IOSurface wrapped by
#      CVPixelBufferCreateWithIOSurface, and a stride the caller did not get is counted and fails the run.
#   4. Four plants must each turn it red, and each red must be shown PER SHAPE, because a shape whose cells
#      are never compared is green for the wrong reason. The fourth is a wrong HAND-WRITTEN 180: no cell
#      differs when it is wrong, so the hand-check is the only thing that can catch it, and the run proves
#      that it does.
#   5. The refusals are measured and asserted where the port will cite them: the rotation property is a
#      CFStringRef (three ways of getting that wrong, all kVTParameterErr = -12902), OneComponent8 and
#      444YpCbCr8 answer kVTPixelRotationNotSupportedErr = -12914, a 420 destination is converted rather
#      than rotated, a cross-format destination is converted rather than rotated, and a destination geometry
#      VTPixelRotationSession.h:79 forbids is scale-to-fitted rather than refused.
#
# WHAT IT DELIBERATELY DOES NOT CLAIM: any biplanar YUV. A 420 image's chroma planes are subsampled by two
# on each axis, so rotating one is a second contract with its own arithmetic, and the host answers a 420
# destination with a colour conversion, not with a rotation.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${BUILD:-$(runs_fresh revenant-videotoolbox-pixelrotation)}
mkdir -p "$build"

frameworks="-framework VideoToolbox -framework CoreVideo -framework CoreMedia -framework Foundation -framework IOSurface"

# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w "$here/probe.m" $frameworks -o "$build/probe" > "$build/cc.log" 2>&1 || {
    echo "COMPILE FAILED:"; cat "$build/cc.log"; exit 1; }

echo "--- the host, against an expectation computed from the source alone"
"$build/probe"

survived=0
# $1 the plant's name, $2 the needle, $3 the replacement, $4 the smallest pixel count this plant has to
# turn red at. The run reads the shape's own pixel count out of the mutant's SIZE line rather than out of a
# list of shapes written here, and the floor is 2 for all three because a ONE-PIXEL shape is the fixed
# point of all three faults: a quarter turn of one pixel is the identity (dest(x,y) = src(y, H-1-x) with
# H = 1 and y = x = 0), a rejected rotation property leaves the session at kVTRotation_0, which on one
# pixel is the same picture, and base + i*4 with one destination pixel is base + 0, the same address. That
# the 1x1 shape is green under every plant is therefore arithmetic, and the table below prints it as green
# rather than counting it as a shape the harness forgot.
plant() {
    label=$1; from=$2; to=$3; floor=${4:-none}
    if ! xmake l "$here/../../common/replace.lua" "$here/probe.m" "$build/mutant.m" "$from" "$to"; then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        return
    fi
    # shellcheck disable=SC2086
    if ! xcrun clang -fobjc-arc -w "$build/mutant.m" $frameworks -o "$build/mutant-bin" \
        > "$build/mutant-cc.log" 2>&1; then
        echo "MUTANT DID NOT BUILD, which is not the same as being noticed: $label"
        survived=$((survived + 1))
        return
    fi
    if "$build/mutant-bin" > "$build/mutant.out" 2>&1; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
        return
    fi
    echo "  caught: $(grep -m1 '^CELLS' "$build/mutant.out")"
    awk -v floor="$floor" '
        /^SIZE / {
            pixels = $5; sub("pixels=", "", pixels)
            differing = $7; sub("differing=", "", differing)
            key = $2 " " $3
            if (!(key in seen)) { seen[key] = pixels + 0; order[++n] = key }
            red[key] = differing + 0
        }
        END {
            for (i = 1; i <= n; i++) {
                k = order[i]
                printf "    %-18s pixels=%-3d %s\n", k, seen[k], (red[k] > 0 ? "RED" : "green")
                if (floor != "none" && seen[k] >= floor + 0 && red[k] == 0) missed = missed " " k
            }
            if (missed != "") printf "    NOT RED above the floor of %s pixels:%s\n", floor, missed
        }
    ' "$build/mutant.out" > "$build/shapes.txt"
    cat "$build/shapes.txt"
    if grep -q 'NOT RED above the floor' "$build/shapes.txt"; then
        survived=$((survived + 1))
    fi
}

echo "--- the plants"
plant "the CW90 and CCW90 mappings swapped" \
    'if (CFEqual(rotation, kVTRotation_CW90))      { sx = py;               sy = (int)shape->height - 1 - px; }' \
    'if (CFEqual(rotation, kVTRotation_CW90))      { sx = (int)shape->width - 1 - py; sy = px; }' \
    2
plant "the rotation property set with an NSNumber, as the first probe did" \
    '                OSStatus setRotation = VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation,
                                                             OPS[o].rotation);' \
    '                OSStatus setRotation = VTSessionSetProperty(session, kVTPixelRotationPropertyKey_Rotation,
                                                             (__bridge CFNumberRef)@(0));' \
    2
plant "the read-back at a contiguous offset instead of the buffer own bytesPerRow" \
    '                        const uint8_t *pixel = base + y * destStride + x * 4;' \
    '                        const uint8_t *pixel = base + i * 4;' \
    2
plant "one hand-written 180 written wrong, which is the guard against a wrong expectation" \
    'static const int hand180_3x5[] = { 141, 131, 121, 111, 101, 91, 81, 71, 61, 51, 41, 31, 21, 11, 1 };' \
    'static const int hand180_3x5[] = { 141, 131, 121, 111, 101, 91, 81, 71, 61, 51, 41, 31, 21, 11, 11 };' \
    none

if [ "$survived" -ne 0 ]; then echo "$survived plants survived; this check proves nothing"; exit 1; fi
echo "videotoolbox-pixelrotation: OK - 320 cells over ten shapes and two formats agree with the host and"
echo "  with the ten hand-written 180s; the padded bytesPerRow was forced where asked for; all four"
echo "  channels and the inter-row bytes compared; 4 plants caught, the three faults red in every shape"
echo "  they can reach and the wrong hand-written 180 caught with no cell differing at all"