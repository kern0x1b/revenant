#!/bin/sh
# run.sh - runs the installer of packages/a/apple-backports/UIKit/UIViewController+TransitionCoordinator.m, the file
# itself and not a copy, against the host's UIKit under Mac Catalyst, a release that has its own UIPresentationController
# and so takes the branch a device from 8.0 on takes (revenant_release_presents() is YES here and dead code on 6.1.3). What
# the port's sheet class does is not on the host (the host has its own class of that name); the recorder stands in for the
# one thing the installer asks of it, and the host's own sheet is the presentation controller the handover gives. It holds:
# a controller is asked for its sheet only when it is presented as one (a page or form sheet from a compact width), the
# release presents it through the handover (the style is put back, the caller's delegate is asked for the animators first
# and is back after the dismissal), and the sheet a dismissal took away is not kept, by whichever route the dismissal came:
# the controller's own, or an ancestor's that takes it down with it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
device=$here/../../device
build=${BUILD:-$(runs_fresh revenant-sheethandover)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-w"
app="$build/handover.app"
mkdir -p "$app/Contents/MacOS"
# The category the file carries (transitioningDelegate and transitionCoordinator, which UIKit has) is attached the way a
# band attaches it, only where the release lacks the selector, and not over the host's.
xcrun clang -fobjc-arc $target $quiet -I"$uikit" -c "$uikit/UIViewController+TransitionCoordinator.m" -o "$build/installer.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__revenant_catlist/g' "$build/installer.o"
xcrun clang -fobjc-arc $target $quiet -I"$uikit" -I"$device" "$here/record.m" "$here/stubs.m" "$device/check.m" "$uikit/RevenantTransitionCoordinator.m" \
    "$here/../foundation2/host-attach.c" "$build/installer.o" -framework UIKit -framework Foundation -framework QuartzCore -framework CoreGraphics -o "$app/Contents/MacOS/app"
cp "$here/record.plist" "$app/Contents/Info.plist"
codesign -s - --force "$app" > /dev/null 2>&1
timeout 60 "$app/Contents/MacOS/app" 2>&1 | grep -v '^20[0-9][0-9]-' | tee "$build/handover.log"
grep -q '^checks=' "$build/handover.log" && ! grep -q '^FAIL' "$build/handover.log"
