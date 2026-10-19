#!/bin/bash
typecheck.sh ROOT: run SILGen over the SwiftUI module -- no codegen, no link. The fast loop while
editing, and unlike a plain -typecheck it catches what SILGen catches.
# typecheck.sh DIR: run SILGen over the SwiftUI module (no codegen, no link) - the fast loop while editing
set -e
cd "$1/eidolon"
ROOT=$(cd "$PWD/.." && pwd); O=$PWD/out
source $ROOT/pkg-env.sh
mkdir -p $O/mc
$SWIFTC $PKGFLAGS $OCFLAGS -module-cache-path $O/mc -enforce-exclusivity=unchecked -suppress-warnings \
  -emit-sil -parse-as-library -module-name SwiftUI Sources/SwiftUI/*.swift
echo "emit-sil ok"
