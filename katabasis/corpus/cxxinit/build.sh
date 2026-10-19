#!/bin/sh
set -eu
cd "$(dirname "$0")"
LAB=$(cd ../.. && pwd)
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
out=out; mkdir -p "$out"
xcrun clang -target arm64-apple-ios12.0 -isysroot "$SDK" -O2 -fobjc-arc -w -x objective-c++ -std=c++14 \
  -framework UIKit -framework Foundation -framework CoreGraphics -lc++ main.mm -o "$out/CxxInit-arm64"
cat "$LAB/p3/includes.h" > "$out/includes.h"
"$LAB/scripts/translate.sh" "$out/CxxInit-arm64" "$out/includes.h" "$out/xl"
app="$out/CxxInit-armv7.app"; rm -rf "$app"; mkdir -p "$app"
cp "$out/xl/CxxInit" "$app/CxxInit"; cp Info.plist "$app/Info.plist"; ldid -S "$app/CxxInit"
echo "built $app"
