#!/bin/sh
# run.sh — records what the system's UICollectionViewFlowLayout lays out for every case of device/insetref-cases.m in a Mac Catalyst binary,
# writes the answers where the device test reads them, then compiles the port's flow layout beside them (its categories replace the
# system's methods of the same name) and holds it to the same records, with mutants of the port that each have to be told apart.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
uikit=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
build=${BUILD:-$(runs_fresh revenant-insetref)}
sdk=$(xcrun --show-sdk-path)
compile() {
    output=$1; shift
    xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
        "$here/record.m" "$device/insetref-cases.m" "$@" -framework UIKit -framework Foundation -framework CoreGraphics -o "$output"
}
compile "$build/system"
INSETREF_RECORDS="$build/system.json" "$build/system"
xmake l "$here/../../common/embed.lua" "$build/system.json" "$device/insetref-expectations.h" foundation2_expectations
sed -i.bak 's/foundation2_expectations/insetref_expectations/' "$device/insetref-expectations.h" && rm -f "$device/insetref-expectations.h.bak"
echo "records: $(python3 -c "import json; print(len(json.load(open('$build/system.json'))))")"

port="UICollectionViewFlowLayout+SelfSizing.m"
mkdir -p "$build/port"
cp "$uikit/$port" "$build/port/$port"
compile "$build/port/run" "$build/port/$port"
INSETREF_RECORDS="$build/port.json" "$build/port/run"
if cmp -s "$build/system.json" "$build/port.json"; then echo "port: same as the system"; else
    python3 - "$build/system.json" "$build/port.json" <<'PY'
import json, sys
a, b = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
for key in sorted(a):
    if a[key] != b.get(key):
        print("DIFF", key)
        print("  system", a[key][:300])
        print("  port  ", str(b.get(key))[:300])
PY
    echo "port: DIFFERS"; exit 1
fi

survived=0
mutant() {
    from=$1; to=$2
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    python3 - "$uikit/$port" "$build/mutant/$port" "$from" "$to" <<'PY'
import sys
source, target, old, new = sys.argv[1:5]
text = open(source).read()
assert old in text, old
open(target, "w").write(text.replace(old, new, 1))
PY
    compile "$build/mutant/run" "$build/mutant/$port"
    rm -f "$build/mutant.json"
    INSETREF_RECORDS="$build/mutant.json" timeout 60 "$build/mutant/run" > /dev/null 2>&1 || true
    if cmp -s "$build/system.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $from -> $to"; survived=$((survived + 1)); fi
}
mutant "inset.left = MAX(inset.left + against.left - adjusted.left, 0);" "inset.left = MAX(inset.left + against.left, 0);"
mutant "inset.right = MAX(inset.right + against.right - adjusted.right, 0);" "inset.right = MAX(inset.right - adjusted.right, 0);"
mutant "reference == 2 ? view.layoutMargins : view.safeAreaInsets" "reference == 1 ? view.layoutMargins : view.safeAreaInsets"
mutant "MAX(inset.left + against.left - adjusted.left, 0)" "inset.left + against.left - adjusted.left"
mutant "CGFloat width = view.bounds.size.width - adjustment.left - adjustment.right;" "CGFloat width = view.bounds.size.width - adjustment.left;"
mutant "return revenant_reference_kind(flow) != 0 &&" "return revenant_reference_kind(flow) == 1 &&"
mutant "layout.itemSize;" "CGSizeMake(50, 50);"
mutant "    if (reference == 0)
        return inset;" "    if (reference == 3)
        return inset;"
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]
