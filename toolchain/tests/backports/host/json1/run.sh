#!/bin/sh
# NSJSONSerialization of packages/frameworks/apple-backports/Foundation/NSJSONSerialization.m, compiled for the host with the
# class renamed, against the host's own NSJSONSerialization: the whole class (the three 5.0 methods and the two 7.0
# stream methods), every reading and writing rule the file names, the exact wording of every error and exception, the
# position each error carries, and the number each literal comes out as.
#
# Two comparisons are deliberately not exact, each for a stated reason, and both are checked here rather than left out:
#   - the text of a written dictionary without NSJSONWritingSortedKeys (an unsorted dictionary has no order of its own;
#     this host's Foundation sorts, the releases this port carries write the dictionary's own order), and
#   - the position a "too deeply nested" failure carries (the host reports an internal offset, the file reports where
#     the limit was reached); the wording of that failure and whether it happens at all are compared exactly.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
FOUNDATION=${FOUNDATION:-$here/../../../../packages/frameworks/apple-backports/Foundation}
BUILD=${BUILD:-$(runs_fresh revenant-json1)}
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-objc-designated-initializers"
rm -rf "$BUILD/port"
mkdir -p "$BUILD/port"
xcrun clang -fobjc-arc $quiet -DNSJSONSerialization=RevenantHostNSJSONSerialization \
    -c "$FOUNDATION/NSJSONSerialization.m" -o "$BUILD/port/NSJSONSerialization.o"
xcrun clang -fobjc-arc $quiet "$here/differential.m" "$BUILD/port/NSJSONSerialization.o" -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
