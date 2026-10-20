#!/bin/sh
# textkit2.m as a device binary under xmake emulate: every implemented method of the range layer of TextKit 2
# called on the release, once per release, and nothing may crash. The port's classes are the only ones of their
# names on 6.1.3 and on 4.3, so this is a call test and not a differential: what each answer is was measured
# against the host's own UIKit (packages/frameworks/apple-backports/facts/UIKit/NSTextRange15.md) and the checks here are
# those rules held on the release. The two releases are the ones the port targets: 6.1.3 and 4.3, so both ends
# of the armv7 range are asked. One heavy job (the package's build and an emulated boot a release), so run it in
# a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/textkit2/run.sh
# TEXTKIT2_RELEASES lists the releases (default "6.1.3 4.3"), TEXTKIT2_DEVICE the device (default iPhone3,1, the
# 4S, which runs both), TEXTKIT2_BUILD where the builds and the logs go. It needs the addon v0.8.12 in the shared
# xmake store and the firmware of each release. Exits 1 for a release whose checks did not all pass, a run that
# left no report, and a run whose verdict is not a pass.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
export TEXTKIT2_ROOT=$(cd "$here/../../.." && pwd)
releases=${TEXTKIT2_RELEASES:-"6.1.3 4.3"}
device=${TEXTKIT2_DEVICE:-iPhone3,1}
build=${TEXTKIT2_BUILD:-$(runs_folder revenant-textkit2)}
rm -rf "$build"
mkdir -p "$build"
cp "$here/textkit2/xmake.lua" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
failed=0
for release in $releases; do
    # The binary's own apple_minimum names the band that is copied in, and it has to stay exported for install
    # and run as well: xmake emulate install re-reads xmake.lua.
    TEXTKIT2_MINIMUM="$release" xmake emulate -d "$device" -r "$release" install > "install-$release.log" 2>&1
    TEXTKIT2_MINIMUM="$release" xmake emulate -d "$device" -r "$release" run /usr/libexec/textkit2 > "$release.log" 2>&1 || true
    # The verdict line names the run - pass, fail, crash, timeout or boot-blocked - between colour codes.
    if ! grep -Eq 'pass.{0,12} on iPhone' "$release.log" || grep -q '^FAIL' "$release.log"; then
        echo "$release: not a pass"
        grep -aE '^FAIL|fail|crash|timeout|blocked' "$release.log" || true
        failed=1
        continue
    fi
    report=$(grep -a ' checks, ' "$release.log" | tail -1 || true)
    if [ -z "$report" ]; then
        echo "$release: the run left no report"
        failed=1
        continue
    fi
    echo "$release: $report"
    # The answers are the same on both releases, so the second one is held to the first: a rule that only holds
    # on one of them is a rule that is not the port's.
    if [ "$release" = "$(echo $releases | awk '{print $1}')" ]; then
        grep -a '^ok ' "$release.log" | sed 's/^ok //' | sort > "$build/expected.txt"
    else
        grep -a '^ok ' "$release.log" | sed 's/^ok //' | sort > "$build/answered-$release.txt"
        if diff "$build/expected.txt" "$build/answered-$release.txt" > "$build/diff-$release.txt"; then
            echo "$release: the same $(wc -l < "$build/answered-$release.txt" | tr -d ' ') checks pass as on $(echo $releases | awk '{print $1}')"
        else
            echo "$release: checks that do not pass on both releases:"; head -20 "$build/diff-$release.txt"
            failed=1
        fi
    fi
done
echo "logs=$build"
exit $failed
