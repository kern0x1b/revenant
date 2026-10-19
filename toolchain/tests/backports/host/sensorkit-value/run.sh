#!/bin/sh
# run.sh - the five value-object members, held to what the host's own SensorKit answers and to what the
# compiled armv7 objects carry.
#
#   1. host-answers.m asks the HOST: both counts over all ten sentiment categories, both speech
#      properties, and what -[SRSensorReader init] does. host_answers.lua holds those answers to what the
#      SDK's own semantics require - zero, nil, and a raise - so a golden that has drifted is red
#   2. check_values.lua holds the PORT: each of the five is a store-backed accessor in the source, and its
#      selector is in the compiled armv7 object
#   3. four plants, each of which must turn step 2 red: a property reading a constant instead of the
#      store, a count reading a constant, a count that drops the category from its key, and an accessor
#      deleted outright
#   4. the check's own control: an object with none of the five selectors must not look green
#
# WHY THERE IS NO DIFFERENTIAL, and this is measured rather than assumed. SRKeyboardMetrics,
# SRSpeechMetrics and SRFaceMetrics are all API_UNAVAILABLE(macos) in the host's SDK, so a typed call
# cannot name them, and the port's RevenantSensorKit.h cannot be compiled against that SDK at all - clang
# answers "typedef redefinition with different types ('NSInteger' vs
# 'enum SRAcousticSettingsSampleLifetime')" for its fifteen redeclared enumerations. What the host
# answers is therefore measured once, in step 1, and the port is held to it; and the port's own half is
# held twice, in the source and in the object, because a source check alone would pass on a method the
# compiler never emitted and an object check alone would pass on one that returns a constant.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$(runs_fresh revenant-sensorkit-value)}
mkdir -p "$build"

cc=$(ls -d "$HOME"/.xmake/packages/l/llvm/*/*/bin/clang 2>/dev/null | head -1)
sdk=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/cccc080d0cbe42c2a85b1369aba6e290/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk 2>/dev/null | head -1)
if [ -z "$cc" ] || [ -z "$sdk" ]; then
    echo "FAIL no pinned toolchain: expected clang under \$HOME/.xmake/packages/l/llvm/*/*/bin and an"
    echo "     iPhoneOS 16.4 SDK under \$HOME/.xmake/packages/i/iphoneos-sdk/16.4/cccc080d0cbe42c2a85b1369aba6e290/ (tools/gen/project.lua names it). The object half of this"
    echo "     check did not run, and it is half of what the facts pages take from here."
    exit 1
fi
# The compiler's own diagnostics go to a file rather than to /dev/null: a compile that fails has to say
# why, and the caller only reports "did not build", which is not a diagnosis. An earlier version of this
# sent stderr to /dev/null and a mutant that failed to compile would have been reported as a harness
# problem rather than as a mutation that stopped applying.
armv7() {
    "$cc" -target armv7-apple-ios6.1.3 -isysroot "$sdk" \
        -I "$appledir" -I "$appledir/SensorKit" -fobjc-arc -c "$1" -o "$2" \
        > "$build/cc.log" 2>&1 || { echo "COMPILE FAILED for $1:"; cat "$build/cc.log"; return 1; }
}

src170=$appledir/SensorKit/SensorKit170.m
src150=$appledir/SensorKit/SensorKit150.m
armv7 "$src170" "$build/SensorKit170.o"
armv7 "$src150" "$build/SensorKit150.o"

echo "--- what the host's own SensorKit answers, and what that requires of the port"
xcrun clang -fobjc-arc -w "$here/host-answers.m" -framework Foundation -o "$build/host-answers"
"$build/host-answers" > "$build/host.out"
grep '^CONTROL' "$build/host.out" || { echo "FAIL the host reader printed no control line"; exit 1; }
xmake l "$here/host_answers.lua" "$build/host.out"

echo "--- what the port answers: the source, and the compiled armv7 objects"
xmake l "$here/check_values.lua" "$src170" "$src150" "$build/SensorKit170.o" "$build/SensorKit150.o"

survived=0
plant() {
    label=$1; which=$2; from=$3; to=$4
    rm -rf "$build/mutant"; mkdir -p "$build/mutant/SensorKit"
    # RevenantValueStore.h beside the mutated file, so its quoted #import resolves inside the mutant rather
    # than back to the port's own tree. No "|| true" here: a copy that does not happen is a plant that
    # would be measuring the unmutated header, and the earlier version of this line had
    # RevenantValueStore.m in it, which does not exist, so the failure was invisible by construction.
    cp "$appledir/RevenantValueStore.h" "$build/mutant/RevenantValueStore.h"
    cp "$appledir/SensorKit/RevenantSensorKit.h" "$build/mutant/RevenantSensorKit.h"
    cp "$src170" "$src150" "$build/mutant/SensorKit/"
    target=$build/mutant/SensorKit/$which
    if ! xmake l "$here/../../common/replace.lua" "$target" "$target" "$from" "$to"; then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        return
    fi
    if armv7 "$build/mutant/SensorKit/SensorKit170.m" "$build/mutant/170.o" \
        && armv7 "$build/mutant/SensorKit/SensorKit150.m" "$build/mutant/150.o"; then
        :
    else
        echo "MUTANT DID NOT BUILD, which is not the same as being noticed: $label"
        survived=$((survived + 1))
        return
    fi
    if xmake l "$here/check_values.lua" "$build/mutant/SensorKit/SensorKit170.m" \
        "$build/mutant/SensorKit/SensorKit150.m" "$build/mutant/170.o" "$build/mutant/150.o" \
        > "$build/mutant.out" 2>&1; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "  caught: $(grep -m 1 '^FAIL' "$build/mutant.out" | cut -c1-100)"
        echo "  caught: $(grep -m 1 '^sensorkit-value:' "$build/mutant.out")"
    fi
}

echo "--- the plants"

plant "a property answers a constant instead of the store" SensorKit170.m \
    "REVENANT_VALUE_PROPERTY(id, faceAnchor)" \
    "REVENANT_VALUE_PROPERTY(NSString *, unusedFaceAnchor)"

plant "a count answers a constant" SensorKit150.m \
    "-(NSInteger)wordCountForSentimentCategory:(NSInteger)category
{
    return [[self revenant_valueForKey:RevenantKeyboardSentimentKey(@\"wordCountForSentimentCategory:\", category)]
            longLongValue];
}" \
    "-(NSInteger)wordCountForSentimentCategory:(NSInteger)category
{
    (void)category;
    return 7;
}"

plant "a count drops the category from its key, so all ten answer the same number" SensorKit150.m \
    "return [NSString stringWithFormat:@\"%@%ld\", selector, (long)category];" \
    "return selector;"

plant "an accessor deleted outright" SensorKit170.m \
    "REVENANT_VALUE_PROPERTY(id, soundClassification)" \
    ""

echo "--- the check's own control: an object carrying none of the five must not look green"
: > "$build/empty.o"
if xmake l "$here/check_values.lua" "$src170" "$src150" "$build/empty.o" "$build/empty.o" \
    > "$build/empty.out" 2>&1; then
    echo "FAIL an object with none of the five selectors was accepted"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -c '^FAIL' "$build/empty.out") of the five are reported missing"
fi

if [ "$survived" -ne 0 ]; then echo "$survived plants survived; this check proves nothing"; exit 1; fi
echo "sensorkit-value: OK - 5 accessors in the source and in the object, 5 plants noticed"