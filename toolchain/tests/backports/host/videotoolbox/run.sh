#!/bin/sh
# THIS SUITE COMPARES THE 135 STRING CONSTANTS. The sibling vtclass/run.sh compares the CLASSES - the class, its conformance, and where each accessor lives. Two suites, two questions, and both are needed: a constant is a value and a class is a shape.
# run.sh — a host differential for VideoToolbox's 135 string constants, one check per constant.
#
# The host's VideoToolbox exports all 135 and implements them, so its value is the value. The port's
# file is compiled into the same binary with its names renamed, and compare.lua requires the two to agree
# character for character. This is the check the values were measured with and the check that would
# catch a value written from a rule.
#
# The release is not the oracle and cannot be: its 6.1.3 armv7 cache was copied from a running
# device and 3709 of its pages hold slid pointers, which is why tools/corpus/cache-value.lua cannot read it, and
# the host's own cache is a 753KB stub. See facts/VideoToolbox/VideoToolbox.md.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
build=${BUILD:-$(runs_fresh revenant-videotoolbox)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
libs="-framework Foundation -framework CoreMedia -framework VideoToolbox"

xcrun clang $common -I"$here" "$here/record.m" "$here/cases.m" $libs -o "$build/system"
VIDEOTOOLBOX_RECORDS="$build/system.json" "$build/system"
echo "the host answered: $(xmake l "$here/records.lua" count "$build/system.json")"

xmake l "$here/rename.lua" "$build/rename.h" "$here/names.txt"
xcrun clang $common -DREVENANT_VIDEOTOOLBOX_PORT=1 -include "$build/rename.h" -I"$here" -I"$appledir/VideoToolbox" \
    "$here/record.m" "$here/cases.m" "$appledir"/VideoToolbox/VideoToolboxConstants*.m $libs -o "$build/port"
VIDEOTOOLBOX_RECORDS="$build/port.json" "$build/port"
xmake l "$here/compare.lua" "$build/system.json" "$build/port.json"

# The checks the ladder and the registry hold, which no run called before. The generated cases.m is what the ladder says;
# every constant sits in the object of its release (check-constant-files, its control on a copy in $build); the availability
# reader reads the generator's declarations table, and no header text. place-by-ladder then places the committed table into a scratch copy of the objects and
# the registry: the objects come back byte for byte, the registry holds the same rows in the same files (order aside), and
# a second placement changes nothing. The tree itself is only read.
xmake l "$here/gen-constant-cases.lua" --check
xmake l "$here/check-constant-files.lua" --control "$build/constant-files"
xmake l "$here/availability.lua"
rm -rf "$build/committed" "$build/placed" "$build/placed-once"
mkdir -p "$build/committed/objects" "$build/committed/registry" "$build/placed/objects" "$build/placed/registry"
cp "$appledir"/VideoToolbox/VideoToolboxConstants*.m "$build/committed/objects/"
cp "$appledir"/VideoToolbox/VideoToolboxConstants*.m "$build/placed/objects/"
cp "$appledir"/registry/VideoToolbox/*.json "$build/committed/registry/"
cp "$appledir"/registry/VideoToolbox/*.json "$build/placed/registry/"
xmake l "$here/place-by-ladder.lua" --into "$build/placed/objects" "$build/placed/registry" > "$build/place.out"
diff -r "$build/committed/objects" "$build/placed/objects"
echo "  place-by-ladder: the constant objects come back byte for byte from the committed table"
xmake l "$here/place-by-ladder.lua" --same-rows "$build/committed/registry" "$build/placed/registry"
cp -R "$build/placed" "$build/placed-once"
xmake l "$here/place-by-ladder.lua" --into "$build/placed/objects" "$build/placed/registry" > /dev/null
diff -r "$build/placed-once" "$build/placed"
echo "  place-by-ladder: a second placement changes nothing"

# a mutation of the port's file must change a record: one value made into the constant's own name,
# which is the mistake this whole family is measured against
survived=0
mutant() {
    label=$1; from=$2; to=$3
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$appledir"/VideoToolbox/VideoToolboxConstants*.m "$build/mutant/"
    holder=$(grep -l -F -- "$from" "$build"/mutant/VideoToolboxConstants*.m | head -n 1)
    if [ -z "$holder" ] || ! xmake l "$here/mutate.lua" "$holder" "$from" "$to" >/dev/null; then
        echo "MUTATION DID NOT APPLY: $label"; survived=$((survived + 1)); return
    fi
    xcrun clang $common -DREVENANT_VIDEOTOOLBOX_PORT=1 -include "$build/rename.h" -I"$here" -I"$build/mutant" \
        "$here/record.m" "$here/cases.m" "$build"/mutant/VideoToolboxConstants*.m $libs -o "$build/mutant/run"
    rm -f "$build/mutant.json"
    VIDEOTOOLBOX_RECORDS="$build/mutant.json" timeout 90 "$build/mutant/run" >/dev/null 2>&1 || true
    if cmp -s "$build/port.json" "$build/mutant.json"; then
        echo "MUTANT SURVIVED: $label"; survived=$((survived + 1))
    else
        xmake l "$here/records.lua" diff "$build/port.json" "$build/mutant.json"
    fi
}
mutant "one value becomes the constant's own name" \
    "CFSTR(\"PremultipliedAlpha\");" \
    "CFSTR(\"kVTAlphaChannelMode_PremultipliedAlpha\");"
if [ "$survived" -ne 0 ]; then echo "$survived mutations survived"; exit 1; fi
echo "mutations: all caught"
