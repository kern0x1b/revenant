#!/bin/bash
ourdump.sh ROOT: swift-api-digester dump of the module this tree builds, at .agent-work/api/ours.json.
The ours side of the API diff; the Apple side is the 26.2 interface, read by tools/slice-diff.lua.
# ourdump.sh DIR: swift-api-digester dump of the module this tree builds - the ours side of the API diff.
set -e
cd "$1/eidolon"
ROOT=$PWD/..; O=$PWD/out
cd "$ROOT"
source ./pkg-env.sh
mkdir -p .agent-work/api
"$SWIFTHOME/bin/swift-api-digester" -dump-sdk -module SwiftUI -o .agent-work/api/ours.json -sdk "$SDK" \
  -target armv7-apple-ios6.0 -I "$O/mods" $OCFLAGS -resource-dir "$RT/lib/swift" -swift-version 5 \
  -avoid-tool-args -module-cache-path .agent-work/api/mc
echo "ours.json written"
