#!/bin/sh
# run.sh - the port's AAAttribution (renamed RevenantHostAAAttribution) against the host's own
# AdServices. macOS is a platform Apple's attribution service does not support, so the host answers
# the question the port has to answer on iOS 6.1.3, which carries no AdServices either.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/frameworks/apple-backports/AdServices}
harness=${ADSERVICES_HARNESS:-$here/../../device}
build=${ADSERVICES_BUILD:-$(runs_fresh revenant-adservices)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DAAAttribution=RevenantHostAAAttribution -DAAAttributionErrorDomain=revenantHost_AAAttributionErrorDomain \
    -c "$port/AAAttribution.m" -o "$build/port-attribution.o"
xcrun clang -fobjc-arc -fvisibility=hidden -w -DAAAttributionErrorDomain=revenantHost_AAAttributionErrorDomain \
    -c "$port/AAAttributionNames.m" -o "$build/port-names.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$harness" \
    "$here/differential.m" "$harness/check.m" "$build/port-attribution.o" "$build/port-names.o" \
    -framework Foundation -framework AdServices -o "$build/differential"
"$build/differential"
