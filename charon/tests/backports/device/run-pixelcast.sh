#!/bin/sh
# run-pixelcast.sh — the pixel cast's device run, prepared and not run.
#
# Every step is here and none of it has been executed, because the library the run measures is built
# by the package, and that comes with the coordinator's stack-14 push. Until the installed
# libSceneKitBackports carries `projectPoint` (measured on the store's copy: 0 occurrences), a run
# would measure a library without the code under test, so the provenance check below is not a
# formality - it is what stops that run from being believed.
#
# The order, and why each step is here:
#
#   1. build the probe for the target          the swift-runtime overlays it links are the package's,
#                                             and they are what the push produces
#   2. build the test binary that holds the    an Objective-C device test, already written and
#      backports to macOS                      already compiling for armv7 with 0 errors
#   3. record the provenance of both           LC_UUID, and the bytes up to LC_CODE_SIGNATURE
#   4. install into the image                  xmake emulate install
#   5. check the in-image copies               a different LC_UUID means the install is stale or
#                                             another build, and the run must not be read
#   6. run the test, then the probe             verdicts first, numbers second
#
# Load: the run is only for a machine whose load1 is under 12 with a free slot, and it goes through
# heavy.sh detached. `uptime` is read here, at the moment of the run, and its numbers are quoted in
# the log - a reading taken earlier and copied is not a reading.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
# The coordination directory, from the home directory: a commit carrying an absolute
# home path is refused by the hook, and rightly - it would not resolve on another machine.
C=${COORDINATION:-$HOME/Git/projects/ios/coordination}
work=${WORK:-$repo/.agent-work/runs/pixelcast-device}
run=${RUN:-0}

mkdir -p "$work"

if [ "$run" != "1" ]; then
    cat <<EOF
prepared, not run.  Set RUN=1 once the library carries projectPoint.

  1  sh $here/build-scenekitprojection.sh                    # the device test, armv7
  2  swiftc the probe for armv7 against the port's overlays  # see build-probe.sh; it needs the
                                                            # package's swiftRuntime modules, which
                                                            # the push produces
  3  sh $here/provenance.sh uuid <each binary>                # record before the install
  4  xmake emulate install
  5  sh $here/provenance.sh check <local> <in-image copy>
  6  xmake emulate run <the test> && xmake emulate run <the probe>
  and only with load1 under 12 and a free slot, through heavy.sh, detached.
EOF
    exit 0
fi

# The load, read here and now: the numbers below are this run's, not a copy of an earlier one.
echo "=== $(date '+%H:%M:%S %Z') ==="
uptime | tee "$work/uptime.log"
load1=$(uptime | sed -E 's/.*load averages: ([0-9.]+).*/\1/')
# The lock directory is heavy.sh's, and it is named by its variable rather than written
# down: FLEET_HEAVY_DIR defaults to /tmp/fleet-heavy, and a suite that hardcoded that
# would read the wrong lock when a run sets the variable.
heavy_dir=${FLEET_HEAVY_DIR:-/tmp/fleet-heavy}
slots=$(ls "$heavy_dir/machine/" 2>/dev/null | wc -l | tr -d ' ')
echo "load1 = $load1, machine slots in use = $slots"
# uptime prints a float; [ cannot compare one, and the error left the gate doing nothing at all.
if awk -v load="$load1" 'BEGIN { exit !(load >= 12) }'; then
    echo "not run: load1 $load1 is not under 12"
    exit 0
fi

echo "=== the provenance, before the install ==="
sh "$here/provenance.sh" uuid "$work/scenekitprojection" | tee "$work/uuid-test-before.log"
# The library the test links: its LC_UUID is the package build's, and that is what the in-image
# copy has to carry.
# The installed SceneKit backports: the newest install in the store, which is the one the package
# build last left.
lib=${LIB:-$(find "$HOME/.xmake/packages/a/apple-backports" -name libSceneKitBackports.dylib 2>/dev/null | xargs stat -f "%m %N" | sort -rn | head -1 | cut -d" " -f2-)}
if [ -f "$lib" ]; then
    sh "$here/provenance.sh" uuid "$lib" | tee "$work/uuid-lib-before.log"
    echo "projectPoint in the installed library: $(strings "$lib" | grep -c projectPoint)"
else
    echo "no library at $lib; set LIB="
    exit 2
fi

# xmake has to run where the project that carries the emulate task is: from the repository root it
# answers "xmake.lua not found, try generating it" and waits for a y/n that never comes. EMULATE_DIR
# names it, and the run refuses rather than installing into nothing.
emulate_dir=${EMULATE_DIR:-}
if [ -z "$emulate_dir" ] || [ ! -f "$emulate_dir/xmake.lua" ]; then
    echo "not run: EMULATE_DIR does not name a project with the emulate task (tried '$emulate_dir')"
    echo "  the port's root has no xmake.lua, and the plugin that provides the task is in a katabasis"
    echo "  checkout, so this run needs to be pointed at the project that carries it"
    exit 0
fi
echo "=== install and run, from $emulate_dir ==="
cd "$emulate_dir"
FLEET_HEAVY_LANE=fast "$C/heavy.sh" xmake emulate install
FLEET_HEAVY_LANE=fast "$C/heavy.sh" xmake emulate run "$work/scenekitprojection"
# The probe only when it has been built, and it cannot be until a swift-runtime install carries the
# RealityFoundation and RealityKit overlays for armv7 (measured: no install in the store has them, and
# none has a simd module for armv7 either, so a Swift guest program has nothing to compile against).
# Said here rather than left to fail as "the command is not in the image".
if [ -f "$work/probe" ]; then
    FLEET_HEAVY_LANE=fast "$C/heavy.sh" xmake emulate run "$work/probe"
else
    echo "skipped the probe: no armv7 RealityFoundation module to build it against (no swift-runtime install carries the overlays)"
fi
echo "=== the verdicts, from xmake emulate log ==="
FLEET_HEAVY_LANE=fast "$C/heavy.sh" xmake emulate log | tail -30 | tee "$work/verdicts.log"
