#!/bin/sh
# sources.sh <the AVFAudio folder> — the port-side half of the avfaudio host check. What only the port
# can get wrong, read out of its own source: a narrow read of a property the header types as Float64,
# a member answered with a value the unit is not told, a fallback that substitutes another component,
# a magic sentinel where a legal value lives, and a blanket warning suppression.
set -eu
AVFAUDIO=${1:-.}
checks=0
failures=0
check() {
    checks=$((checks + 1))
    if [ "$2" = yes ]; then printf 'ok %s\n' "$1"; else failures=$((failures + 1)); printf 'FAIL %s\n' "$1"; fi
}

# kAudioUnitProperty_Latency and kAudioUnitProperty_TailTime are Float64 by the header's own Value Type.
# A Float32 local beside either name is the finding, and the host oracle measures what it costs: a unit
# whose tail time is 0.001 s reads back as -5.18969491e+11.
# The bug is a *narrow local declared for a Float64 property*: the declaration and the property name
# are on different lines, so the shape to look for is the local itself, not a line mentioning both.
narrow=$(grep -hE "Float32[[:space:]]+(tail|latency|inLatency|busLatency)[[:space:]]*=" "$AVFAUDIO/AUAudioUnit9.m" "$AVFAUDIO/AUAudioUnitBus9.m" | grep -c "Float32" || true)
check "no Float32 local is declared for the Latency or TailTime read" \
      "$([ "$narrow" -eq 0 ] && echo yes || echo no)"

# Every latency/tailTime local must be a Float64.
wide=$(grep -h "Float64" "$AVFAUDIO/AUAudioUnit9.m" "$AVFAUDIO/AUAudioUnitBus9.m" | grep -c "Float64" || true)
check "latency and tailTime are read as Float64 (found $wide declarations)" \
      "$([ "$wide" -ge 4 ] && echo yes || echo no)"

# A description the release does not have must fail. The fallback is the finding.
fallback=$(grep -c "AudioComponentDescription any = {0, 0, 0}" "$AVFAUDIO/AUAudioUnit9.m" || true)
check "a description that names no component is not replaced by another one" \
      "$([ "$fallback" -eq 0 ] && echo yes || echo no)"

# The four members the header names a v2 property for must call that property.
for pair in "ParametersForOverview:parametersForOverviewWithCount" \
            "SupportedNumChannels:channelCapabilities" \
            "BypassEffect:shouldBypassEffect"; do
    property=${pair%%:*}; member=${pair##*:}
    hits=$(grep -c "$property" "$AVFAUDIO/AUAudioUnit9.m" || true)
    check "$member reads kAudioUnitProperty_$property" \
          "$([ "$hits" -ge 1 ] && echo yes || echo no)"
done
hits=$(grep -c "SupportedChannelLayoutTags" "$AVFAUDIO/AUAudioUnitBus9.m" || true)
check "AUAudioUnitBus.supportedChannelLayoutTags reads kAudioUnitProperty_SupportedChannelLayoutTags" \
      "$([ "$hits" -ge 1 ] && echo yes || echo no)"

# The render path may not allocate, and every observer is called. Both are read out of the render
# method alone: a block copied into an ivar off the render thread is ordinary, a copy inside a
# comment is a comment, and the break in -removeRenderObserver: is where a break belongs.
# the comment inside the method explains the very rule this checks, so comments are stripped first
render=$(sed -n '/- (OSStatus)charon_renderWithActionFlags:/,/^}/p' "$AVFAUDIO/AUAudioUnit9.m" | grep -vE '^[[:space:]]*(//|\*|/)')
copy=$(printf '%s' "$render" | grep -c "copy\]" || true)
check "the render method takes no copy of the observer list" \
      "$([ "$copy" -eq 0 ] && echo yes || echo no)"
breaks=$(printf '%s' "$render" | grep -c "break;" || true)
check "the render method calls every observer rather than breaking after the first" \
      "$([ "$breaks" -eq 0 ] && echo yes || echo no)"

# A magic sentinel where a legal value lives: kDelayParam_Feedback and kTimePitchParam_Pitch both
# take -1 inside their documented range, so "-1 means unset" is a value the host can set.
sentinel=$(grep -c "= -1;" "$AVFAUDIO/AVAudioUnitSubclasses8.m" || true)
check "no parameter is kept as -1 to mean 'not set'" "$([ "$sentinel" -eq 0 ] && echo yes || echo no)"

# A blanket suppression of the warning class that would report a missing protocol member.
pragma=$(grep -h "pragma clang diagnostic ignored" "$AVFAUDIO"/*.m \
    | grep -cE '"-Wobjc-protocol-property-synthesis"|"-Wprotocol"' || true)
check "no file suppresses -Wobjc-protocol-property-synthesis or -Wprotocol wholesale" \
      "$([ "$pragma" -eq 0 ] && echo yes || echo no)"

# The number of AUChannelInfo entries a unit holds is the property's own size over the size of one
# entry - the header says "The size of this property will represent the number of AUChannelInfo
# structs that an audio unit provides" - so the count must be derived from the size the unit
# answered and not written down. A forced count is unobservable through the port's answer, because
# the port returns the first entry's two numbers and a one-entry property makes any count read the
# same: the reviewer's "entries = 2" left every output check green. So this is held where it can be
# held, which is the derivation itself.
body=$(sed -n '/- (NSArray<NSNumber \*> \*)channelCapabilities/,/^}/p' "$AVFAUDIO/AUAudioUnit9.m")
derived=$(printf '%s' "$body" | grep -c "size / (UInt32)sizeof(AUChannelInfo)" || true)
check "the channel pair's entry count is the property size over sizeof(AUChannelInfo)" \
      "$([ "$derived" -ge 1 ] && echo yes || echo no)"
literal=$(printf '%s' "$body" | grep -cE "entries[[:space:]]*=[[:space:]]*[0-9]+" || true)
check "no literal entry count is written over the property's size" \
      "$([ "$literal" -eq 0 ] && echo yes || echo no)"

printf 'checks=%d failures=%d\n' "$checks" "$failures"
[ "$failures" -eq 0 ]
