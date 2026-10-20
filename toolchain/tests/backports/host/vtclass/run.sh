#!/bin/sh
# THIS SUITE COMPARES THE CLASSES: the class exists, it conforms to the protocol the SDK declares, and each accessor is spelled as the SDK spells it and lives where the SDK puts it. The sibling videotoolbox/run.sh compares the 135 STRING CONSTANTS, which are values rather than shapes.
# run.sh — a host differential for the port's VideoToolbox classes: the class exists, it conforms to the
# protocol the SDK declares, every accessor is spelled the SDK spells it, and each accessor lives WHERE
# the SDK declares it — on the class for a class property, on the instance otherwise. One mutation per
# covered class must change a record, and the mutation is the one the family is most likely to make: a
# class property that becomes an instance method, or the reverse.
#
# It is a shape comparison and not a value one, and the reason is measured rather than chosen: the
# host's VideoToolbox refuses dimensions it does not support — its own documentation says
# initWithFrameWidth: returns nil for them — so neither side can be put into a state where a value
# could be compared. What the host can be asked about is the shape, and that is what compare.py holds
# the port to.
#
# covered.txt says which classes the comparison asks about, so each class lands in it in the commit
# that adds the class. mutants.txt carries one mutation per covered class, in the file that class owns —
# one class per file is what makes each mutation's anchor unique, so mutate.py can insist on it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
# The lists the run asks about come from the environment when it is given them, so a driver can ask about
# a class that is not committed yet WITHOUT writing the class into the committed lists first. A class that
# fails its differential must leave no trace that would make the next run skip it - which is exactly what
# appending to covered.txt before the commit did, and it cost four classes a run to find.
covered=${VTCLASS_COVERED:-$here/covered.txt}
gen=$(runs_folder generated/vt)

# the generated table roundtrip-cases.h, which cases-roundtrip.m includes
appledir=${APPLEDIR:-$here/../../../../packages/a/apple-backports}
vt="$appledir/VideoToolbox"
# 0. THE PACKAGE RECIPE MUST PARSE, and this differential cannot see it: it compiles the value files
#    itself and never loads the recipe, so a recipe with a syntax error leaves the whole family green.
#    The light guard is the only check that loads it, and it found exactly that - a missing comma in
#    table.join, introduced by a rebase resolution, invisible here for eleven commits. So the guard runs
#    FIRST and its exit code is checked; a recipe that does not parse turns this run red.
light_tests=${LIGHT_TESTS:-$HOME/Git/projects/ios/coordination/run_light_tests.lua}
if [ "${VT_SKIP_LIGHT:-0}" != "1" ] && [ -f "$light_tests" ]; then
# The repository root, not $PWD: the sweep runs every run.sh from tests/backports, so $PWD there is
# tests/backports and `xmake l run_light_tests.lua` cannot find its modules - it said "cannot import
# module: descriptions_test, not found!" and the run died there, before any SDK was looked for.
    xmake l "$light_tests" "$root" || {
        echo "the package recipe does not load, and this differential cannot see that: exit 1 above is"
        echo "descriptions_test, and the value files below were compiled without it"
        exit 1
    }
fi

build=${BUILD:-$(runs_fresh revenant-vtclass)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
libs="-framework Foundation -framework CoreMedia -framework VideoToolbox"

# 0. the port's DECLARATIONS against SDK 26.2's own headers, before anything is compiled: a selector, an
#    argument count or a type that disagrees with the SDK is found here rather than by a caller, and the
#    initialiser of VTMotionBlurConfiguration was declared with four arguments where the SDK declares five
#    for twenty-six commits before anything noticed.
VT_SDK=${VT_SDK:-$(runs_sdk)}
if [ ! -d "$VT_SDK" ]; then
    echo "FAIL: VT_SDK is $VT_SDK, which is not a folder, so there are no VideoToolbox headers to compare the port's declarations against"
    exit 1
fi
export VT_SDK
echo "sdk: $VT_SDK"
rm -f "$gen/roundtrip-cases.h" "$gen/mutants.tsv"
xmake l "$here/probe_types.lua" || exit 1
[ -s "$here/type-branches.tsv" ] || { echo "the committed type-branches.tsv is missing, and the generator reads that one"; exit 1; }
xmake l "$here/emit.lua" "$VT_SDK" || exit 1
for generated in roundtrip-cases.h mutants.tsv summary.json; do
    [ -s "$gen/$generated" ] || { echo "emit.py produced no $generated"; exit 1; }
done
echo "provisioned: $(wc -l < "$here/type-branches.tsv" | tr -d ' ') types, $(wc -l < "$gen/mutants.tsv" | tr -d ' ') mutants"

# 0b. cases.m is the table compare.lua holds the port to, and it is GENERATED: gen_cases.lua writes it from the
#     SDK's own headers. Nothing else checked that the committed copy still says what the generator says, so a
#     hand-edited or stale cases.m would be the table the comparison trusted. It is regenerated here, into this
#     run's folder, and compared byte for byte with the committed file.
xmake l "$here/gen_cases.lua" "$VT_SDK" > "$build/cases.generated.m" || { echo "gen_cases.lua failed to write cases.m"; exit 1; }
cmp -s "$build/cases.generated.m" "$here/cases.m" || { echo "cases.m is not what gen_cases.lua generates from the SDK - regenerate it, do not edit it"; exit 1; }

# The anchors are GENERATED, from the same emission that produced the accessors, and a stale hand-written
# one is how all sixteen mutants came to report as survivors. The generated list wins when it is there.
if [ -z "${VTCLASS_MUTANTS:-}" ] && [ -f "$gen/mutants.tsv" ]; then
    mutants=$gen/mutants.tsv
else
    mutants=${VTCLASS_MUTANTS:-$here/mutants.txt}
fi

xmake l "$here/check_declarations.lua" "$VT_SDK" --quiet
# A NAME IN NEITHER TABLE must be refused, and the refusal is run here rather than left to a reader:
# DECLARED_KEYS is the only way past the check that a property exists, so it is where a generator's own
# mistake would hide, and a control that is only ever run by hand is a control that is not run.
xmake l "$here/decoy_test.lua" || { echo "the decoy name was accepted"; exit 1; }

# 1. the host's own VideoToolbox
# every build's exit status is checked, and the binary is removed first: a run.sh that reuses the last
# build's binary after a compile failed answers with the PREVIOUS comparison and reports it as this one's
rm -f "$build/system" "$build/port"
xcrun clang $common -I"$here" "$here/record.m" "$here/cases.m" "$here/cases-roundtrip.m" -I"$gen" $libs -o "$build/system"
VTCLASS_COVERED="$covered" VTCLASS_RECORDS="$build/system.json" "$build/system"
echo "the host answered: $(xmake l "$here/count_records.lua" "$build/system.json")"

# 2. the port's own build, every class under names of its own
xmake l "$here/rename.lua" "$build/rename.h"
xcrun clang $common -DREVENANT_HOST_DIFFERENTIAL=1 -DREVENANT_VT_DECLARE_FOR_CASE=1 -include "$build/rename.h" -I"$here" -I"$vt" \
    "$here/record.m" "$here/cases.m" "$here/cases-roundtrip.m" -I"$gen" "$vt"/*.m $libs -o "$build/port"
VTCLASS_COVERED="$covered" VTCLASS_RECORDS="$build/port.json" "$build/port"
for side in system port; do
    # every covered class must have contributed its records; a run that stopped early is a red answer
    for cls in $(cat "$covered"); do
        key="class.$cls"
        grep -q "\"$key\"" "$build/$side.json" || {
            echo "$side: no record for $key - the build lost the class before it was asked anything"
            exit 1
        }
    done
done
xmake l "$here/compare.lua" "$build/system.json" "$build/port.json" "$here/cases.m"

# 3. one mutation per covered class. A mutation that does not apply is an error, not a pass, and a
#    mutation whose records are unchanged is a survivor: the comparison did not see it.
survived=0
while IFS="$(printf '\t')" read -r cls file from to; do
    [ -n "$cls" ] || continue
    grep -qx "$cls" "$covered" || continue
    label="$cls: $from -> $to"
    rm -rf "$build/mutant"
    mkdir -p "$build/mutant"
    cp "$vt"/*.m "$build/mutant/"
    if ! xmake l "$here/mutate.lua" "$build/mutant/$file" "$from" "$to" >/dev/null; then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        continue
    fi
    if ! xcrun clang $common -DREVENANT_HOST_DIFFERENTIAL=1 -DREVENANT_VT_DECLARE_FOR_CASE=1 -include "$build/rename.h" -I"$here" \
        -I"$build/mutant" -I"$vt" "$here/record.m" "$here/cases.m" "$here/cases-roundtrip.m" -I"$gen" "$build/mutant"/*.m $libs \
        -o "$build/mutant/run" >"$build/mutant/compile.log" 2>&1; then
        echo "MUTANT DID NOT COMPILE: $label"
        tail -5 "$build/mutant/compile.log"
        survived=$((survived + 1))
        continue
    fi
    rm -f "$build/mutant.json"
    VTCLASS_COVERED="$covered" VTCLASS_RECORDS="$build/mutant.json" timeout 90 "$build/mutant/run" >/dev/null 2>&1 || true
    if cmp -s "$build/port.json" "$build/mutant.json"; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        xmake l "$here/caught_lines.lua" "$build/port.json" "$build/mutant.json"
    fi
done < "$mutants"

if [ "$survived" -ne 0 ]; then
    echo "$survived mutations survived"
    exit 1
fi
# WHAT WAS ACTUALLY MUTATED, AND WHAT WAS NOT. The verdict above says whether every mutation that ran was
# caught; it says nothing about the classes that had no mutation to run, and a class with no mutant looks
# exactly like a class that passed. So: per class, what was caught, and the classes with nothing - by NAME,
# compared against a checked-in list that this run fails against if it GROWS.
xmake l "$here/mutant_summary.lua" "$build/port.json" "$build/mutant.json" "$mutants" "$here/covered.txt" "$here/mutants-expected.txt"
echo "mutations: all caught"
