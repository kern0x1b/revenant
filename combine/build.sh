#!/bin/bash
# build.sh host|pkg (pkg, also "ios": armv7 iOS 6 against the charon@swift-runtime ../rtpkg requires, from the shared xmake store): OpenCombine + OpenCombineDispatch + OpenCombineFoundation + tests (with the XCTest shim) into out-<mode>/
set -e
cd "$(dirname "$0")"
MODE=${1:-host}; [ "$MODE" = ios ] && MODE=pkg; ROOT=$PWD/..; SRC=$ROOT/src/OpenCombine; O=$PWD/out-$MODE
rm -rf $O; mkdir -p $O/mods $O/obj $O/sg $O/mc
X=$HOME/.xmake/packages
if [ $MODE = host ]; then
  SWIFTC=/usr/bin/swiftc; T=arm64-apple-macosx13.0
  SWFLAGS="-target $T -module-cache-path $O/mc"
  CXX="/usr/bin/clang++ -target $T"
  SDKFLAGS=""
elif [ $MODE = pkg ]; then
  source $ROOT/pkg-env.sh
  SWFLAGS="$PKGFLAGS -module-cache-path $O/mc -enforce-exclusivity=unchecked ${EXTRA_SWIFT_FLAGS:-}"
  CXX="$LLVM/bin/clang++ -target armv7-apple-ios6.0 -isysroot $SDK -nostdinc++ -isystem $LIBCXX/include/c++/v1"
fi
OPT=${OPT:--O}; TESTOPT=$([ $MODE = host ] && echo -Onone || echo -O); SWFLAGS="$SWFLAGS -suppress-warnings"
H=$SRC/Sources/COpenCombineHelpers
$CXX -std=c++17 -O2 -include exception -Wno-incompatible-sysroot -I $H/include -c $H/COpenCombineHelpers.cpp -o $O/obj/COpenCombineHelpers.o
lib() { # name dir extra
  local n=$1 d=$2; shift 2
  $SWIFTC $SWFLAGS $OPT -parse-as-library -enable-testing -wmo -module-name $n -I $H/include -I $O/mods "$@" \
    -emit-module -emit-module-path $O/mods/$n.swiftmodule -c $(find $d $([ -d extra-$MODE/$n ] && echo extra-$MODE/$n) -name '*.swift' | sort) -o $O/obj/$n.o
  echo "built $n"
}
lib OpenCombine $SRC/Sources/OpenCombine
lib OpenCombineDispatch $SRC/Sources/OpenCombineDispatch
FOUNDATION=$SRC/Sources/OpenCombineFoundation
if [ $MODE = pkg ]; then
  FOUNDATION=$O/src/OpenCombineFoundation; mkdir -p $O/src; cp -R $SRC/Sources/OpenCombineFoundation $FOUNDATION
  rm $FOUNDATION/URLSession.swift
  xmake l patch-portability.lua $FOUNDATION/Helpers/Portability.swift
fi
lib OpenCombineFoundation $FOUNDATION
lib XCTest xctest
TESTS=$(find $SRC/Tests/OpenCombineTests -name '*.swift' | sort | grep -v "${TESTEXCLUDE:-^$}")
if [ $MODE = pkg ]; then
  TESTS=$(echo "$TESTS" | grep -v 'URLSessionTests.swift')
  SWFLAGS="$SWFLAGS -disable-availability-checking"
fi
$SWIFTC $SWFLAGS $TESTOPT -parse-as-library -wmo -module-name OpenCombineTests -I $H/include -I $O/mods -D Xcode \
  -emit-module -emit-module-path $O/sg/OpenCombineTests.swiftmodule -emit-symbol-graph -emit-symbol-graph-dir $O/sg \
  -symbol-graph-minimum-access-level private $TESTS 2>&1 | grep -E "error:" | head -40 || true
xmake l gentests.lua $O/sg/OpenCombineTests.symbols.json $O/main.swift
$SWIFTC $SWFLAGS $TESTOPT -wmo -module-name OpenCombineTests -I $H/include -I $O/mods -D Xcode -c $TESTS $O/main.swift -o $O/obj/OpenCombineTests.o 2>&1 | grep -E "error:" | head -40 || true
echo "built tests"
