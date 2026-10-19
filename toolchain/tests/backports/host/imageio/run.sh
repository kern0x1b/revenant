#!/bin/sh
# run.sh — runs device/imageio.m against the host's own ImageIO, so what the port is held to is what the system does.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
build=${BUILD:-$(runs_fresh charon-imageio)}
xcrun clang -DCHARON_HOST -fobjc-arc -w -I"$device" "$device/imageio.m" "$device/check.m" -framework ImageIO -framework CoreGraphics -framework Foundation -o "$build/imageio"
"$build/imageio"
