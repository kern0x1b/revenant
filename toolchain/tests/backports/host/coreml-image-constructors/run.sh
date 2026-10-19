#!/bin/sh
# The host side of the CGImage constructor measurement (facts/CoreML/Image13.md). The probe is built against the
# host's own CoreML and run; its output is checked for the case count and for the error table, which is the part of
# the measurement the port already matches. The pixel comparison with the port is recorded in the facts, not run here.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${COREML_IMAGE_BUILD:-$(runs_folder revenant-coreml-image-host)}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/probe.m" \
    -framework Foundation -framework CoreML -framework CoreGraphics -framework CoreVideo -o "$build/probe"
"$build/probe" > "$build/host.txt"
cases=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$cases" != 3072 ]; then
    echo "cases $cases, want 3072"
    exit 1
fi
grep ': err ' "$build/host.txt" | awk '{ match($0, /crop=[^ ]+/); c = substr($0, RSTART, RLENGTH);
    match($0, /size=[^ ]+/); s = substr($0, RSTART, RLENGTH); print c, s, $(NF - 1), $NF }' |
    sort | uniq -c | awk '{ print $2, $3, $4, $5, $1 }' > "$build/errors.txt"
diff "$here/errors.txt" "$build/errors.txt"
echo "cases $cases; error table matches errors.txt"
