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
# The constant objects of HealthKit are written into .gen/HealthKit by gen, as the build writes them, from the SDK the spec is measured on
# (CHARON_GEN_SDK, the variable the gate sets). xmake.lua reads that folder, so gen runs first; a failure stops the run.
sdk=${CHARON_GEN_SDK:?set CHARON_GEN_SDK to the iPhoneOS 26.2 SDK}
corpus=${CHARON_CORPUS:-$HOME/Git/projects/ios/coordination/corpus}
(cd "$root" && xmake l tools/gen.lua gen --tree "$root" --framework HealthKit --sdk "$sdk" --coordination "$corpus") > "$build/gen.log" 2>&1 || {
    echo "gen HealthKit failed:"; tail -n 20 "$build/gen.log"; exit 1; }
cp "$here/xmake.lua" "$here/control" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
failed=0
for release in $releases; do
    xmake emulate -d "$device" -r "$release" install > "install-$release.log" 2>&1 || {
        echo "$release: install failed:"; tail -n 20 "install-$release.log"; exit 1; }
    xmake emulate -d "$device" -r "$release" run /usr/libexec/healthkit > "$release.log" 2>&1 || true
    if grep -q '^FAIL' "$release.log" || ! grep -Eq 'pass.{0,12} on iPhone' "$release.log"; then
        echo "$release: not a pass"
        grep -E '^FAIL|crash|timeout|blocked' "$release.log" || true
        failed=1
    else
        echo "$release: $(grep -E 'pass.{0,12} on iPhone' "$release.log")"
        grep -E 'health: ' "$release.log" | sed 's/^/  /' || true
    fi
done
echo "logs=$build"
exit $failed
