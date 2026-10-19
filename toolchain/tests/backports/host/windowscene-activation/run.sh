#!/bin/sh
# run.sh: a differential of the three window-scene activation value classes, UIWindowSceneActivationConfiguration,
# UIWindowSceneActivationRequestOptions and UIWindowSceneActivationAction, the port against the Mac Catalyst host's own
# classes in one process. Each port class is compiled under its own name (-D renames it), so the host's class is still
# reached by name at run time. test.m prints the same checks for both sides; the run passes when they print the same values.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ports=${WINDOWSCENE_PORT_DIR:-$here/../../../../packages/a/apple-backports/UIKit}
build=${WINDOWSCENE_BUILD:-$(runs_fresh revenant-windowscene-activation)}
sdk=$(xcrun --show-sdk-path)
app="$build/windowscene-activation"
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -w \
    -DUIWindowSceneActivationConfiguration=RevenantPortUIWindowSceneActivationConfiguration \
    -DUIWindowSceneActivationRequestOptions=RevenantPortUIWindowSceneActivationRequestOptions \
    -DUIWindowSceneActivationAction=RevenantPortUIWindowSceneActivationAction \
    "$ports/UIWindowSceneActivationConfiguration.m" "$ports/UIWindowSceneActivationRequestOptions.m" "$ports/UIWindowSceneActivationAction.m" \
    "$here/test.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app"
codesign -s - --force "$app" > /dev/null 2>&1
"$app" > "$build/windowscene-activation.txt"
awk -F '\t' '$1 == "host" {print $2 "\t" $3}' "$build/windowscene-activation.txt" > "$build/host.txt"
awk -F '\t' '$1 == "port" {print $2 "\t" $3}' "$build/windowscene-activation.txt" > "$build/port.txt"
checks=$(wc -l < "$build/host.txt" | tr -d ' ')
if [ "$checks" -eq 0 ]; then
    echo "FAIL windowscene-activation: no checks ran"
    exit 1
fi
if [ "$checks" -ne "$(wc -l < "$build/port.txt" | tr -d ' ')" ]; then
    echo "FAIL windowscene-activation: the two sides printed different numbers of checks"
    exit 1
fi
if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
    echo "ok windowscene-activation: $checks checks, the port answers as the host does"
else
    echo "FAIL windowscene-activation: the port and the host differ"
    cat "$build/diff.txt"
    exit 1
fi
