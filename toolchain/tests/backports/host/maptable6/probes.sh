#!/bin/sh
# The two probes the facts cite, as device binaries under xmake emulate (one heavy job):
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/maptable6/probes.sh
# enumprobe (probes/enum.m): the owner enumerating keys while others drop keys and values, on 5.1.1 (clean) and 4.3 (SIGSEGV).
# weakprobe (probes/weak.m): what libobjc's handle and dlsym answer for the weak functions, then __weak to the classes that keep their own retain count, on 5.0, 5.1.1, 6.0 and 4.3 (aborts there).
# weakwindowprobe (probes/weakwindow.m): what a __weak reference reads as -dealloc runs, for a class that does not keep its own retain count, on 5.0, 5.1.1, 6.0 and 4.3 - the one measurement the 4.3 paragraph of the facts calls unmeasured.
# registrationprobe (probes/registration.m): whether dispatch_resume calls a source's registration handler before it returns or only enqueues it, with the target queue held, on all four releases - what the registration half of the barrier source entry rests on.
# The verdicts are read, not asserted: a crash on 4.3 is what the facts say. Logs in $MAPTABLE6_BUILD.
# MAPTABLE6_BOOT is the whole-boot timeout in seconds (xmake emulate's -t, 900 by default). A release with no golden image
# yet in ~/.revenant/emulator has to boot once past its first-boot migration before it can run anything, and on a machine
# busy with two gate bands that first boot is the one that gives out - measured on 2026-10-03: the build and all three
# installs finished ("imports: every non-weak import ... resolves against 85386 exports", "install ok!") and
# "booting iPhone2,1 9A334 once past its first-boot migration for a golden image" answered "error: <no error object>".
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
export MAPTABLE6_ROOT=$(cd "$here/../../../.." && pwd)
export MAPTABLE6_PROBES=1
build=${MAPTABLE6_BUILD:-$(runs_folder revenant-maptable6-probes)}
device=${MAPTABLE6_DEVICE:-iPhone2,1}
: ${MAPTABLE6_BOOT:=1800}
rm -rf "$build"
mkdir -p "$build"
cp "$here/emulate/xmake.lua" "$here/emulate/control" "$here/emulate/control-enum" "$here/emulate/control-weak" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
for release in 5.0 5.1.1 6.0 4.3; do
    xmake emulate -d "$device" -r "$release" -t "$MAPTABLE6_BOOT" install > "install-$release.log" 2>&1
    for probe in enumprobe weakprobe weakwindowprobe registrationprobe; do
        [ "$probe" = enumprobe ] && [ "$release" != 5.1.1 ] && [ "$release" != 4.3 ] && continue
        xmake emulate -d "$device" -r "$release" -t "$MAPTABLE6_BOOT" run /usr/libexec/$probe > "$probe-$release.log" 2>&1 || true
        echo "== $probe $release"; sed 's/\x1b\[[0-9;]*m//g' "$probe-$release.log" | grep -E '^[A-Za-z]+: |^  |^libobjc handle|^dlsym |checks,|pass|crash|fail|Cannot|cannot' | cut -c1-200
    done
done
echo "logs=$build"
