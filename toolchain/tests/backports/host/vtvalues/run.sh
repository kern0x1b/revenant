#!/bin/sh
# The strings the host's VideoToolbox gives the H.264 profile levels of iOS 7 and kVTDecompressionPropertyKey_RealTime,
# the values VideoToolbox/VideoToolbox7.m carries (facts/VideoToolbox/H264Encoding.md).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
BUILD=${BUILD:-$(runs_fresh revenant-vtvalues)}
xcrun clang -w "$here/values.m" -framework VideoToolbox -framework CoreFoundation -o "$BUILD/values"
"$BUILD/values"
