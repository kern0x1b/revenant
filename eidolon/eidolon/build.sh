#!/bin/bash
# build.sh: Eidolon (module SwiftUI) + EidolonDemo, EidolonTests, EidolonProbe for armv7 iOS 6 against the charon@swift-runtime and charon@styx ../rtpkg requires, from the shared xmake store, staged as out/EidolonDemo.app
set -e
cd "$(dirname "$0")"
ROOT=$PWD/..; O=$PWD/out
source $ROOT/pkg-env.sh
SWFLAGS="$PKGFLAGS $OCFLAGS -module-cache-path $O/mc -enforce-exclusivity=unchecked -suppress-warnings -O"
# the count of invented names comes from the module built below (bridge/api-surface.sh), so it is compared afterwards by a plain --check
xmake l coverage.lua --check --before-build
rm -rf $O/obj $O/mods; mkdir -p $O/obj $O/mods
$SWIFTC $SWFLAGS -parse-as-library -wmo -module-name SwiftUI -emit-module -emit-module-path $O/mods/SwiftUI.swiftmodule \
  -c Sources/SwiftUI/*.swift -o $O/obj/SwiftUI.o
echo "built SwiftUI"
# the two typecheck gates: each resolves eidolon/out/mods and exits non-zero on failure
"$PWD/tools/tabletests/run.sh"
"$PWD/tools/tabtests/run.sh"
$LLVM/bin/clang -target armv7-apple-ios -miphoneos-version-min=6.0 -isysroot $SDK -fobjc-arc -Wno-deprecated-declarations -c Demo/device/gesture.m -o $O/obj/gesture.o
$SWIFTC $SWFLAGS -parse-as-library -wmo -module-name EidolonDemo -I $O/mods -import-objc-header Demo/device/bridge.h -c Demo/*.swift -o $O/obj/EidolonDemo.o
echo "built Demo"
$SWIFTC $SWFLAGS -disable-availability-checking -wmo -module-name EidolonTests -I $O/mods -c Tests/*.swift -o $O/obj/EidolonTests.o
echo "built Tests"
$SWIFTC $SWFLAGS -wmo -module-name EidolonProbe -I $O/mods -c Probe/*.swift -o $O/obj/EidolonProbe.o
echo "built Probe"
A=$O/EidolonDemo.app; rm -rf $A; mkdir -p $A
bundle_runtime $A
link() {
  $LLVM/bin/clang -target armv7-apple-ios -miphoneos-version-min=6.0 -isysroot $SDK -mlinker-version=956.6 -fuse-ld=$LD -o $A/$1 \
    $O/obj/$1.o $O/obj/SwiftUI.o $2 $PKGLINK $OCLINK \
    ${3:-} -lobjc -framework Foundation -framework CoreFoundation -framework UIKit -framework CoreGraphics -framework QuartzCore -framework CoreData -framework CoreImage
}
# BACKPORTS_LIBS names a directory with the phone's libUIKitBackports and libFoundationBackports: the demo then weak-links them, so a phone that has the backports gives it their swipe actions and one that has not runs without
BACKPORTS=""; [ -n "${BACKPORTS_LIBS:-}" ] && BACKPORTS="-L$BACKPORTS_LIBS ${BACKPORTS_LINK:--weak-lUIKitBackports -weak-lFoundationBackports}"
link EidolonDemo $O/obj/gesture.o "$BACKPORTS"; link EidolonProbe; link EidolonTests
for f in EidolonDemo EidolonProbe EidolonTests; do relink_runtime $A/$f; done
cat > $A/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>EidolonDemo</string>
<key>CFBundleIdentifier</key><string>space.kern0x1b.eidolon.demo</string>
<key>CFBundleName</key><string>EidolonDemo</string>
<key>CFBundleDisplayName</key><string>Eidolon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>MinimumOSVersion</key><string>6.0</string>
<key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
<key>UIRequiredDeviceCapabilities</key><array><string>armv7</string></array>
<key>UISupportedInterfaceOrientations</key><array><string>UIInterfaceOrientationPortrait</string></array>
</dict></plist>
PLIST
plutil -convert binary1 $A/Info.plist
for f in $A/*.dylib $A/EidolonDemo $A/EidolonProbe $A/EidolonTests; do $LDID -S $f; done
ls $A | tr '\n' ' '; echo
