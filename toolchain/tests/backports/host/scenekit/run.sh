#!/bin/sh
# Records macOS SceneKit's answers for the matrix functions, a node's rotation conventions and SCNView's defaults
# into device/scenekit-expectations.h, which tests/backports/device/scenekit.m holds the port to.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
DEVICE=${DEVICE:-$here/../../device}
BUILD=${BUILD:-$(runs_fresh charon-scenekit)}
EXPECTATIONS=${EXPECTATIONS:-$DEVICE/scenekit-expectations.h}
mkdir -p "$BUILD"
xcrun swiftc -O "$here/oracle.swift" -o "$BUILD/oracle"
"$BUILD/oracle" "$BUILD/expectations.json"
xmake l "$here/../../common/embed.lua" "$BUILD/expectations.json" "$EXPECTATIONS" foundation2_expectations
sed -i '' 's/foundation2_expectations/scenekit_expectations/' "$EXPECTATIONS"
echo "wrote $EXPECTATIONS"
