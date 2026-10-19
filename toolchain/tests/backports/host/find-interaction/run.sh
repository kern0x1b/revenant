#!/bin/sh
# run.sh: a differential of UIFindInteraction in a bundled Mac Catalyst app with the iPad idiom and a key window: the interaction's state, the
# delegate's conversation (the session asked for on present, the begin and end callbacks, the navigator's visibility, the active session), the
# text it keeps, and the values of its sessions. The host app is app/main.m alone. The port app adds the port's UIFindInteraction.m,
# UIFindSession.m, UITextSearchingFindSession.m and UIView+Interactions.m, with the classes renamed to RevenantPort<name>. Each app writes its
# checks to a file, and the two files must be the same line for line. The text view's own find interaction is host-only evidence
# (REVENANT_HOST_ONLY_OUT), not compared, since the port does not build it yet. FIND_INTERACTION_PORT_SOURCES replaces the port's files, so a
# planted wrong port can be run as a control: it must fail.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=$here/../../../../packages/a/apple-backports/UIKit
build=${FIND_INTERACTION_BUILD:-$(runs_fresh revenant-find-interaction)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
if [ -n "${FIND_INTERACTION_PORT_SOURCES:-}" ]; then
    port_sources=$FIND_INTERACTION_PORT_SOURCES
else
    port_sources="$uikit/UIFindInteraction.m $uikit/UIFindSession.m $uikit/UITextSearchingFindSession.m $uikit/UIView+Interactions.m"
fi
renames=$(grep -h '^@implementation ' $port_sources | grep -v '(' | awk '{ print "-D" $2 "=RevenantPort" $2 }' | sort -u)
plist="$here/app/Info.plist"
for side in host port; do
    bundle="$build/$side/RevenantFindInteraction.app"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$plist" "$bundle/Contents/Info.plist"
    if [ "$side" = host ]; then
        xcrun clang $common "$here/app/main.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/RevenantFindInteraction"
    else
        # shellcheck disable=SC2086
        xcrun clang $common $renames -DREVENANT_PORT_SIDE "$here/app/main.m" $port_sources \
            -framework UIKit -framework Foundation -framework CoreGraphics -o "$bundle/Contents/MacOS/RevenantFindInteraction"
    fi
    codesign -s - --force --deep "$bundle" > /dev/null 2>&1
    REVENANT_SCENE_OUT="$build/$side.txt" REVENANT_HOST_ONLY_OUT="$build/$side.host-only.txt" timeout 120 "$bundle/Contents/MacOS/RevenantFindInteraction" > "$build/$side.log" 2>&1 || true
done
if [ ! -s "$build/host.txt" ] || [ ! -s "$build/port.txt" ]; then
    echo "FAIL find-interaction: an app wrote no checks (see $build/*.log)"
    exit 1
fi
cut -f2- "$build/host.txt" > "$build/host.cut"
cut -f2- "$build/port.txt" > "$build/port.cut"
checks=$(wc -l < "$build/host.cut" | tr -d ' ')
if diff "$build/host.cut" "$build/port.cut" > "$build/diff.txt"; then
    echo "ok find-interaction: $checks checks, the port's UIFindInteraction answers as the host's does"
else
    echo "FAIL find-interaction: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
