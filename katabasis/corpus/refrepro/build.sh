#!/bin/sh
# build.sh — compile RefRepro to arm64, translate to armv7/iOS6, assemble the .app.
set -eu
cd "$(dirname "$0")"
LAB=$(cd ../.. && pwd)
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
out=out
mkdir -p "$out"

# 1. Native arm64 iOS executable (the "App Store" input; ARC, like OneBusAway, so ivar
#    stores compile to objc_storeStrong -- the release-of-old-ivar site that faulted).
xcrun clang -target arm64-apple-ios12.0 -isysroot "$SDK" -O2 -fobjc-arc -w \
  -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
  main.m -o "$out/RefRepro-arm64"

# 2. Translate to armv7/iOS 6.
cat "$LAB/p3/includes.h" > "$out/includes.h"
printf '#import <objc/runtime.h>\n' >> "$out/includes.h"
"$LAB/scripts/translate.sh" "$out/RefRepro-arm64" "$out/includes.h" "$out/xl"

# 3. Assemble the .app bundle.
app="$out/RefRepro-armv7.app"
rm -rf "$app"; mkdir -p "$app"
cp "$out/xl/RefRepro" "$app/RefRepro"
cp Info.plist "$app/Info.plist"
ldid -S "$app/RefRepro"
echo "built $app"
