#!/bin/sh
# The host oracle for the sampler's three parameters, and the port's own three against it.
#
# Part one: what the host's AVAudioUnitSampler holds. The release names kAUSamplerParam_Gain 900,
# _CoarseTuning 901, _FineTuning 902 and _Pan 903 in AudioUnitParameters.h and gives no range for
# any of them, so the range is read from the v2 property kAudioUnitProperty_ParameterInfo with the
# parameter id as the element - the same path the port's parameter tree walks. There is no
# AudioUnitGetParameterInfo on the SDK.
#
# Part two: the port's accessors against the host's, compared as the AU parameter the release itself
# renders from, not as the property's value twice. The port's classes are compiled with their names
# renamed so they sit beside Apple's in one binary, the way the phase oracle does it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
AVFAUDIO="$root/packages/a/apple-backports/AVFAudio"
AVFOUNDATION="$root/packages/a/apple-backports/AVFoundation"
build=${AVFAUDIO_SAMPLER_BUILD:-$(runs_folder revenant-avfaudio-sampler)}
rm -rf "$build"
mkdir -p "$build"

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/sampler.m" \
    -framework Foundation -framework AVFAudio -framework AudioToolbox -o "$build/sampler" 2> "$build/sampler.err" || {
        echo "FAIL building the host oracle"; head -8 "$build/sampler.err"; exit 1; }
"$build/sampler"

# Every class the port's sampler and its whole superline define, renamed. The chain is
# sampler -> MIDI instrument -> generator -> effect -> unit -> node, and the unit's parameter tree and bus
# classes, because the sampler's initialiser goes through all of them.
renames="-DAVAudioUnitSampler=revenant_host_AVAudioUnitSampler
-DCHaronAudioComponentCount=revenant_host_CHaronAudioComponentCount"
# the iOS spelling of the mixer's bus-enable parameter; the macOS SDK this harness builds
# against has only the newer name, and the headers renamed the other way
renames="$renames -Dk3DMixerParam_Enable=k3DMixerParam_BusEnable"
for name in AVAudioUnitSampler AVAudioUnitMIDIInstrument AVAudioUnitGenerator AVAudioUnitEffect \
            AVAudioUnitTimeEffect AVAudioUnitDelay AVAudioUnitVarispeed AVAudioUnitTimePitch \
            AVAudioUnitDistortion AVAudioUnitReverb AVAudioUnitEQ AVAudioUnit AUAudioUnit \
            AUAudioUnitBus AUAudioUnitBusArray AUAudioUnitPreset AUParameter AUParameterGroup \
            AUParameterNode AUParameterTree AVAudioNode AVAudioFormat AVAudioPCMBuffer RevenantAudioBuffer; do
    renames="$renames -D$name=revenant_host_$name"
done

objects=""
for source in "$AVFAUDIO"/AVAudioUnitSampler8.m "$AVFAUDIO"/AVAudioUnitMIDIInstrument8.m \
              "$AVFAUDIO"/AVAudioUnitSubclasses8.m "$AVFAUDIO"/AVAudioUnitMixing9.m \
              "$AVFAUDIO"/AUAudioUnitBus9.m "$AVFAUDIO"/AUAudioUnit9.m "$AVFAUDIO"/AUParameter9.m \
              "$AVFAUDIO"/AUParameters9.m "$AVFAUDIO"/AUParameters10.m \
              "$AVFAUDIO"/RevenantAUAudioUnitRender.m "$AVFAUDIO"/RevenantAVFAudioCommon.m \
              "$AVFAUDIO"/AVAudioTime8.m "$AVFOUNDATION"/AVAudioNode.m "$AVFOUNDATION"/AVAudioBuffer8.m \
              "$AVFOUNDATION"/AVAudioFormat8.m "$AVFOUNDATION"/AVAudioConnectionPoint.m \
              "$AVFOUNDATION"/AVAudioPlayerNode.m "$AVFOUNDATION"/AVAudioUnit.m; do
    if [ ! -f "$source" ]; then
        echo "missing $source" >&2
        exit 1
    fi
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -w $renames -I"$AVFAUDIO" -I"$AVFOUNDATION" -I"$root/modules" \
        -c "$source" -o "$build/$(basename "$source").o" 2> "$build/$(basename "$source").err" || {
            echo "FAIL compiling $(basename "$source")"; head -6 "$build/$(basename "$source").err"; exit 1; }
    objects="$objects $build/$(basename "$source").o"
done

# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/sampler-params.m" $objects \
    -framework Foundation -framework AVFAudio -framework AudioToolbox -o "$build/params" 2> "$build/params.err" || {
        echo "FAIL building the parameter differential"; head -8 "$build/params.err"; exit 1; }
"$build/params"
