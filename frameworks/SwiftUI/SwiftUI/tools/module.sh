#!/bin/bash
module.sh ROOT: emit only the SwiftUI module -- no codegen, no link, no probe. The two typecheck
pairs compile their snippets against out/mods/SwiftUI.swiftmodule, so this is the loop before a
full build.
# module.sh DIR: emit only the SwiftUI module -- no codegen, no link, no probe. The two typecheck gates
# compile their snippets against out/mods/SwiftUI.swiftmodule, so this is the light loop before a full build.
set -e
ROOT=$1
O=$ROOT/eidolon/out
cd "$ROOT"
source ./pkg-env.sh
mkdir -p "$O/mods" "$O/mc"
"$SWIFTC" $PKGFLAGS $OCFLAGS -module-cache-path "$O/mc" -enforce-exclusivity=unchecked -suppress-warnings \
  -wmo -parse-as-library -module-name SwiftUI -emit-module -emit-module-path "$O/mods/SwiftUI.swiftmodule" \
  "$O"/../Sources/SwiftUI/*.swift
echo "module emitted"
