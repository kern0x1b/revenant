#!/bin/sh
# run.sh: the port's HealthKit on a 6.1.3 emulator, answering the three questions a device without
# Health data can answer: whether Health data is available, what the authorization status is for a
# process that has asked for nothing, and what error a query of a type the process may not read gives.
# Each is held to what Apple's own headers document, and the release's own HealthKit is the control: on
# 6.1.3 it is absent, and the test prints that the release cannot answer where the port can.
#
# One heavy job - a build and an emulated boot of a release - so run it in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/device/healthkit/run.sh
#
# HEALTHKIT_DEVICE names the device (default iPhone4,1, the 4S, which runs 6.1.3 and has the hardware
# HealthKit asks about), HEALTHKIT_RELEASES the releases (default "6.1.3"), and HEALTHKIT_BUILD where
# the build and the logs go. It needs the addon in the shared xmake store and the firmware of each
# release named. Exits 1 for a program that did not pass.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
export HEALTHKIT_ROOT=$root
build=${HEALTHKIT_BUILD:-$(runs_folder charon-healthkit-device)}
device=${HEALTHKIT_DEVICE:-iPhone4,1}
releases=${HEALTHKIT_RELEASES:-"6.1.3"}
rm -rf "$build"
mkdir -p "$build"
# The package's build runs gen from CHARON_GEN_SDK (the variable the gate sets, the iPhoneOS 26.2 SDK the spec is measured on).
export CHARON_GEN_SDK=${CHARON_GEN_SDK:?set CHARON_GEN_SDK to the iPhoneOS 26.2 SDK}
cp "$here/xmake.lua" "$here/control" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
failed=0
for release in $releases; do
    xmake emulate -d "$device" -r "$release" install > "install-$release.log" 2>&1 || {
        echo "$release: install failed:"; tail -n 20 "install-$release.log"; exit 1; }
    xmake emulate -d "$device" -r "$release" run /usr/libexec/healthkit > "$release.log" 2>&1 || true
    # The checks' lines are the program's own log in the guest (check.m writes /private/var/backports/healthkit.log), which healthkit.m
    # reads back and echoes through NSLog: the run's output carries them as "guest log: <line>". A run that echoes none is not a pass.
    sed -n 's/.*guest log: //p' "$release.log" > "$release.guest.log"
    if ! grep -q '^ok ' "$release.guest.log" || grep -q '^FAIL' "$release.guest.log" || ! grep -Eq 'pass.{0,12} on iPhone' "$release.log"; then
        echo "$release: not a pass"
        grep -E '^FAIL|crash|timeout|blocked' "$release.log" "$release.guest.log" || true
        failed=1
    else
        echo "$release: $(grep -c '^ok ' "$release.guest.log") checks ok, none failed; $(grep -E 'pass.{0,12} on iPhone' "$release.log")"
        sed 's/^/  /' "$release.guest.log"
    fi
done
echo "logs=$build"
exit $failed
