#!/bin/sh
# run.sh - what the system's UIKit does with a navigation controller that never asked for a toolbar, and with one that did, recorded in a
# Mac Catalyst application with a window (device/toolbar-cases.m); then the port's safe area files are compiled beside the same cases (their
# categories replace the system's methods of the same name) and held to the same records, with mutants that each have to be told apart.
# An application, not a process of its own: UIWindow needs UIApplicationMain behind it, as host/safeguide/run.sh does.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
uikit=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
build=${BUILD:-$(runs_fresh charon-toolbar)}
sdk=$(xcrun --show-sdk-path)
compile() {
    app=$1; shift
    mkdir -p "$app/Contents/MacOS"
    xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
        "$here/../uikit2/windowed.m" "$here/record.m" "$device/toolbar-cases.m" "$device/check.m" "$@" -framework UIKit -framework Foundation -framework CoreGraphics -o "$app/Contents/MacOS/app"
    cp "$here/../uikit2/windowed.plist" "$app/Contents/Info.plist"
    codesign -s - --force "$app" > /dev/null 2>&1
}
record() {
    app=$1; out=$2
    rm -f "$out"
    TOOLBAR_RECORDS="$out" "$app/Contents/MacOS/app" > "$out.log" 2>&1 || true
    [ -f "$out" ] || { echo "no records from $app; $out.log says why" >&2; cat "$out.log" >&2; exit 1; }
}
compile "$build/system.app"
record "$build/system.app" "$build/system.json"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/system.json'))))")"
cat "$build/system.json.log"

files="UIView+SafeArea.m UIViewController+SafeArea.m"
mkdir -p "$build/port"
for file in $files; do cp "$uikit/$file" "$build/port/$file"; done
compile "$build/port/port.app" "$build/port/UIView+SafeArea.m" "$build/port/UIViewController+SafeArea.m"
record "$build/port/port.app" "$build/port.json"
if cmp -s "$build/system.json" "$build/port.json"; then echo "port: same as the system"; else
    python3 - "$build/system.json" "$build/port.json" <<'PY'
import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
for key in sorted(a):
    if a[key] != b.get(key):
        print("DIFF", key)
        print("  system", a[key])
        print("  port  ", b.get(key))
PY
    echo "port: DIFFERS"; exit 1
fi

# A mutant of the safe area file has to differ from the system. The host's windows keep a toolbar out of the view tree, so a port that
# never reads the toolbar is the same as one that reads it here: that mutant is the device test's (shownToolbarIsTheBottomInset).
survived=0
mutant() {
    from=$1; to=$2
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$build/port/UIView+SafeArea.m" "$build/mutant/UIView+SafeArea.m"
    python3 - "$uikit/UIViewController+SafeArea.m" "$build/mutant/UIViewController+SafeArea.m" "$from" "$to" <<'PY'
import sys
source, target, old, new = sys.argv[1:5]
text = open(source).read()
assert text.count(old) == 1, old
open(target, "w").write(text.replace(old, new, 1))
PY
    compile "$build/mutant/mutant.app" "$build/mutant/UIView+SafeArea.m" "$build/mutant/UIViewController+SafeArea.m"
    rm -f "$build/mutant.json"
    TOOLBAR_RECORDS="$build/mutant.json" timeout 60 "$build/mutant/mutant.app/Contents/MacOS/app" > /dev/null 2>&1 || true
    if cmp -s "$build/system.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $from -> $to"; survived=$((survived + 1)); fi
}
mutant "navigation.toolbarHidden ? nil : navigation.toolbar" "navigation.toolbar"
mutant "navigation.toolbarHidden ? nil : navigation.toolbar" "navigation.toolbarHidden ? navigation.toolbar : nil"
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]

# What the device holds itself to: every record of the host's but the measured ones, which are numbers of one window.
python3 - "$build/system.json" "$build/expected.json" <<'PY'
import json, sys
records = json.load(open(sys.argv[1]))
json.dump({key: value for key, value in records.items() if not key.startswith("measured")}, open(sys.argv[2], "w"))
PY
xmake l "$here/../../common/embed.lua" "$build/expected.json" "$device/toolbar-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/toolbar_expectations/' "$device/toolbar-expectations.h" && rm -f "$device/toolbar-expectations.h.bak"
