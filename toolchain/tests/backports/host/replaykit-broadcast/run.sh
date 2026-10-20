#!/bin/sh
# run.sh - the port's broadcast family (ReplayKit) against the host's own ReplayKit, case by case, in separate processes.
#
#   1. differential.m is COMPILED into a windowed Catalyst app (uikit2's windowed.m) against the host's ReplayKit, and run
#      once per case, the case named by DIFF_CASE
#   2. the same source is COMPILED against the port's ReplayKit sources instead, with no ReplayKit framework linked, and run
#      once per case
#   3. the outputs of each case are compared; a case where the host dies on a signal is named as such and is not counted
#      as agreement
#   4. two plants on a scratch copy of the port's sources - one answer changed, each in the case that measures it - must
#      turn that case red
#
# Two processes per case, not one, because both sides define the same classes. No case starts a broadcast or a recording.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/frameworks/apple-backports}
build=${BUILD:-$(runs_folder replaykit-broadcast)}
harness=$here/../../device
windowed=$here/../uikit2
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
frameworks="-framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics"
# UIKit brings the host's ReplayKit into every Catalyst process, so a port class of the same name is implemented twice and the
# runtime keeps one of them: the port side renames its classes and the two category selectors. differential.m strips the
# prefix when it prints a name, and the rename covers every use in both files, so the port side calls its own renamed methods.
renames="-DRPBroadcastActivityViewController=RevenantRPBroadcastActivityViewController -DRPBroadcastController=RevenantRPBroadcastController -DRPBroadcastConfiguration=RevenantRPBroadcastConfiguration -DRPBroadcastHandler=RevenantRPBroadcastHandler -DRPBroadcastSampleHandler=RevenantRPBroadcastSampleHandler -DRPBroadcastMP4ClipHandler=RevenantRPBroadcastMP4ClipHandler -DRPSystemBroadcastPickerView=RevenantRPSystemBroadcastPickerView -DloadBroadcastingApplicationInfoWithCompletion=revenantLoadBroadcastingApplicationInfoWithCompletion -DcompleteRequestWithBroadcastURL=revenantCompleteRequestWithBroadcastURL -DRPScreenRecorder=RevenantRPScreenRecorder -DRPPreviewViewController=RevenantRPPreviewViewController"
cases="constants activity-nil activity-named controller configuration configuration-copy picker superclasses handler-calls clip-handler request-context extension-context recorder recorder-available preview"
# A case whose difference is known and owed, not a failure: it is printed as KNOWN and not counted. recorder-available is the
# port's `available` answering NO until the recorder records (ruling 5); its registry row is inert, a safe NO that says so once.
known="recorder-available"

# bundle <bundle-dir> <extra arguments: the port's sources, or -framework ReplayKit for the host>
bundle() {
    out=$1; shift
    mkdir -p "$out/Contents/MacOS"
    xcrun clang $target -fobjc-arc -w -I"$harness" "$windowed/windowed.m" "$here/differential.m" "$harness/check.m" "$@" \
        $frameworks -o "$out/Contents/MacOS/app"
    cp "$windowed/windowed.plist" "$out/Contents/Info.plist"
    codesign -s - --force "$out" > /dev/null 2>&1
}

bundle "$build/host.app" -framework ReplayKit
bundle "$build/port.app" $renames "$appledir/ReplayKit/"*.m

differs=0
crashed=0
compare() {
    # compare <case>
    n=$1
    set +e
    DIFF_CASE=$n "$build/host.app/Contents/MacOS/app" > "$build/host.$n.out" 2>/dev/null; hs=$?
    DIFF_CASE=$n "$build/port.app/Contents/MacOS/app" > "$build/port.$n.out" 2>/dev/null; ps=$?
    set -e
    if [ "$hs" -ge 128 ]; then
        crashed=$((crashed + 1))
        echo "case $n: HOST CRASHED (signal $((hs - 128))), not comparable; port exit $ps: $(tail -1 "$build/port.$n.out")"
        return
    fi
    if [ "$ps" -ne 0 ] || [ "$hs" -ne 0 ]; then
        differs=$((differs + 1))
        echo "case $n: DIFFERS: host exit $hs, port exit $ps"
        return
    fi
    if cmp -s "$build/host.$n.out" "$build/port.$n.out"; then
        echo "case $n: EQUAL"
    elif [ "$(echo " $known " | grep -c " $n ")" -eq 1 ]; then
        echo "case $n: KNOWN difference, not counted"
        diff "$build/host.$n.out" "$build/port.$n.out" | sed 's/^/    /' || true
    else
        differs=$((differs + 1))
        echo "case $n: DIFFERS"
        diff "$build/host.$n.out" "$build/port.$n.out" | sed 's/^/    /' || true
    fi
}

echo "--- the clean run"
for n in $cases; do compare "$n"; done

# A plant is a copy of the port's sources with one line changed, and the case that measures that line must differ from the
# host. The copy holds every file, so the mutant builds as the port does.
plant() {
    # plant <case> <file> <sed-expression> <label>
    n=$1; file=$2; expr=$3; label=$4
    rm -rf "$build/mutant" "$build/mutant.app"
    mkdir -p "$build/mutant"
    # The sources include the log-once header as ../RevenantSayOnce.h, so the copy keeps it one level above them.
    cp "$appledir/RevenantSayOnce.h" "$build/RevenantSayOnce.h"
    cp "$appledir/ReplayKit/"*.m "$build/mutant/"
    sed "$expr" "$appledir/ReplayKit/$file" > "$build/mutant/$file"
    if cmp -s "$appledir/ReplayKit/$file" "$build/mutant/$file"; then
        echo "MUTATION DID NOT APPLY: $label"
        differs=$((differs + 1000))
        return
    fi
    bundle "$build/mutant.app" $renames "$build/mutant/"*.m
    set +e
    DIFF_CASE=$n "$build/mutant.app/Contents/MacOS/app" > "$build/mutant.$n.out" 2>/dev/null
    set -e
    if cmp -s "$build/host.$n.out" "$build/mutant.$n.out"; then
        echo "MUTANT SURVIVED: $label"
        differs=$((differs + 1000))
    else
        echo "  caught: $label"
    fi
}

echo "--- the plants"
plant controller RPBroadcastController.m 's/RPRecordingErrorAttemptToStopNonRecording/RPRecordingErrorUnknown/' \
    "finishing a broadcast that never started answers -5800 instead of -5829"
plant activity-nil RPBroadcastActivityViewController.m 's/initWithNibName:nil bundle:nil], nil);/initWithNibName:nil bundle:nil], [NSError errorWithDomain:RPRecordingErrorDomain code:RPRecordingErrorUnknown userInfo:nil]);/' \
    "the activity controller's load answers an error"
plant picker RPSystemBroadcastPickerView.m 's/_showsMicrophoneButton = YES;/_showsMicrophoneButton = NO;/' \
    "the picker's microphone choice defaults to NO"
plant recorder RPScreenRecorder.m 's/RPRecordingErrorAttemptToStopNonRecording/RPRecordingErrorUnknown/' \
    "stopping a recording that never started answers -5800 instead of -5829"
plant recorder RPScreenRecorder.m 's/^    handler(nil, error);$/    dispatch_async(dispatch_get_main_queue(), ^{ handler(nil, error); });/' \
    "the stop answers after the call returns, not before it"

echo "--- verdict: $differs difference(s) among comparable cases, $crashed host crash(es) not comparable"
[ "$differs" -eq 0 ]
