#!/bin/bash
# stage-pkg.sh: link the armv7 test runner against the charon@swift-runtime ../rtpkg requires (shared xmake store), @executable_path install names, sign
set -e
cd "$(dirname "$0")"
ROOT=$PWD/..; O=$PWD/out-pkg; S=$O/stage
source $ROOT/pkg-env.sh
rm -rf $S; mkdir -p $S
bundle_runtime $S
$LLVM/bin/clang -target armv7-apple-ios -miphoneos-version-min=6.0 -isysroot $SDK -mlinker-version=956.6 -fuse-ld=$LD -o $S/${NAME:-octests} \
  ${OBJS:-$O/obj/*.o} $PKGLINK -lobjc -framework Foundation -framework CoreFoundation ${LINKEXTRA}
relink_runtime $S/${NAME:-octests}
for f in $S/*; do $LDID -S $f; done
ls $S | tr '\n' ' '; echo
