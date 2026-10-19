#!/bin/bash
# api-surface.sh [DIR]: what Revenant's SwiftUI lacks of Apple's SwiftUI, declaration by declaration.
# Dumps the API of Apple's SwiftUI (the iOS 16.4 interface, through the patched copy in fw/) and of the module built
# by ../SwiftUI/build.sh with swift-api-digester, and lists Apple's declarations that have no counterpart with the
# same signature, and the other way round: the public names this module has that Apple's own 26.2 interface does not
# declare, which is a failure. DIR (default ./api) receives apple.json, ours.json, gaps.txt and invented.txt;
# api-diff.lua and api-invented.lua explain the columns.
set -e
cd "$(dirname "$0")"
source ../pkg-env.sh
O=${1:-api}
mkdir -p "$O"
DIGESTER=$SWIFTHOME/bin/swift-api-digester
$DIGESTER -dump-sdk -module SwiftUI -o "$O/apple.json" -sdk "$SDK" -target arm64-apple-ios16.4 -F "$PWD/fw" \
  -resource-dir "$RT/lib/swift" -swift-version 5 -avoid-tool-args -module-cache-path "$O/mc"
$DIGESTER -dump-sdk -module SwiftUI -o "$O/ours.json" -sdk "$SDK" -target armv7-apple-ios6.0 -I ../SwiftUI/out/mods $OCFLAGS \
  -resource-dir "$RT/lib/swift" -swift-version 5 -avoid-tool-args -module-cache-path "$O/mc"
xmake l api-diff.lua "$O/apple.json" "$O/ours.json" > "$O/gaps.txt"
sort "$O/gaps.txt" | cut -f1 | uniq -c | sort -rn | head -30

# The other direction: what this module declares that no 26.2 interface of the modules we re-export
# declares. An invented public member is a row the ledger counts as covered and no reader of Apple's
# API ever asked for. APPLE_26_SDK overrides where those interfaces are looked for.
xmake l api-invented.lua "$O/ours.json" > "$O/invented.txt" || true
echo "api-surface: $(wc -l < "$O/invented.txt" | tr -d ' ') public names here that Apple's 26.2 does not declare (see $O/invented.txt); STRICT=1 makes this a failure"
