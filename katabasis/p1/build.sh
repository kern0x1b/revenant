#!/bin/sh
set -eu
cd "$(dirname "$0")"
LAB=$HOME/Git/projects/ios/katabasis
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
LD=$(ls $HOME/.xmake/packages/l/ld64/956.6/*/bin/ld | head -1)
LLVM=/opt/homebrew/opt/llvm/bin
input=${1:-$LAB/corpus/out/bench-arm64}
name=$(basename "$input" -arm64)
out=out/$name
mkdir -p "$out"
xcrun dyld_info -imports "$input" | tail -n +3 | awk '{print $1}' > "$out/imports.txt"
"$LAB/xlate/build/xlgen" --sdk "$SDK" --resource-dir /opt/homebrew/opt/llvm/lib/clang/23 --includes includes.h \
  --symbols "$out/imports.txt" --guest-out "$out/guest.c" --host-out "$out/host.c" \
  --passthrough-out "$out/passthrough.txt" --report-out "$out/report.txt"
traps=$(grep -o 'xl_trap_[A-Za-z0-9_]*(' "$out/guest.c" | tr -d '(' | sort -u | sed 's/^/-Wl,-U,_/' | tr '\n' ' ')
xcrun clang -target arm64-apple-ios12.0 -isysroot "$SDK" -dynamiclib -O2 -fno-builtin -fno-stack-protector -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0 -w \
  -install_name @rpath/libxl-guest.dylib "$out/guest.c" -o "$out/libxl-guest.dylib" $traps
"$LAB/xlate/build/xlate" --output "$out/lifted.bc" --layout "$out/layout.txt" \
  --passthrough "$out/passthrough.txt" --state-header "$out/xl_state.h" --bridge "$out/libxl-guest.dylib" "$input" "$out/libxl-guest.dylib"
$LLVM/clang -target armv7-apple-ios6.0 -marm -O2 -c "$out/lifted.bc" -o "$out/lifted.o"
for source in "$LAB/runtime/runtime.c" "$LAB/runtime/bridge.c" "$out/host.c"; do
  $LLVM/clang -target armv7-apple-ios6.0 -marm -isysroot "$SDK" -O2 -w -I "$out" -I "$LAB/runtime" -c "$source" -o "$out/$(basename "$source" .c).o"
done
xcrun clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fuse-ld="$LD" -Wl,-no_pie $(cat "$out/layout.txt") \
  "$out/lifted.o" "$out/runtime.o" "$out/bridge.o" "$out/host.o" -o "$out/$name"
ldid -S "$out/$name"
file "$out/$name"
