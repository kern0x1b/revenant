#!/bin/sh
# run.sh - AVDepthData and AVCameraCalibrationData (iOS 11.0), the port against the host's own framework.
#
# probe.m is built twice: plain, where every name is Apple's, and with the two class names renamed to the
# port's own (revenant_host_AVDepthData, revenant_host_AVCameraCalibrationData) and the port's AVDepthData11.m linked
# in, so the same questions are asked of the port's classes in the same binary. Both outputs are one line per
# answer, and diff is the check: the port must say what the host says, line for line, except where the named
# divergence below says otherwise.
#
# THE NAMED DIVERGENCE (measured, facts/AVFoundation/DepthData11.md): the host's metadata entry is a CGImageMetadata
# object, and the probe hands both sides a metadata STRING, which the host reads differently from its own object
# (any string reads as high quality, and its Accuracy and Filtered lines are not read). The port reads the text, so
# the probe's metadata cases differ on purpose. Those labels are ALLOWED_DIFF below; a difference on any other
# label is a red.
#
# What makes it a check and not a comparison:
#   * the output is asserted non-empty on both sides, so an empty table is a red and not a clean diff;
#   * a name the port does not define is a link error, so a missing class cannot read as "both absent";
#   * the run is PLANTED: MUTANT=1 compiles a copy of AVDepthData11.m whose reciprocal is not taken, and the diff
#     must show differences on labels that are not allowed; CONTROL=1 runs the unmutated source through the same
#     path and must pass;
#   * a build that fails is RUN FAILED with the compiler's first line, never a noticed mutation.
#
# Run DIRECTLY: two compiles and two runs, not through heavy.sh.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/a/apple-backports/AVFoundation
build=${AVF_DEPTH_BUILD:-$root/.agent-work/avf-depthdata-build}
mutant=${MUTANT:-0}
control=${CONTROL:-0}
ALLOWED_DIFF="metadata-0 metadata-1 metadata-2 metadata-3 metadata-4 tagged tagged-converted"
rm -rf "$build"
mkdir -p "$build"
frameworks="-framework Foundation -framework AVFoundation -framework CoreVideo -framework CoreGraphics"
renames="-DAVDepthData=revenant_host_AVDepthData -DAVCameraCalibrationData=revenant_host_AVCameraCalibrationData"
source="$avf/AVDepthData11.m"
[ -f "$source" ] || { echo "FAIL: $source does not exist, so the port's classes are not there to check"; exit 1; }
if [ "$mutant" = 1 ] && [ "$control" = 1 ]; then
    echo "FAIL: MUTANT and CONTROL are separate runs"
    exit 1
fi

if [ "$mutant" = 1 ]; then
    # The planted wrong answer: the reciprocal is returned unclamped, so 0 and negative values change.
    sed 's/return reciprocal < limit ? reciprocal : limit;/return reciprocal;/' "$source" > "$build/AVDepthData11.m"
    if cmp -s "$source" "$build/AVDepthData11.m"; then
        echo "FAIL: the planted mutation did not change the source, so the run would not prove anything"
        exit 1
    fi
    source="$build/AVDepthData11.m"
fi

clang -fobjc-arc -Wall -c $renames "$source" -o "$build/port.o" 2> "$build/port-build.log" || {
    echo "RUN FAILED: the port's AVDepthData11.m did not build:"; head -1 "$build/port-build.log"; exit 1; }
clang -fobjc-arc -DREVENANT_PORT=1 $renames "$here/probe.m" "$build/port.o" $frameworks -o "$build/port" 2> "$build/port-link.log" || {
    echo "RUN FAILED: the port probe did not link:"; head -1 "$build/port-link.log"; exit 1; }
clang -fobjc-arc "$here/probe.m" $frameworks -o "$build/host" 2> "$build/host-link.log" || {
    echo "RUN FAILED: the host probe did not link:"; head -1 "$build/host-link.log"; exit 1; }

"$build/host" > "$build/host.txt" 2> "$build/host-err.txt" || { echo "RUN FAILED: the host probe exited non-zero"; exit 1; }
"$build/port" > "$build/port.txt" 2> "$build/port-err.txt" || { echo "RUN FAILED: the port probe exited non-zero"; exit 1; }
rows=$(wc -l < "$build/host.txt" | tr -d ' ')
[ "$rows" -gt 80 ] || { echo "FAIL: the host probe printed $rows lines, so there is nothing to compare"; exit 1; }

# diff exits 1 when the two sides differ, which is an answer; anything above 1 is diff itself failing.
diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt" || [ $? -eq 1 ] || { echo "RUN FAILED: diff did not run"; exit 1; }
# The label a differing line belongs to is its first word: "<label> ..." in either side.
differing=$(grep '^[<>]' "$build/diff.txt" | awk '{print $2}' | sort -u | tr '\n' ' ')
unexpected=""
for label in $(echo "$differing"); do
    case " $ALLOWED_DIFF " in
        *" $label "*) ;;
        *) unexpected="$unexpected $label" ;;
    esac
done
if [ -z "$unexpected" ]; then
    if [ "$mutant" = 1 ]; then
        echo "avf-depthdata: FAIL the planted mutation was not noticed"
        exit 1
    fi
    echo "avf-depthdata: OK ($rows answers; the port and the host agree except the named metadata divergence)"
    exit 0
fi
if [ "$mutant" = 1 ]; then
    echo "avf-depthdata: planted mutation noticed on:$unexpected"
    exit 0
fi
echo "avf-depthdata: FAIL the port differs from the host on:$unexpected"
grep "^[<>]" "$build/diff.txt" | head -20
exit 1
