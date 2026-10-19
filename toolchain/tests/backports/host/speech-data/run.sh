#!/bin/sh
# run.sh - the port's iOS 10 Speech data classes (requests, result, transcription, segment) against the host's own Speech,
# case by case, in two processes.
#
#   1. differential.m is COMPILED against the host's Speech (a bare macOS tool) and run once per case
#   2. the same source is COMPILED against the port's Speech sources and run once per case
#   3. the two outputs of each case are compared; a case where the host dies on a signal is named as such and is not
#      counted as agreement
#   3a. case 12, where the host always dies, is checked on the port side against the coordinator's decision instead
#   4. a plant on a scratch copy of the port's sources - one answer changed, each in the case that measures it - must turn
#      that case red
#
# Two processes, not one, because both sides define the same classes. No recognizer is created or started in any case.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/generated.sh"
ensure_generated "$here" Speech
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$here/../../../../.agent-work/runs/speech-data}
mkdir -p "$build"
cases="1 2 3 4 5 6 7 8 9 10 12 13 14"

# The port's sources, every class of the folder given, and the generated constants (SFSpeechErrorDomain, from
# spec/Speech/constants.tsv), and nothing of the host's Speech: the port side does not link it.
gen="$appledir/.gen/Speech/SpeechConstants17.m"
[ -f "$gen" ] || { echo "no $gen: generate it first (xmake l tools/gen.lua gen)"; exit 1; }
port_build() {
    # port_build <source-dir> <output>
    xcrun clang -fobjc-arc -w -DPORT -framework Foundation -framework AVFoundation \
        "$here/differential.m" "$1/"*.m "$gen" -o "$2"
}

xcrun clang -fobjc-arc -w -framework Foundation -framework AVFoundation -framework Speech \
    "$here/differential.m" -o "$build/host"
port_build "$appledir/Speech" "$build/port"

differs=0
crashed=0
compare() {
    # compare <label> <port-binary> <case...>
    label=$1; port=$2; shift 2
    for n in "$@"; do
        set +e
        "$build/host" "$n" > "$build/host.$n.out" 2>/dev/null; hs=$?
        "$port" "$n" > "$build/port.$n.out" 2>/dev/null; ps=$?
        set -e
        if [ "$hs" -ge 128 ]; then
            crashed=$((crashed + 1))
            echo "case $n: HOST CRASHED (signal $((hs - 128))), not comparable; port exit $ps"
            continue
        fi
        if [ "$ps" -ne 0 ] || [ "$hs" -ne 0 ]; then
            differs=$((differs + 1))
            echo "case $n: DIFFERS ($label): host exit $hs, port exit $ps"
            continue
        fi
        if cmp -s "$build/host.$n.out" "$build/port.$n.out"; then
            echo "case $n: EQUAL"
        else
            differs=$((differs + 1))
            echo "case $n: DIFFERS ($label)"
            diff "$build/host.$n.out" "$build/port.$n.out" | sed 's/^/    /' || true
        fi
    done
}

echo "--- the clean run"
compare clean "$build/port" $cases

# Case 12 has no host answer: the host ends the process. The port's lines are checked against the coordinator's decision
# (facts/Speech/recognizer.md): the handler runs once, off the main thread, with Restricted (2), and the status reads
# Restricted after the request.
decision12() {
    # decision12 <label> <output>
    printf 'returned from requestAuthorization\nhandler calls=1 status=2 main=0\nstatus after=2\n' > "$build/decision.12.out"
    if cmp -s "$build/decision.12.out" "$2"; then
        echo "case 12: port answers the decision ($1)"
        return 0
    fi
    echo "case 12: port DIFFERS from the decision ($1)"
    diff "$build/decision.12.out" "$2" | sed 's/^/    /' || true
    return 1
}
decision12 clean "$build/port.12.out" || differs=$((differs + 1))

# A plant is a copy of the port's sources with one line changed, and the case that measures that line must differ. The copy
# is a directory of its own holding every file, so a harness that copied only the changed one would fail to build rather
# than measure nothing.
plant() {
    # plant <case> <file> <sed-expression> <label>
    n=$1; file=$2; expr=$3; label=$4
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$appledir/Speech/"*.m "$build/mutant/"
    sed "$expr" "$appledir/Speech/$file" > "$build/mutant/$file"
    if cmp -s "$appledir/Speech/$file" "$build/mutant/$file"; then
        echo "MUTATION DID NOT APPLY: $label"
        differs=$((differs + 1000))
        return
    fi
    port_build "$build/mutant" "$build/port-mutant"
    set +e
    "$build/port-mutant" "$n" > "$build/port-mutant.$n.out" 2>/dev/null
    set -e
    # Case 12 is measured against the decision, the host having no answer there.
    ref="$build/host.$n.out"; [ "$n" = 12 ] && ref="$build/decision.12.out"
    if cmp -s "$ref" "$build/port-mutant.$n.out"; then
        echo "MUTANT SURVIVED: $label"
        differs=$((differs + 1000))
    else
        echo "  caught: $label"
    fi
}

echo "--- the plants"
plant 1 SFSpeechRecognitionRequest.m 's/        _shouldReportPartialResults = YES;/        _shouldReportPartialResults = NO;/' "request default shouldReportPartialResults YES flipped to NO"
plant 2 SFSpeechAudioBufferRecognitionRequest.m 's/AVAudioPCMFormatInt16/AVAudioPCMFormatFloat32/' "buffer request native format Int16 flipped to Float32"
plant 6 SFTranscriptionSegment.m 's/    copy->_confidence = _confidence;/    copy->_confidence = 1;/' "segment copy loses the confidence"
plant 8 SFSpeechRecognizer.m 's/    return SFSpeechRecognizerAuthorizationStatusNotDetermined;/    return SFSpeechRecognizerAuthorizationStatusAuthorized;/' "authorization status NotDetermined flipped to Authorized"
plant 10 SFSpeechRecognizer.m 's/    return nil;/    return self;/' "recognizer for an unsupported locale made instead of nil"
plant 13 SFSpeechRecognitionTask.m '/isCancelled/,/^}/ s/return NO;/return YES;/' "fresh task reported cancelled"
plant 12 SFSpeechRecognizer.m 's/        handler(SFSpeechRecognizerAuthorizationStatusRestricted);/        handler(SFSpeechRecognizerAuthorizationStatusAuthorized);/' \
    "authorization handler answers Authorized instead of Restricted"

echo "--- verdict: $differs difference(s) among comparable cases, $crashed host crash(es) not comparable"
[ "$differs" -eq 0 ]
