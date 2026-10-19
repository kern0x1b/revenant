#!/bin/sh
# tests/backports/device/<program>.m for the classes the backports carry below iOS 6, as device binaries run on emulated releases: the
# port's answers on 4.3 and 5.0 are held to the release's own on 6.0 (the `answer` lines), and each program's own checks must pass.
# Two builds (xmake.lua), each with revenant@apple-backports linked: "ported", apple_minimum 4.3, run on every release below the class's
# own minimum; "bare", apple_minimum set to the reference release (6.0) itself, run on it alone - "bare" for what band() (modules/
# apple/backports.lua) puts in that band, not for whether the package is linked: at apple_minimum 6.0 it reexports the class instead
# of carrying it, the same way the real apple-backports .deb's own band 6.0 does (checked with nm: no NSProgress/NSUUID class metadata
# there, only a reexport stub). Revenant's own "copy the library in" mechanism (toolchain/AGENTS.md, "revenant.libraries and verify_placed")
# copies the band a build's own apple_minimum names, so a "ported" binary (band 4.3, which does carry the class) run on the
# reference release instead would hold two classes of the same name next to the release's real Foundation, and the runtime's own
# choice between them ("which one is undefined") is not a measurement of either. Like tests/backports/device/display-probe/xmake.lua's
# own per-cell apple_minimum, the env var that picks it (BELOW6_MINIMUM) stays exported for configuring, building, installing and
# running alike - xmake emulate install re-reads xmake.lua, so a var exported only around the build step is unset again by the time
# install runs. One heavy job (the package's build and an emulated boot a release), so run it in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/below6/run.sh nsuuid
# BELOW6_RELEASES lists the releases (default "6.0 4.3 5.0"; the first is the reference, run with the bare build); BELOW6_DEVICE names
# the device (default iPhone2,1, the 3GS, which runs every release named here, and iPhone3,1 for 6.0); BELOW6_UIKIT=1 builds the package
# with UIKit, for a program that needs it; BELOW6_BUILD is where the builds and the logs go. It needs the addon v0.8.12 in the shared
# xmake store and the firmware of each release.
# Exits 1 for a program that did not pass, an answer that differs from the reference's, a run that left no report, and no program named.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
export BELOW6_ROOT=$(cd "$here/../../../.." && pwd)
[ $# -gt 0 ] || { echo "usage: run.sh PROGRAM..."; exit 1; }
releases=${BELOW6_RELEASES:-"6.0 4.3 5.0"}
reference=$(echo "$releases" | awk '{print $1}')
others=$(echo "$releases" | cut -d' ' -f2-)
build=${BELOW6_BUILD:-$(runs_folder revenant-below6)}
rm -rf "$build"
mkdir -p "$build/ported" "$build/bare"
cp "$here/xmake.lua" "$here/control" "$build/ported/"
cp "$here/xmake.lua" "$here/control" "$build/bare/"
failed=0

# $1: cell (ported/bare), $2: apple_minimum, $3: the releases to install and run on
run_cell() {
    cell=$1; minimum=$2; cellreleases=$3
    shift 3
    [ -n "$cellreleases" ] || return 0
    (
        cd "$build/$cell"
        export BELOW6_MINIMUM=$minimum
        xmake f -c -p iphoneos -a armv7 -y > configure.log 2>&1 || { echo "$cell: CONFIG-FAIL"; tail -5 configure.log; exit 1; }
        xmake build -y "$@" > build.log 2>&1 || { echo "$cell: BUILD-FAIL"; sed 's/\x1b\[[0-9;]*m//g' build.log | grep -a 'error' | head -10; exit 1; }
        cellfailed=0
        for program in "$@"; do
            for release in $cellreleases; do
                device=${BELOW6_DEVICE:-iPhone2,1}
                [ -n "${BELOW6_DEVICE:-}" ] || [ "$release" != 6.0 ] || device=iPhone3,1
                xmake emulate -d "$device" -r "$release" install > "$build/install-$release.log" 2>&1 || { echo "$program $release ($cell): INSTALL-FAIL"; cellfailed=1; continue; }
                xmake emulate -d "$device" -r "$release" run "/usr/libexec/$program" > "$build/$program-$release.log" 2>&1 || true
                sed 's/\x1b\[[0-9;]*m//g' "$build/$program-$release.log" > "$build/$program-$release.txt"
                # The verdict line names the run - pass, fail, crash, timeout or boot-blocked - between the colour codes.
                if ! grep -Eq "pass.{0,12} on iPhone" "$build/$program-$release.txt" || grep -q '^FAIL' "$build/$program-$release.txt"; then
                    echo "$program $release ($cell): not a pass"; grep -aE '^FAIL|^fail|^crash|^timeout|^error|blocked' "$build/$program-$release.txt" | head -20
                    cellfailed=1
                else
                    echo "$program $release ($cell): $(grep -aE ": [0-9]+ checks, |^checks=[0-9]+ failures=[0-9]+" "$build/$program-$release.txt") ($(grep -a '^NSUUID comes from\|comes from' "$build/$program-$release.txt" | head -1))"
                fi
                grep -a '^answer ' "$build/$program-$release.txt" > "$build/$program-$release.answers" || true
            done
        done
        exit $cellfailed
    )
}
run_cell bare "$reference" "$reference" "$@" || failed=1
run_cell ported 4.3 "$others" "$@" || failed=1

for program in "$@"; do
    # The reference release's own answers are what the port must give where the release has none.
    for release in $others; do
        if diff "$build/$program-$reference.answers" "$build/$program-$release.answers" > "$build/$program-diff-$release.txt" 2>/dev/null; then
            echo "$program $release: the $(wc -l < "$build/$program-$release.answers" | tr -d ' ') answers are $reference's"
        else
            echo "$program $release: answers that are not $reference's:"; cat "$build/$program-diff-$release.txt" 2>/dev/null || echo "  ($reference's own answers are missing: its run above must be checked first)"
            failed=1
        fi
    done
done
echo "logs=$build"
exit $failed
