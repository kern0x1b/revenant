#!/bin/sh
# Two differentials, both against the HOST's own Security and CommonCrypto in one process:
#   differential.c       CCRandomGenerateBytes (the port's source, its symbol renamed): status and write bounds per input class
#   differential-constants.c   the 90 CFStringRef constants the port carries that the host also exports: values, as strings
#                              (78 "both" constants, then the 11 RFC 4754 names of iOS 17.0 and kSecImportToMemoryOnly of 18.0)
# The build directory is under the checkout's agent work area, never the system temp path.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
CCSRC=${CCSRC:-$root/packages/a/apple-backports/CommonCrypto}
SECSRC=${SECSRC:-$root/packages/a/apple-backports/Security}
build=${CC_BUILD:-$root/.agent-work/runs/commoncrypto-host}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DCCRandomGenerateBytes=revenant_host_CCRandomGenerateBytes \
    -c "$CCSRC/CCRandomGenerateBytes.m" -o "$build/port.o"
xcrun clang -w "$here/differential.c" "$build/port.o" -framework Security -o "$build/differential"
xcrun clang -fobjc-arc -w -c "$SECSRC/SecurityNames100.m" -o "$build/names.o"
xcrun clang -fobjc-arc -w -c "$SECSRC/SecurityConstants11_0.m" -o "$build/constants.o"
xcrun clang -fobjc-arc -w -c "$SECSRC/SecurityNames170.m" -o "$build/names170.o"
xcrun clang -fobjc-arc -w -c "$SECSRC/SecurityNames180.m" -o "$build/names180.o"
xcrun clang -w "$here/differential-constants.c" "$build/names.o" "$build/constants.o" "$build/names170.o" "$build/names180.o" \
    -framework Foundation -framework Security -o "$build/differential-constants"
status=0
"$build/differential" > "$build/log-ccrandom" 2>&1 || status=1
"$build/differential-constants" > "$build/log-constants" 2>&1 || status=1
grep -v '^ok ' "$build/log-ccrandom" "$build/log-constants" || true
echo "logs=$build"
exit $status
