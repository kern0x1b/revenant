#!/bin/sh
# run.sh - the port's DCAppAttestService (renamed CharonHostDCAppAttestService) against the host's own
# DeviceCheck. The host is a platform that does not run the App Attest service, which is what an iPhone
# 4S and an iPad 2 are: no Secure Enclave and no daemon of that name.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/Foundation}
harness=${DEVICEATTEST_HARNESS:-$here/../../device}
build=${DEVICEATTEST_BUILD:-$(runs_fresh charon-deviceattest)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DDCAppAttestService=CharonHostDCAppAttestService \
    -c "$port/DCAppAttestService14.m" -o "$build/port.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port.o" \
    -framework Foundation -framework DeviceCheck -o "$build/differential"
"$build/differential"
