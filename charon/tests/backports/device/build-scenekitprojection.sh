#!/bin/sh
# Compiles one device test for the target, which no script in this tree did: tests/backports/README.md
# indexes the tests and what each needs built, and the gates build the backports, but nothing
# assembled the clang line for a test binary. This is that line for scenekitprojection.m, and the
# shape the others take.
#
# The toolchain is the store's own - the same 6.4.0 the package is built with - and the SDK is the
# 16.4 one the armv7 slices come from, which is what `-target armv7-apple-ios6.1.3` needs: a
# deployment target that old has no Swift, and the port supplies it.
#
# Nothing of the package is linked here on purpose: this test asks the *port's* SceneKit for its
# answers, and at compile time the interface is the system's, so what is being checked here is that
# the test compiles against the target at all. The binary that runs is linked against
# libSceneKitBackports and installed with `xmake emulate install`.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
# Three levels, not two: tests/backports/device is three below the repository root, and a short path
# writes the build into tests/ where nothing expects it and nothing sweeps it.
work=${WORK:-$here/../../../.agent-work/runs/device-scenekitprojection}
target=${TARGET:-armv7-apple-ios6.1.3}
sdk=${SDK:-$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk 2>/dev/null | head -1)}
cc=${CC:-$HOME/.xmake/packages/s/swift/6.4.0/f1d0e4f9eebe477396350986a88081e5/bin/clang}
[ -d "$sdk" ] || { echo "no 16.4 SDK found; set SDK="; exit 2; }
[ -x "$cc" ] || { echo "no store clang at $cc; set CC="; exit 2; }
mkdir -p "$work"
echo "$cc -target $target -isysroot $sdk -O -fobjc-arc -Wall -I$here \\"
echo "    $here/scenekitprojection.m $here/check.m \\"
echo "    -framework Foundation -framework QuartzCore -framework SceneKit -framework OpenGLES \\"
echo "    -o $work/scenekitprojection"
"$cc" -target "$target" -isysroot "$sdk" -O -fobjc-arc -Wall -I"$here" \
    "$here/scenekitprojection.m" "$here/check.m" \
    -framework Foundation -framework QuartzCore -framework SceneKit -framework OpenGLES \
    -o "$work/scenekitprojection"
echo "built $work/scenekitprojection for $target"
