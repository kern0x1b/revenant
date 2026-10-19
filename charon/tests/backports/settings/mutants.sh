#!/bin/sh
# settings/mutants.sh - every assertion of the settings check has a mutant, and every mutation has a
# control. How many that is, and how many of them died and how many were controls, is printed by the
# run and not written here: a count in a file is a count no run maintains, and this file has been wrong
# about the check's own assertion count twice today already.
#
# The rules, and the mutants that break them:
#   M1  a settings value answers YES, where the release's answer is NO            (the six value answers)
#   M2  a notification is never posted                                            (the observer)
#   M3  the completion is not called at all                                        (the Settings call)
#   M4  the completion is called twice                                            (the Settings call)
#   M5  the completion is called after the function returns                        (the Settings call)
#   M6  the error carries a system domain rather than the port's                  (the Settings call)
#   M7  the error's code is not the feature the caller asked for                   (the Settings call)
#   M8  a notification constant is carried under another name                      (the five constants)
#   M9  the hearing object does not define the streaming-ear function              (nm, not a run)
#  M10  a null completion crashes the port                                        (the Settings call)
#  M11  the control: the sources copied through the same path with nothing changed, which must stay green
#
# A mutant that does not BUILD is "RUN FAILED", never counted as noticed: a mutant that stops the
# compiler has told nobody anything about the answer, which is the defect this file's own M10 exists to
# catch, because the first version of it compiled a mutation that only removed a line and was counted as
# a kill.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
root=$(cd "$here/../../.." && pwd)
package=$root/packages/a/apple-backports
sources=${ACCESSIBILITY_SRC:-$package/Accessibility}
work=${BUILD:-$(runs_folder charon-accessibility-settings-mutants)}
rm -rf "$work"
mkdir -p "$work"
survived=0
ran=0
killed=0
run_failed=0
control_green=0

# mutate <dir> <file> <nth> <old> <new>  - through the tree's own mutator, on a copy
mutate() {
    dir=$1; file=$2; nth=$3; old=$4; new=$5
    MUTATE="$dir/$file" MUTATE_OLD="$old" MUTATE_NEW="$new" MUTATE_NTH="$nth" \
        python3 "$here/../host/common/mutate.py"
}

# mutation <name> <file> <nth> <old> <new> - break one thing and run the check; a control is a
# mutation whose old and new are the same, so the same path is exercised and must stay green.
mutation() {
    name=$1; file=$2; nth=$3; old=$4; new=$5
    crash_is_kill=${6:-0}
    is_control=0
    if [ "$old" = "$new" ]; then is_control=1; fi
    dir="$work/$name"
    mkdir -p "$dir"
    cp "$sources/Accessibility.m" "$dir/" 2>/dev/null || true
    for each in CharonAXSettings.h CharonAXSettingsCommon.h CharonAXSettings17.m CharonAXSettings18.m \
                CharonAXSettings26.m CharonHearing15.m; do
        cp "$sources/$each" "$dir/$each"
    done
    cp "$package/CharonSayOnce.h" "$dir/" 2>/dev/null || true
    if ! mutate "$dir" "$file" "$nth" "$old" "$new" 2>"$dir/mutate.log"; then
        echo "MUTANT DID NOT APPLY: $name: $(tail -1 "$dir/mutate.log")"
        run_failed=$((run_failed + 1))
        return 0
    fi
    ran=$((ran + 1))
    if ACCESSIBILITY_SRC="$dir" BUILD="$dir/build" sh "$here/run.sh" > "$dir/out.txt" 2>&1; then
        if [ "$is_control" -eq 1 ]; then
            control_green=$((control_green + 1))
            echo "control stayed green through the same path: $name"
        else
            echo "MUTANT SURVIVED: $name"
            survived=$((survived + 1))
        fi
    elif grep -q 'FAILED' "$dir/out.txt"; then
        killed=$((killed + 1))
        echo "killed: $name: $(grep -m1 'FAILED' "$dir/out.txt")"
    elif [ "$crash_is_kill" -eq 1 ] && grep -q 'Segmentation fault' "$dir/out.txt"; then
        # This mutation's point is that the port crashes on a null completion, so a crash is the kill.
        # Any other mutation that crashes is RUN FAILED, below.
        killed=$((killed + 1))
        echo "killed: $name: the program died on a null completion, which is the behaviour being broken"
    elif grep -q 'did not build' "$dir/out.txt" || grep -q 'error:' "$dir/out.txt"; then
        # A mutation that stops the build is not a kill: it is RUN FAILED, and saying otherwise is how a
        # check that examines nothing comes to be trusted.
        run_failed=$((run_failed + 1))
        echo "RUN FAILED (not counted as noticed): $name: $(grep -m1 -E 'error:' "$dir/out.txt")"
    else
        run_failed=$((run_failed + 1))
        echo "MUTANT DIED FOR THE WRONG REASON: $name"
        tail -4 "$dir/out.txt"
    fi
}

# M1: the shared answer becomes YES. It is in CharonAXSettingsCommon.h, which is where the census's
# result lives, so this breaks all six value answers at once and that is the honest shape of it.
mutation M1-value-yes CharonAXSettingsCommon.h 1 \
    '    return NO;
}' \
    '    return YES;
}'

# M2: the library posts what it never changed. The first version of this mutation added a function that
# posts and nothing ever called it, so the check was right to pass it - the mutation broke nothing, and a
# mutation that breaks nothing is not a mutation. It posts from AXAnimatedImagesEnabled instead, which
# the check calls, so the observer fires and the assertion about nothing being posted has to fail.
mutation M2-posts-a-change CharonAXSettings17.m 1 \
    'BOOL AXAnimatedImagesEnabled(void)
{
    return CharonAXSettingIsOffOnThisRelease();
}' \
    'BOOL AXAnimatedImagesEnabled(void)
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:AXAnimatedImagesEnabledDidChangeNotification object:nil];
    return CharonAXSettingIsOffOnThisRelease();
}'

# M3, M4, M5, M6, M7, M10: the Settings call.
mutation M3-completion-never-called CharonAXSettings18.m 1 \
    '    if (!completionHandler) {
        return;
    }' \
    '    if (completionHandler || !completionHandler) {
        return;
    }'

mutation M4-completion-called-twice CharonAXSettings18.m 1 \
    '    completionHandler([NSError errorWithDomain:CharonAXSettingsErrorDomain code:feature userInfo:@{
        NSLocalizedDescriptionKey: reason,
        @"AXSettingsFeature": @(feature),
    }]);' \
    '    NSError *first = [NSError errorWithDomain:CharonAXSettingsErrorDomain code:feature userInfo:@{
        NSLocalizedDescriptionKey: reason,
        @"AXSettingsFeature": @(feature),
    }];
    completionHandler(first);
    completionHandler(first);'

mutation M5-completion-called-later CharonAXSettings18.m 1 \
    '    completionHandler([NSError errorWithDomain:CharonAXSettingsErrorDomain code:feature userInfo:@{' \
    '    NSError *deferred = [NSError errorWithDomain:CharonAXSettingsErrorDomain code:feature userInfo:@{
        NSLocalizedDescriptionKey: reason,
        @"AXSettingsFeature": @(feature),
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(deferred);
    });
    if (0) completionHandler([NSError errorWithDomain:CharonAXSettingsErrorDomain code:feature userInfo:@{'

mutation M6-system-domain CharonAXSettings18.m 1 \
    'NSErrorDomain const CharonAXSettingsErrorDomain = @"org.charon.Accessibility.Settings";' \
    'NSErrorDomain const CharonAXSettingsErrorDomain = @"com.apple.Accessibility.Settings";'

mutation M7-wrong-code CharonAXSettings18.m 1 \
    '    completionHandler([NSError errorWithDomain:CharonAXSettingsErrorDomain code:feature userInfo:@{' \
    '    completionHandler([NSError errorWithDomain:CharonAXSettingsErrorDomain code:0 userInfo:@{'

mutation M8-constant-renamed CharonAXSettings26.m 1 \
    '    @"AXShowBordersEnabledStatusDidChangeNotification";' \
    '    @"AXShowBordersEnabledStatusDidChange";'

# M9: the port stops defining one of the three. This one is held by nm over the object and not by a run,
# so the criterion is the symbol's absence from the run's own output.
mutation M9-hearing-ear-not-defined CharonHearing15.m 1 \
    'AXHearingDeviceEar AXMFiHearingDeviceStreamingEar(void)' \
    'static AXHearingDeviceEar charon_port_unused(void)'

# M10: a null completion is dereferenced. It compiles; the program dies; that is not a kill.
mutation M10-null-completion-crashes CharonAXSettings18.m 1 \
    '    if (!completionHandler) {
        return;
    }' \
    '    if (!completionHandler) {
        completionHandler(nil);
        return;
    }' 1

# M11: the control. The same path, nothing changed, which has to stay green - without it, a check that
# was red for any reason at all would pass every mutation above.
mutation M11-control-path-only CharonAXSettings17.m 1 \
    '    return CharonAXSettingIsOffOnThisRelease();' \
    '    return CharonAXSettingIsOffOnThisRelease();'

echo "mutants run: $ran, killed: $killed, controls stayed green: $control_green, run failed: $run_failed, survived: $survived"
[ "$survived" -eq 0 ] && [ "$run_failed" -eq 0 ] && [ "$control_green" -eq 1 ] \
    && [ $((killed + control_green)) -eq "$ran" ]
