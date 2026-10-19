#!/bin/sh
# The host's answers for the optical-flow and trajectory requests (facts/Vision/Motion.md). The output is compared
# with expected.txt, which holds the measured answers; a host that answers differently fails here.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${MOTION_BUILD:-$(runs_folder charon-vision-motion-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/motion.m" \
    -framework Foundation -framework Vision -framework CoreVideo -framework CoreMedia -o "$build/motion"
"$build/motion" > "$build/log" 2>&1
diff "$here/expected.txt" "$build/log"
echo "motion: host answers match expected.txt"
