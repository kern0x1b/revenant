#!/bin/sh
# assets-extract.sh — builds assets-extract on first use and runs it: assets-extract.sh [--scales 1,2,3] CATALOGUE OUTPUT-FOLDER
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cache=${CHARON_ASSETS_EXTRACT_CACHE:-${TMPDIR:-/tmp}/charon-assets-extract}
tool="$cache/assets-extract"
if [ ! -x "$tool" ] || [ "$here/assets-extract.m" -nt "$tool" ]; then
    mkdir -p "$cache"
    xcrun clang -isysroot "$(xcrun --show-sdk-path)" -fobjc-arc -Wall -Wno-deprecated-declarations "$here/assets-extract.m" \
        -framework Foundation -framework CoreGraphics -framework ImageIO -framework UniformTypeIdentifiers -o "$tool"
fi
exec "$tool" "$@"
