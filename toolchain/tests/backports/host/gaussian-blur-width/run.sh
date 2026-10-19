#!/bin/sh
# run.sh - Apple's MPSImageGaussianBlur on the macOS host: the nonzero extent of its impulse response over sigma.
#
# The width is not a property of the object (MPSImageGaussianBlur has no kernelWidth), so it is read from the
# output of a blur of one impulse. This host can encode the blur (the legacy queue path returns Completed), which is
# why the measurement exists here at all. The sweep prints "sigma half-width centre-weight edge-weight" for sigma
# 0.1 to 12.0 in steps of 0.1. The result is NOT a closed form: the half-width is not monotone in sigma, so the port
# does not compute a width from sigma. See facts/MetalPerformanceShaders/GaussianBlur.md.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
BUILD=${BUILD:-$(runs_fresh revenant-gaussian-blur-width)}
xcrun clang -O -fobjc-arc "$here/sweep.m" -framework Foundation -framework Metal -framework MetalPerformanceShaders -o "$BUILD/sweep"
"$BUILD/sweep"
