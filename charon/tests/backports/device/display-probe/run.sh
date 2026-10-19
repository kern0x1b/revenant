#!/bin/sh
# tests/backports/device/display-probe.m on an emulated release, built for every combination of the two things a build decides:
# the binary's apple_minimum (4.3, and the release's own where that is a different one) and charon@apple-backports linked or not
# (facts/UIKit/UIDynamicAnimator.md M3). One heavy job, so run it in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/display-probe/run.sh 6.1.3
# DISPLAYPROBE_DEVICE names the emulated device (default iPhone3,1, and iPhone4,1 for 6.1.3: the device the release's other device
# programs use); the display the process finds depends on it as well as on the release (facts M3), so a run names both.
# DISPLAYPROBE_CELLS lists the `minimum:package` cells to build (default every one), e.g. "4.3:0 6.0:1".
# Arguments: the release (4.3, 5.1.1, 6.0 or 6.1.3), then optionally the modes to run, each in quotes, `screen view` and so on
# (default: "screen" "screen view" "screen window" "screen turn"; a mode may be named twice, to see whether a run repeats). Each mode is a run of its own, since a display link that
# faults ends the process. DISPLAYPROBE_BUILD is where the builds and the logs go (default a directory of the system temp path);
# copy what a fact cites out of it before it is wiped.
# Exits 1 when a cell fails to configure, build or install, when a run left no report (a fault is the datum, a boot-blocked or timed-out
# run that never printed its `UIScreen screens` line is not), and when DISPLAYPROBE_CELLS names no cell that exists.
# It needs the addon v0.8.11 in the shared xmake store and the firmware of the release, as any port does.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
export DISPLAYPROBE_ROOT=$(cd "$here/../../../.." && pwd)
release=${1:?release}
shift
[ $# -gt 0 ] || set -- "screen" "screen view" "screen window" "screen turn"
device=${DISPLAYPROBE_DEVICE:-iPhone3,1}
[ -n "${DISPLAYPROBE_DEVICE:-}" ] || [ "$release" != 6.1.3 ] || device=iPhone4,1
build=${DISPLAYPROBE_BUILD:-$(runs_folder charon-display-probe)}/$release-$device
failed=0
cells=0
minimums=$release
[ "$release" = 4.3 ] || minimums="4.3 $release"
for minimum in $minimums; do
    for package in 0 1; do
        # Below 6.1.3 the package's weak imports are refused by the release, which the target waives. The deb's postinst picks the
        # band by the version of the OS it is installed on, so the cells at minimum 4.3 and at the release's own install the same
        # band; what differs is the minimum OS the binary and the libraries are built for (M3).
        case " ${DISPLAYPROBE_CELLS:-$minimum:$package} " in *" $minimum:$package "*) ;; *) continue ;; esac
        cells=$((cells + 1))
        cell=$build/min-$minimum-pkg-$package
        rm -rf "$cell"
        mkdir -p "$cell"
        cp "$here/xmake.lua" "$here/control" "$cell/"
        (
            cd "$cell"
            export DISPLAYPROBE_MINIMUM=$minimum DISPLAYPROBE_PACKAGE=$package
            xmake f -c -p iphoneos -a armv7 -y > configure.log 2>&1 || { echo "min $minimum pkg $package: CONFIG-FAIL"; tail -5 configure.log; exit 1; }
            xmake build -y > build.log 2>&1 || { echo "min $minimum pkg $package: BUILD-FAIL"; tail -5 build.log; exit 1; }
            xmake emulate -d $device -r "$release" install > install.log 2>&1 || { echo "min $minimum pkg $package: INSTALL-FAIL"; exit 1; }
            n=0
            unreported=0
            for mode in "$@"; do
                n=$((n + 1))
                name=$n-$(echo "$mode" | tr ' ' '-')
                # A run that faults exits non-zero and is the datum; its log says what happened.
                xmake emulate -d $device -r "$release" run /usr/libexec/display-probe $mode > "run-$name.log" 2>&1 || true
                # A run that faults is the datum and its log says so; a run that got no report at all (boot-blocked, a timeout, an
                # emulator that did not start) is not one. The report of a program run as a command is its `UIScreen screens` line, even
                # when the display link then faults; the `app` mode's datum is the run's own verdict, which the emulator prints as `pass on
                # ...` or, for every other state, as `error: <state>(...) on ...`; a timeout is not a datum, so it is not matched.
                case "$mode" in
                    *app*) pattern='^(pass|error: (fail|crash|boot-blocked))' ;;
                    *)    pattern='^UIScreen screens' ;;
                esac
                if ! sed 's/\x1b\[[0-9;]*m//g' "run-$name.log" | grep -aEq "$pattern"; then
                    unreported=$((unreported + 1))
                    echo "min $minimum pkg $package, $mode: NO REPORT in run-$name.log"
                fi
                echo "== $release on $device, apple_minimum $minimum, package $package, $mode: $(sed 's/\x1b\[[0-9;]*m//g' "run-$name.log" | grep -a '^UIScreen screens\|^display link\|^FAULT\|^a UI\|^a CAT\|^waited\|^pass\|^error' | tr '\n' '|')"
            done
            [ "$unreported" -eq 0 ] || exit 1
        ) || failed=1
    done
done
if [ "$cells" -eq 0 ]; then
    echo "no cell ran: DISPLAYPROBE_CELLS (${DISPLAYPROBE_CELLS:-unset}) names none of the cells $minimums x 0 1 (minimum:package)"
    failed=1
fi
echo "logs=$build"
exit $failed
