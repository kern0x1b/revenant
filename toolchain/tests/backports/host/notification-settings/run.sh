#!/bin/sh
# run.sh: a differential of UNNotificationSettings, read from UNUserNotificationCenter's getNotificationSettings in a bundled Mac Catalyst app
# that has never asked for authorization. The host app is app/main.m alone. The port app adds the port's UNUserNotificationCenter.m with its two
# classes renamed to RevenantPort<name>, so the host's classes are still the ones the center is. Each app writes its checks to a file, and the
# two files must be the same line for line. NOTIFICATION_SETTINGS_PORT_SOURCES replaces the port's file, so a planted wrong port can be run as
# a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/frameworks/apple-backports/UIKit
build=${NOTIFICATION_SETTINGS_BUILD:-$(runs_fresh revenant-notification-settings)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${NOTIFICATION_SETTINGS_PORT_SOURCES:-}" ]; then
    port_sources=$NOTIFICATION_SETTINGS_PORT_SOURCES
else
    port_sources="$uikit/UNUserNotificationCenter.m"
fi
# The region monitor is the harness's stub in every build: the port's own is compiled from a file that Mac Catalyst does not build.
port_sources="$port_sources $here/app/region-monitor-stub.m"
# The Catalyst build compiles copies of the port's sources, made here in the build directory and never in the product tree. Mac Catalyst has no
# UNLocationNotificationTrigger (the SDK marks it unavailable), so the copy writes the class literal of the location-trigger check as
# NSClassFromString: the same answer where the class exists. The product source keeps the literal.
mkdir -p "$build/catalyst"
catalyst_sources=""
for f in $port_sources; do
    copy="$build/catalyst/$(basename "$f")"
    sed 's/\[UNLocationNotificationTrigger class\]/NSClassFromString(@"UNLocationNotificationTrigger")/g' "$f" > "$copy"
    if grep -q '\[UNLocationNotificationTrigger class\]' "$copy"; then
        echo "FAIL notification-settings: the Catalyst copy of $f still has the class literal"
        exit 1
    fi
    catalyst_sources="$catalyst_sources $copy"
done
renames=$(grep -h '^@implementation ' $catalyst_sources | grep -v '(' | awk '{ print "-D" $2 "=RevenantPort" $2 }' | sort -u)
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/RevenantNotificationSettings.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        # shellcheck disable=SC2086
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework UserNotifications -framework CoreLocation -framework CoreGraphics \
            -o "$bundle/Contents/MacOS/RevenantNotificationSettings"
    else
        # shellcheck disable=SC2086
        xcrun clang $common $renames -DREVENANT_PORT_SIDE "$here/app/main.m" $catalyst_sources \
            -framework UIKit -framework Foundation -framework UserNotifications -framework CoreLocation -framework CoreGraphics \
            -o "$bundle/Contents/MacOS/RevenantNotificationSettings"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    REVENANT_SCENE_OUT="$build/$side.txt" timeout 120 "$bundle/Contents/MacOS/RevenantNotificationSettings" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL notification-settings: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok notification-settings: $checks checks, the port's UNNotificationSettings answers as the host's does"
else
    echo "FAIL notification-settings: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
