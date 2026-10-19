#!/bin/sh
# The oracle side of the guest probe: probe.m alone, against the host's own UTTypeCopyAllTagsWithClass.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
BUILD=${BUILD:-$(runs_fresh charon-uttypetags-host)}
xcrun clang -fobjc-arc -w -I"$here" "$here/probe.m" -framework Foundation -framework CoreServices -o "$BUILD/probe"
"$BUILD/probe" > "$BUILD/host.txt"
echo "$BUILD/host.txt"
