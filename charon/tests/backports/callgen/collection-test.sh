#!/bin/sh
# collection-test.sh - the resolution results' collection factories against the host's measured
# answer, and a mutation that shows the count table goes red.
#
# The host is the oracle and it is the host's own Intents.framework, not this port: the five
# +successesWithResolved…: factories are built into a Catalyst-style macOS binary against the
# system's Intents, and the port's own body is built into a port library and read back the same
# way. The table is printed for both, and for a mutant of the port's body that returns one element
# fewer, so the counts can be put side by side and the red is visible rather than argued about.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
root=$(cd "$here/../../.." && pwd)
build=${BUILD:-$(runs_fresh charon-callgen)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)

# 1. the host's own answer, for the five classes it carries.
xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O0 -w \
    "$here/collection-host.m" -framework Foundation -framework Intents -o "$build/host" \
    2>"$build/host-build.log" || { echo "the host probe did not build" >&2; tail -10 "$build/host-build.log" >&2; exit 1; }
"$build/host" "the host's own Intents"

# 2. the port's own body, and 3. the mutant, both read out of the built library.
python3 "$here/collection-mutant.py" "$root/packages/a/apple-backports/Intents/IN16_0.m" \
    "$build/IN16_0.mutant.m" >/dev/null
# IN12_0.m is compiled too: it is where the port's own INMediaItem is implemented, and the
# factories take one.
for half in real mutant; do
    source="$root/packages/a/apple-backports/Intents/IN16_0.m"
    [ "$half" = mutant ] && source="$build/IN16_0.mutant.m"
    printf '%s\n' "=== $half"
    xcrun clang -target armv7-apple-ios6.1.3 \
        -isysroot "$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/iPhoneOS16.4.sdk | head -1)" \
        -fobjc-arc -O0 -w -I"$root/packages/c/charon-coding/files" \
        -I"$root/packages/a/apple-backports/Intents" -c "$source" \
        -o "$build/IN16_0.$half.o" 2>>"$build/build.log" || {
            echo "the $half half did not compile" >&2; tail -10 "$build/build.log" >&2; exit 1; }
    xcrun clang -target arm64-apple-macos26.0 -isysroot "$sdk" -fobjc-arc -O0 -w \
        "$here/collection-test.m" "$build/IN16_0.$half.o" \
        -framework Foundation -framework Intents -o "$build/$half" 2>>"$build/build.log" || {
            echo "the $half runner did not build" >&2; tail -10 "$build/build.log" >&2; exit 1; }
    "$build/$half" "the port's own body ($half)" CharonPortMediaItemResolutionResult CharonPortMediaItem
done

# The port's own half is built for macOS out of two generated object files, and one of them
# includes CharonIntents262.h - the transcription of the nine names the port's own SDK has not - and
# macOS 26's Intents.framework now declares some of those names itself, so that translation unit
# cannot be compiled for the host at all. That is why this test's port side is a separate run on the
# port, and why a host-only table is the host's own twice over.
#
# The mutation exists to make the table go red, so an identical pair of tables is a failure and not
# a pass: it would mean the two halves are the same code, or the class the test asked for is not the
# one that was built.
"$build/real" counts CharonPortMediaItemResolutionResult CharonPortMediaItem > "$build/real.counts"
"$build/mutant" counts CharonPortMediaItemResolutionResult CharonPortMediaItem > "$build/mutant.counts"
if cmp -s "$build/real.counts" "$build/mutant.counts"; then
    echo "FAIL: the mutation did not change the count table, so the two halves are the same code"
    diff "$build/real.counts" "$build/mutant.counts" || true
    exit 1
fi
echo "the mutation turns the table red - the two halves differ:"
diff "$build/real.counts" "$build/mutant.counts" || true
