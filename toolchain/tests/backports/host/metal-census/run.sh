#!/bin/sh
# run.sh - the host differential for MetalKit's carried family.
#
# What runs here and what does not is written down rather than discovered:
#
#   * The ROW FLIP runs, and it is the port's own function: this test #includes the port's
#     MTKTextureLoader9.m rather than copying the flip out of it, because a copy would be a test of
#     the copy. It is checked against a reference flip written out longhand in the test - the rows
#     swapped end for end, one byte at a time. A flip that mirrored instead, or that dropped the
#     middle row of an odd height, differs from the reference and nothing else in the port notices.
#   * The ZONE ARITHMETIC is checked as the port's rule, stated in the test: windows in order, none
#     overlapping, and the first request that does not fit answers nil, which is what
#     MDLMeshBufferAllocator's own words require ("Returns nil the buffer could not be allocated in
#     the zone given").
#   * The loader's METHODS do not run here, and the zone and buffer OBJECTS are not made: they need an
#     EAGL context and a device. This is the same wall tests/backports/host/metalblit/run.sh writes
#     down, and it is answered the same way - the part that is pure runs here, and the rest is held to
#     the device test. Nothing here fakes a device to get past it.
#
# The binary carries two MTKTextureLoader classes - the port's and the system's, because
# `#import <MetalKit/MetalKit.h>` auto-links the framework - and clang says so at startup. It does not
# affect what is checked: the flip is a static function in the port's own translation unit, so the one
# under test is the port's whichever class wins the name.
#
# Why the flip is worth a test at all: MTKTextureLoaderOriginTopLeft and
# MTKTextureLoaderOriginFlippedVertically both end in this function, and a texture loaded upside down
# is wrong in a way no compiler and no row count will report.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
METALKIT=${METALKIT:-$here/../../../../packages/frameworks/apple-backports/MetalKit}
BUILD=${BUILD:-$(runs_fresh revenant-metal-census)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"

# MetalKit is named on the link line because the header alone did not link it. The comment above
# says `#import <MetalKit/MetalKit.h>` auto-links the framework, which it does with modules on;
# this harness compiles the translation unit without them, so the two MTKTextureLoaderCubeLayout
# constants the port's own texture loader reads came back as `Undefined symbols
# _MTKTextureLoaderCubeLayoutVertical, _MTKTextureLoaderOptionCubeLayout` - and both are declared
# (MTKTextureLoader.h:91 and :94) and exported by the SDK's own stub, measured.
xcrun clang $target -fobjc-arc -Wno-incomplete-implementation -Wno-unguarded-availability-new \
    -I"$METALKIT" -include "$METALKIT/MTKTextureLoader9.m" \
    -o "$BUILD/mesh-differential" "$here/mesh-differential.m" \
    -framework Foundation -framework CoreGraphics -framework UIKit -framework Metal -framework MetalKit
"$BUILD/mesh-differential"
