#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
GRAPHICS=${GRAPHICS:-$here/../../../../packages/frameworks/apple-backports/Graphics}
BUILD=${BUILD:-$(runs_fresh revenant-cgmatch)}
renames="-DCGColorCreateCopyByMatchingToColorSpace=RevenantHostCGColorCreateCopyByMatchingToColorSpace"
xcrun clang -fobjc-arc -w $renames -c "$GRAPHICS/CGColorMatching9.m" -o "$BUILD/port.o"
xcrun clang -fobjc-arc -w "$here/differential.m" "$BUILD/port.o" -framework CoreGraphics -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
