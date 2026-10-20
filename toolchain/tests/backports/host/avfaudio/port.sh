#!/bin/sh
# port.sh — the port-versus-host half of the avfaudio check.
#
# The host half (checks.m) asks Apple's own classes. This one puts **the port's own classes in the
# same binary** and holds both to the same inputs, which is what the round-3 review measured as
# missing: with only checks.m, a mutation of the port's channelCapabilities left the harness green,
# because the harness never called the port.
#
# The mechanism is the repository's own (accelerate7, animatorscrub, appgroup): the port's sources
# are compiled with the class names they define renamed, so the port's AUAudioUnit is literally
# revenant_host_AUAudioUnit and sits beside Apple's in one binary. The rename list is written out
# rather than derived, and it names every class in the compiled subset and nothing else: a derived
# list spans the whole AVFoundation folder, renames classes this binary does not compile, and turns
# a class the port *uses from the host* into one it does not have.
#
# The subset is the audio unit family and the node it hangs off. The port's sources compile against
# the host frameworks, so nothing about this is out of reach.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=${AVFAUDIO_ROOT:-$(cd "$here/../../../.." && pwd)}
AVFAUDIO="$root/packages/frameworks/apple-backports/AVFAudio"
AVFOUNDATION="$root/packages/frameworks/apple-backports/AVFoundation"
build=${AVFAUDIO_PORT_BUILD:-$(runs_folder revenant-avfaudio-port)}
rm -rf "$build"
mkdir -p "$build"

# Every class the compiled subset defines. If a source below grows a class, it is added here with
# the rest: a class left out collides with Apple's at link, which is a failure the link names.
renames="-DAUAudioUnit=revenant_host_AUAudioUnit
-DAUAudioUnitBus=revenant_host_AUAudioUnitBus
-DAUAudioUnitBusArray=revenant_host_AUAudioUnitBusArray
-DAUAudioUnitPreset=revenant_host_AUAudioUnitPreset
-DAUParameter=revenant_host_AUParameter
-DAUParameterGroup=revenant_host_AUParameterGroup
-DAUParameterNode=revenant_host_AUParameterNode
-DAUParameterTree=revenant_host_AUParameterTree
-DAVAudioChannelLayout=revenant_host_AVAudioChannelLayout
-DAVAudioConnectionPoint=revenant_host_AVAudioConnectionPoint
-DAVAudioFormat=revenant_host_AVAudioFormat
-DAVAudioMixingDestination=revenant_host_AVAudioMixingDestination
-DAVAudioNode=revenant_host_AVAudioNode
-DAVAudioPCMBuffer=revenant_host_AVAudioPCMBuffer
-DAVAudioPlayerNode=revenant_host_AVAudioPlayerNode
-DAVAudioTime=revenant_host_AVAudioTime
-DAVAudioIONode=revenant_host_AVAudioIONode
-DAVAudioInputNode=revenant_host_AVAudioInputNode
-DAVAudioMixerNode=revenant_host_AVAudioMixerNode
-DAVAudioOutputNode=revenant_host_AVAudioOutputNode
-DRevenantAudioBuffer=revenant_host_RevenantAudioBuffer
-DRevenantScheduledBuffer=revenant_host_RevenantScheduledBuffer
-DRevenantAUParameterImpl=revenant_host_RevenantAUParameterImpl"

# The one naming difference between the iOS SDK the port compiles against and the macOS SDK this
# harness builds with: the header declares k3DMixerParam_BusEnable the replacement for the iOS
# spelling k3DMixerParam_Enable, deprecated on macOS and kept on iOS. Same value, and the port's
# spelling is the right one for the release, so only this compile is renamed.
renames="$renames -Dk3DMixerParam_Enable=k3DMixerParam_BusEnable"

# AVAudioChannelLayout8.m is here for the -initWithLayout: cases in port.m, which ask the port's class and
# the host's the same question in this one binary.
objects=""
for source in \
    "$AVFAUDIO/AUAudioUnit9.m" \
    "$AVFAUDIO/AUAudioUnitBus9.m" \
    "$AVFAUDIO/AUParameter9.m" \
    "$AVFAUDIO/AUParameters9.m" \
    "$AVFAUDIO/AUParameters10.m" \
    "$AVFAUDIO/RevenantAUAudioUnitRender.m" \
    "$AVFAUDIO/RevenantAVFAudioCommon.m" \
    "$AVFAUDIO/AVAudioUnitMixing9.m" \
    "$AVFAUDIO/AVAudioTime8.m" \
    "$AVFAUDIO/AVAudioChannelLayout8.m" \
    "$AVFOUNDATION/AVAudioNode.m" \
    "$AVFOUNDATION/AVAudioFormat8.m" \
    "$AVFOUNDATION/AVAudioBuffer8.m" \
    "$AVFOUNDATION/AVAudioConnectionPoint.m" \
    "$AVFOUNDATION/AVAudioPlayerNode.m"
do
    [ -f "$source" ] || { echo "FAIL missing $source"; exit 1; }
    name=$(basename "$source")
    # no -fvisibility=hidden: it makes a renamed class symbol private to the object that defines it,
    # and ld64 then cannot resolve the category that references it. The renaming already keeps the
    # port's names apart from Apple's, which is what that flag would have been for.
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -I"$AVFAUDIO" -I"$AVFOUNDATION" -I"$root/modules" \
        -c "$source" -o "$build/$name.o" 2> "$build/$name.err" || {
            echo "FAIL compiling $name"; head -6 "$build/$name.err"; exit 1; }
    objects="$objects $build/$name.o"
done

# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$AVFAUDIO" -I"$AVFOUNDATION" \
    "$here/port.m" $objects \
    -framework Foundation -framework AudioToolbox -framework AVFAudio -framework CoreAudio -framework QuartzCore \
    -o "$build/port" 2> "$build/link.err" || { echo "FAIL linking"; head -10 "$build/link.err"; exit 1; }

"$build/port" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
