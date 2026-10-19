#!/bin/sh
# run.sh -- AVSpeechUtterance and its three rate constants, the port against the host, in one binary; then
# AVSpeechSynthesisVoice (voice-checks.m) in a second binary, in four locale variants.
#
# The port's objects (AVFoundation/AVSpeechUtterance7.m, AVFoundation/AVSpeechConstants7.m, and for the voice
# AVFoundation/AVSpeechSynthesisVoice7.m) are compiled with every name they define renamed to a revenant_host_ spelling,
# and linked beside the checks, which ask the host's own class and the port's the same questions in one process.
#
# Controls keep the checks honest:
#   * checks.m's first line asks the host for its default rate; a probe that is not reading the host fails there;
#   * AVSPEECH_MUTANT=pitch plants a wrong floor for pitchMultiplier in a COPY of the port source and the run
#     must go red. A plant that goes green means the check cannot see the thing it claims to see.
#   * voice-checks.m's first lines ask the host for its current language, which run.sh sets per variant;
#   * AVSPEECH_VOICE_MUTANT=identifier plants a wrong identifier for one voice in a COPY, and the voice run must go red.
#   * AVSPEECH_LATER_MUTANT=audio-session plants YES as the default of usesApplicationAudioSession in a COPY of the iOS 13
#     category, and the synthesizer run must go red.
# The host has no VoiceServices framework, so the voice's listing is a stub in voice-checks.m; run.sh checks the stub
# against the 6.1.3 probe's listing (voices/listing-6.1.3.txt) before it builds anything.
#
# Run directly, not through heavy.sh: two small compiles and one run.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/a/apple-backports/AVFoundation
build=$(runs_folder revenant-avf-speech)
rm -rf "$build"
mkdir -p "$build/src"

cp "$avf/AVSpeechUtterance7.m" "$avf/AVSpeechConstants7.m" "$build/src/"
mutant=${AVSPEECH_MUTANT:-0}
if [ "$mutant" = pitch ]; then
    sed -i '' 's/pitchMultiplier >= 0.5f) ? pitchMultiplier : 0.5f/pitchMultiplier >= 0.25f) ? pitchMultiplier : 0.25f/' "$build/src/AVSpeechUtterance7.m"
    [ "$(grep -c '0.25f' "$build/src/AVSpeechUtterance7.m")" -eq 1 ] || { echo "FAIL: the planted pitch floor did not apply"; exit 1; }
    echo "planted: pitchMultiplier floor 0.25 in the copy (control: must go red)"
fi

renames="-DAVSpeechUtterance=revenant_host_AVSpeechUtterance
-DAVSpeechUtteranceMinimumSpeechRate=revenant_host_AVSpeechUtteranceMinimumSpeechRate
-DAVSpeechUtteranceMaximumSpeechRate=revenant_host_AVSpeechUtteranceMaximumSpeechRate
-DAVSpeechUtteranceDefaultSpeechRate=revenant_host_AVSpeechUtteranceDefaultSpeechRate"
# shellcheck disable=SC2086
for source in AVSpeechUtterance7.m AVSpeechConstants7.m; do
    xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations $renames -I"$avf" \
        -c "$build/src/$source" -o "$build/${source%.m}.o" 2> "$build/$source.err" || {
            echo "FAIL compiling the port's $source"; head -6 "$build/$source.err"; exit 1; }
done

xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/checks.m" \
    "$build/AVSpeechUtterance7.o" "$build/AVSpeechConstants7.o" \
    -framework Foundation -framework AVFAudio -o "$build/avf-speech" 2> "$build/link.err" || {
        echo "FAIL linking the differential"; head -10 "$build/link.err"; exit 1; }

set +e
"$build/avf-speech" > "$build/log" 2>&1
result=$?
set -e
grep -v '^ok ' "$build/log" || true
grep -q '^checks=' "$build/log" || { echo "FAIL: the run printed no checks= line, so nothing was checked"; exit 1; }
echo "log=$build/log"

# AVSpeechSynthesisVoice (voice-checks.m). The host has no VoiceServices, so the port's listing source is the stub in
# voice-checks.m; that stub must hold the 6.1.3 probe's listing (voices/listing-6.1.3.txt) pair for pair.
voices=$here/voices
awk '/^probe: code /{code=$3; getline; n=$0; gsub(/[ "]/,"",n); print code, n}' "$voices/listing-6.1.3.txt" | sort > "$build/listing-pairs"
grep -oE '@"[a-z]{2}-[A-Z]{2}": @"[^"]+"' "$here/voice-checks.m" | sed -E 's/@"([^"]+)": @"([^"]+)"/\1 \2/' | sort > "$build/stub-pairs"
[ "$(wc -l < "$build/listing-pairs")" -eq 36 ] || { echo "FAIL: the 6.1.3 listing file does not hold 36 code lines"; exit 1; }
cmp -s "$build/listing-pairs" "$build/stub-pairs" || { echo "FAIL: the stub in voice-checks.m is not the 6.1.3 listing"; diff "$build/listing-pairs" "$build/stub-pairs" | head -6; exit 1; }

cp "$avf/AVSpeechSynthesisVoice7.m" "$build/src/"
vmutant=${AVSPEECH_VOICE_MUTANT:-0}
if [ "$vmutant" = identifier ]; then
    sed -i '' 's/@"com.apple.voice.compact.en-US.Samantha"/@"com.apple.voice.super-compact.en-US.Samantha"/' "$build/src/AVSpeechSynthesisVoice7.m"
    [ "$(grep -c 'super-compact.en-US.Samantha' "$build/src/AVSpeechSynthesisVoice7.m")" -eq 1 ] || { echo "FAIL: the planted identifier did not apply"; exit 1; }
    echo "planted: Samantha's identifier in the copy is the super-compact one (control: must go red)"
fi
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -DAVSpeechSynthesisVoice=revenant_host_AVSpeechSynthesisVoice \
    -I"$avf" -c "$build/src/AVSpeechSynthesisVoice7.m" -o "$build/AVSpeechSynthesisVoice7.o" 2> "$build/voice.err" || {
        echo "FAIL compiling the port's AVSpeechSynthesisVoice7.m"; head -6 "$build/voice.err"; exit 1; }
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/voice-checks.m" "$build/AVSpeechSynthesisVoice7.o" \
    -framework Foundation -framework AVFAudio -o "$build/avf-speech-voices" 2> "$build/voice-link.err" || {
        echo "FAIL linking the voice differential"; head -10 "$build/voice-link.err"; exit 1; }

# One run per locale variant: argv[1] is the host's current language code for that variant, the rest are the
# preferred-language arguments the host reads at start-up (the setting is the variant's, not the machine's).
set +e
"$build/avf-speech-voices" en-US > "$build/voice-en-US.log" 2>&1; v1=$?
"$build/avf-speech-voices" fr-FR -AppleLanguages "(fr-FR)" > "$build/voice-fr-FR.log" 2>&1; v2=$?
"$build/avf-speech-voices" cmn-CN -AppleLanguages "(zh-Hans-CN)" > "$build/voice-zh-Hans-CN.log" 2>&1; v3=$?
"$build/avf-speech-voices" ar-001 -AppleLanguages "(ar-SA)" > "$build/voice-ar-SA.log" 2>&1; v4=$?
set -e
for log in "$build"/voice-*.log; do
    grep -v '^ok ' "$log" || true
    grep -q '^checks=' "$log" || { echo "FAIL: $log printed no checks= line, so nothing was checked"; exit 1; }
done
echo "voice-logs=$build/voice-*.log"

# AVSpeechSynthesizer (synth-checks.m): the port's queue, flags and delegate order, driven through a stub
# VSSpeechSynthesizer in the binary, against the host's own class. The port's synthesizer is compiled with its names
# renamed, beside the utterance and the voice objects it links (both renamed above).
cp "$avf/AVSpeechSynthesizer7.m" "$build/src/"
smutant=${AVSPEECH_SYNTH_MUTANT:-0}
if [ "$smutant" = cancel ]; then
    sed -i '' 's/for (AVSpeechUtterance \*utterance in cancelled) {/for (AVSpeechUtterance *utterance in [cancelled subarrayWithRange:NSMakeRange(0, 1)]) {/' "$build/src/AVSpeechSynthesizer7.m"
    [ "$(grep -c 'subarrayWithRange' "$build/src/AVSpeechSynthesizer7.m")" -eq 1 ] || { echo "FAIL: the planted cancel did not apply"; exit 1; }
    echo "planted: a stop cancels only the head in the copy (control: must go red)"
fi
# The two later properties (AVSpeechSynthesizer10.m, AVSpeechSynthesizer13.m) are categories on the same class. The
# planted control makes the copy of the iOS 13 default YES (the header's default); the host answers NO, so the run must go red.
cp "$avf/AVSpeechSynthesizer10.m" "$avf/AVSpeechSynthesizer13.m" "$build/src/"
later=${AVSPEECH_LATER_MUTANT:-0}
if [ "$later" = audio-session ]; then
    sed -i '' 's/uses ? uses.boolValue : NO;/uses ? uses.boolValue : YES;/' "$build/src/AVSpeechSynthesizer13.m"
    [ "$(grep -c 'uses.boolValue : YES;' "$build/src/AVSpeechSynthesizer13.m")" -eq 1 ] || { echo "FAIL: the planted default did not apply"; exit 1; }
    echo "planted: usesApplicationAudioSession defaults to YES in the copy (control: must go red)"
fi
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations $renames \
    -DAVSpeechSynthesisVoice=revenant_host_AVSpeechSynthesisVoice -DAVSpeechSynthesizer=revenant_host_AVSpeechSynthesizer \
    -I"$avf" -c "$build/src/AVSpeechSynthesizer7.m" -o "$build/AVSpeechSynthesizer7.o" 2> "$build/synth.err" || {
        echo "FAIL compiling the port's AVSpeechSynthesizer7.m"; head -6 "$build/synth.err"; exit 1; }
for source in AVSpeechSynthesizer10.m AVSpeechSynthesizer13.m; do
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations $renames \
        -DAVSpeechSynthesisVoice=revenant_host_AVSpeechSynthesisVoice -DAVSpeechSynthesizer=revenant_host_AVSpeechSynthesizer \
        -I"$avf" -c "$build/src/$source" -o "$build/${source%.m}.o" 2> "$build/$source.err" || {
            echo "FAIL compiling the port's $source"; head -6 "$build/$source.err"; exit 1; }
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/synth-checks.m" \
    "$build/AVSpeechUtterance7.o" "$build/AVSpeechConstants7.o" "$build/AVSpeechSynthesisVoice7.o" "$build/AVSpeechSynthesizer7.o" \
    "$build/AVSpeechSynthesizer10.o" "$build/AVSpeechSynthesizer13.o" \
    -framework Foundation -framework AVFAudio -o "$build/avf-speech-synth" 2> "$build/synth-link.err" || {
        echo "FAIL linking the synthesizer differential"; head -10 "$build/synth-link.err"; exit 1; }
set +e
"$build/avf-speech-synth" > "$build/synth.log" 2>&1; sresult=$?
set -e
grep -v '^ok ' "$build/synth.log" || true
grep -q '^checks=' "$build/synth.log" || { echo "FAIL: the synthesizer run printed no checks= line, so nothing was checked"; exit 1; }
echo "synth-log=$build/synth.log"

[ "$result" -eq 0 ] || exit "$result"
[ "$sresult" -eq 0 ] || exit "$sresult"
[ "$v1$v2$v3$v4" = 0000 ] || { echo "FAIL: a voice variant went red"; exit 1; }
exit 0
