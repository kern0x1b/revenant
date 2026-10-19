#!/bin/sh
# The port's AppleBLAS8.m held against the host's own Accelerate, case by case: the same inputs through
# each, comparing every element of C, and for a bad parameter the two messages and the two exit statuses
# from a child process each (the release's cblas_xerbla ends the process, as the host's own does).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
build=${APPLEBLAS_BUILD:-$(runs_folder charon-appleblas-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -w -Dappleblas_sgeadd=charon_host_appleblas_sgeadd -Dappleblas_dgeadd=charon_host_appleblas_dgeadd \
    -I"$ACCELERATE" -c "$ACCELERATE/AppleBLAS8.m" -o "$build/AppleBLAS8.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations \
    "$here/differential.m" "$build/AppleBLAS8.o" \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
