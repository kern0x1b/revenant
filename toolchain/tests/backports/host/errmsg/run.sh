#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
SECURITY=${SECURITY:-$here/../../../../packages/frameworks/apple-backports/Security}
harness=${ERRMSG_HARNESS:-$here/../../device}
build=${ERRMSG_BUILD:-$(runs_folder revenant-errmsg-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DSecCopyErrorMessageString=revenant_host_SecCopyErrorMessageString -c "$SECURITY/SecCopyErrorMessageString.m" -o "$build/port.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port.o" \
    -framework Foundation -framework Security -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
