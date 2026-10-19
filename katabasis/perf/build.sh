#!/bin/sh
set -eu
cd "$(dirname "$0")"
LAB=$HOME/Git/projects/ios/katabasis
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
LD=$(ls $HOME/.xmake/packages/l/ld64/956.6/*/bin/ld | head -1)
RT=$(for f in $HOME/.xmake/packages/c/compiler-rt/23.1.1/*/lib/libgcc_s.1.a; do lipo -archs "$f" | grep -qx armv7 && echo "$f" && break; done)
LLVM=/opt/homebrew/opt/llvm/bin
OPT=${OPT:--O2}
mkdir -p out
FLAGS="$OPT -ffreestanding -fno-builtin -fno-stack-protector -fno-vectorize -fno-slp-vectorize"
xcrun clang -target arm64-apple-ios12.0 -isysroot "$SDK" $FLAGS -dynamiclib -install_name @rpath/libkernels.dylib kernels.c -o out/kernels-arm64.dylib
"$LAB/xlate/build/xlate" --output out/lifted.bc --layout out/layout.txt --state-header out/xl_state.h out/kernels-arm64.dylib
$LLVM/clang -target armv7-apple-ios6.0 -marm -O2 -c out/lifted.bc -o out/lifted.o
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -O2 -fno-builtin -I out -c harness.c -o out/harness.o
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" $FLAGS -c kernels.c -o out/kernels-native.o
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -O2 -c native_run.c -o out/native_run.o
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" $FLAGS -c kernels_wide.c -o out/kernels-wide.o
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -O2 -c native_wide_run.c -o out/native_wide_run.o
xcrun clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fuse-ld="$LD" -static -nostdlib -Wl,-e,_xlate_run -Wl,-no_pie $(cat out/layout.txt) \
  out/lifted.o out/harness.o out/kernels-native.o out/native_run.o out/kernels-wide.o out/native_wide_run.o "$RT" -o out/perf 2>&1 | grep -v incompatible-sysroot || true
nm out/perf | grep -E " T _k_| T _xlate_run| D _xl_functions| S _xl_functions| T _sub_" | head -40
