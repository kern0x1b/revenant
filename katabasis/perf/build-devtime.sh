#!/bin/sh
# build-devtime.sh — on-device wall-clock benchmark (translated vs native), a normal
# armv7 iOS CLI executable (links libSystem/libm), unlike the -nostdlib emulator harness.
set -eu
cd "$(dirname "$0")"
LAB=$HOME/Git/projects/ios/katabasis
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
LD=$(ls $HOME/.xmake/packages/l/ld64/956.6/*/bin/ld | head -1)
LLVM=/opt/homebrew/opt/llvm/bin
out=out
mkdir -p "$out"
FLAGS="-O2 -ffreestanding -fno-builtin -fno-stack-protector -fno-vectorize -fno-slp-vectorize"

# 1. Native arm64 kernels -> lifted armv7.
xcrun clang -target arm64-apple-ios12.0 -isysroot "$SDK" $FLAGS -dynamiclib -install_name @rpath/libkernels.dylib kernels.c -o "$out/kernels-arm64.dylib"
"$LAB/xlate/build/xlate" --output "$out/lifted.bc" --layout "$out/layout.txt" --state-header "$out/xl_state.h" "$out/kernels-arm64.dylib"
$LLVM/clang -target armv7-apple-ios6.0 -marm -O2 -c "$out/lifted.bc" -o "$out/lifted.o"

# 2. Generate kernel_addrs.h: guest address = nm(_k_<name>) + 0x10000000, in native_run order.
python3 - "$out/kernels-arm64.dylib" > "$out/kernel_addrs.h" <<'PY'
import subprocess, sys
order = ["crc32","sha256","fnv64","sort","list","geometry","matrix","text"]
val = {}
for line in subprocess.run(["nm","-gU",sys.argv[1]],capture_output=True,text=True).stdout.splitlines():
    p = line.split()
    if len(p) == 3 and p[2].startswith("_k_"):
        val[p[2][3:]] = int(p[0],16) + 0x10000000
print("// generated")
print("static const unsigned kernel_count = %d;" % len(order))
print("static const char *const kernel_names[] = {%s};" % ", ".join('"%s"'%k for k in order))
print("static const uint32_t kernel_addrs[] = {%s};" % ", ".join("0x%xu"%val[k] for k in order))
PY

# 3. Native kernels + dispatch + timing main.
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" $FLAGS -c kernels.c -o "$out/kernels-native.o"
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -O2 -c native_run.c -o "$out/native_run.o"
$LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -O2 -I "$out" -c devtime.c -o "$out/devtime.o"

# 4. Link a normal iOS executable: guest segments fixed at their vmaddrs (-no_pie + layout),
#    but with libSystem so mach_absolute_time / task_info / printf / libm work.
xcrun clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fuse-ld="$LD" -Wl,-no_pie $(cat "$out/layout.txt") \
  "$out/lifted.o" "$out/kernels-native.o" "$out/native_run.o" "$out/devtime.o" \
  -o "$out/devtime" 2>&1 | grep -v incompatible-sysroot || true
ldid -S "$out/devtime"
file "$out/devtime"
echo "built $out/devtime"
