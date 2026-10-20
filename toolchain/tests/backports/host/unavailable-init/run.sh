#!/bin/sh
# run.sh - the -init and +new that the SDK 26.2 headers of these frameworks close with NS_UNAVAILABLE,
# held to what Apple's own class was measured to do about them.
#
#   1. probe.m asks the host's own framework, ONE CLASS PER PROCESS: is the selector in the class's own
#      method list (the corpus row's question), and what does a caller reach at run time (the behaviour).
#      One process per class because a class's -init can take the host down - measured, PKIdentityElement,
#      PKIdentityIntentToStore, PKIssuerProvisioningExtensionPassEntry and PKVehicleConnectionSession all
#      die with SIGSEGV when initialised directly - and a probe that stopped at the first of those would
#      answer one class and call it a measurement.
#   2. check-host.lua holds that against expectations.tsv, per framework, for the rows whose oracle is the
#      host. A difference means the oracle moved, which is the one thing the table exists to notice.
#   3. check-port.lua holds the PORT to the same table, per framework: where Apple's class defines a
#      selector, the class's @implementation block must answer with the macro the table names and the
#      compiled object must carry it; where Apple's class carries neither, the block must not define it
#      and the object must not carry it.
#   4. the plants, each of which must turn step 3 red, and the check's own control.
#
# A framework with no host binary at all - HomeKit, whose directory holds only PlugIns - has no host half
# and its rows carry `ios16` as their oracle: the arm64e cache of iOS 16.0, which is a real release's own
# metadata and answers the row's question. There is NO test on the framework path before the probe runs,
# on purpose: this OS ships these frameworks out of the dyld shared cache and there is no file under
# /System/Library/Frameworks/<F>.framework/<F> at all (measured 2026-10-03: the binary comes from the
# cache, the symlink dangles, and dlopen of the same path succeeds). dlopen is the question.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
charon=${REVENANT:-$here/../../../..}
charon=$(cd "$charon" && pwd)
appledir="$charon/packages/frameworks/apple-backports"
build=${BUILD:-$(runs_fresh revenant-unavailable-init)}
mkdir -p "$build"
survived=0

store="${XMAKE_GLOBALDIR:-$HOME/.revenant/cache/xmake-global}/.xmake/packages"
cc=$(ls -d "$store"/l/llvm/*/*/bin/clang 2>/dev/null | head -1)
sdk=${BP_SDK:-$(ls -d "$store"/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk 2>/dev/null | head -1)}
if [ -z "$cc" ] || [ -z "$sdk" ]; then
    echo "FAIL no pinned toolchain: expected clang under the shared xmake store's llvm package and the"
    echo "     iPhoneOS 16.4 SDK the port builds against (BP_SDK, or the iphoneos-sdk package in that store)."
    exit 1
fi

# The frameworks, the classes and the sources and objects to check are the table's rows, not a list
# written twice. A framework named on the command line wins over the table's own set.
runs_xmake l "$here/prepare.lua" "$here/expectations.tsv" "$build" "$@"

echo "--- the host's own frameworks, one class per process, and the table each is held to"
xcrun clang -fobjc-arc -w "$here/probe.m" -framework Foundation -o "$build/probe"
for framework in $(cat "$build/frameworks"); do
    binary="/System/Library/Frameworks/$framework.framework/$framework"
    : > "$build/$framework.host"
    while read -r class; do
        [ -n "$class" ] || continue
        if ! echo "$class" | timeout 10 "$build/probe" "$binary" > "$build/one.out" 2>&1; then
            echo "CLASS $class did not survive the host: Apple's own class, asked directly"
        fi
        cat "$build/one.out" >> "$build/$framework.host"
    done < "$build/$framework.classes"
    runs_xmake l "$here/check-host.lua" "$framework" "$build/$framework.host"
done

echo "--- the port: the source, the macro's own body, and the compiled armv7 objects"
for framework in $(cat "$build/frameworks"); do
    mkdir -p "$build/objects/$framework"
    for source in $(cat "$build/$framework.sources"); do
        "$cc" -target armv7-apple-ios6.1.3 -isysroot "$sdk" -I "$appledir" \
            -I "$appledir/$framework" -fobjc-arc -c "$appledir/$source" \
            -o "$build/objects/$framework/$(basename "$source").o" > "$build/cc.log" 2>&1 ||
            { echo "COMPILE FAILED for $source:"; cat "$build/cc.log"; exit 1; }
    done
    runs_xmake l "$here/check-port.lua" "$appledir" "$build/objects/$framework" "$charon" "$framework"
done

# A plant is the port's own tree with one line changed, compiled and asked again. The framework, the file
# and the needle come from plants.lua, which reads them out of the table, so a plant always applies to a
# row that exists.
plant() {
    label=$1; framework=$2; file=$3; from=$(printf '%b' "$4"); to=$(printf '%b' "$5")
    : > "$build/mutant-cc.log"
    rm -rf "$build/mutant"
    mkdir -p "$build/mutant/$framework"
    # Every header of the package and of the framework's own folder, rather than a list of the ones one
    # framework happened to need: a plant that does not build because a header was left behind proves
    # nothing, and the list is what left it behind (measured: RevenantHomeKitConstants.h).
    for header in "$appledir"/*.h; do cp "$header" "$build/mutant/"; done
    for header in "$appledir/$framework"/*.h; do cp "$header" "$build/mutant/$framework/"; done
    for source in $(cat "$build/$framework.sources"); do cp "$appledir/$source" "$build/mutant/$framework/"; done
    # plants.lua writes a newline as the two characters \n so that one plant is one line of its output, so
    # both halves are turned back into newlines above (printf %b) before the first needle is replaced.
    if ! runs_xmake l "$here/../../common/substitute.lua" first "$build/mutant/$framework/$file" "$from" "$to"
    then
        echo "MUTATION DID NOT APPLY: $label"
        survived=$((survived + 1))
        return
    fi
    built=$build/mutant/objects
    mkdir -p "$built"
    ok=1
    for source in $(cat "$build/$framework.sources"); do
        "$cc" -target armv7-apple-ios6.1.3 -isysroot "$sdk" -I "$build/mutant" \
            -I "$build/mutant/$framework" -fobjc-arc -c "$build/mutant/$framework/$(basename "$source")" \
            -o "$built/$(basename "$source").o" >> "$build/mutant-cc.log" 2>&1 ||
            { echo "=== $source" >> "$build/mutant-cc.log"; ok=0; }
    done
    if [ "$ok" = 0 ]; then
        echo "MUTANT DID NOT BUILD, which is not the same as being noticed: $label"
        grep -m 2 ": error:" "$build/mutant-cc.log" | cut -c1-140 | sed 's/^/  /'
        survived=$((survived + 1))
        return
    fi
    if runs_xmake l "$here/check-port.lua" "$build/mutant" "$built" "$charon" "$framework" \
        > "$build/mutant.out" 2>&1; then
        echo "MUTANT SURVIVED: $label"
        survived=$((survived + 1))
    else
        echo "  caught: $(grep -m 1 '^FAIL' "$build/mutant.out" | cut -c1-110)"
    fi
}

echo "--- the plants"
while IFS="$(printf '\t')" read -r label framework file from to; do
    [ -n "${label:-}" ] || continue
    plant "$label" "$framework" "$file" "$from" "$to"
done <<PLANTS
$(runs_xmake l "$here/plants.lua" "$here/expectations.tsv" "$appledir" $(cat "$build/frameworks"))
PLANTS

echo "--- the check's own control: an object carrying neither selector must not look green"
# The control needs a framework that owes a selector; HomeKit's twenty rows all say `none`, so for it
# there is nothing an empty object could contradict, and the control runs against one that owes. `nil` owes
# as much as `raise` does - the object's list has to carry the selector either way, which is the half of the
# check an empty object contradicts - so both count.
# Only among the frameworks THIS run built, which a subset run is: the control copies the objects of the
# framework it picks, and picking one this run did not build is a cp of nothing (measured: asking for
# AVFoundation alone picked HealthKit, whose objects were not built, and the control never ran).
control=$(awk -F'\t' -v built=" $(tr '\n' ' ' < "$build/frameworks")" \
    '($10 == "raise" || $10 == "nil") && index(built, " " $1 " ") { print $1; exit }' \
    "$here/expectations.tsv")
victim=$(awk -F'\t' -v f="$control" 'NR > 1 && $1 == f && ($10 == "raise" || $10 == "nil") { print $NF; exit }' \
    "$here/expectations.tsv")
: > "$build/empty.o"
rm -rf "$build/empty"
mkdir -p "$build/empty"
cp "$build/objects/$control"/*.o "$build/empty/"
cp "$build/empty.o" "$build/empty/$victim"
if runs_xmake l "$here/check-port.lua" "$appledir" "$build/empty" "$charon" "$control" > "$build/empty.out" 2>&1; then
    echo "FAIL an object with no -init was accepted"
    survived=$((survived + 1))
else
    echo "  caught: $(grep -m 1 '^FAIL' "$build/empty.out" | cut -c1-110)"
fi

if [ "$survived" -ne 0 ]; then echo "$survived plants survived; this check proves nothing"; exit 1; fi
classes=$(cat "$build"/*.classes | grep -c .)
echo "unavailable-init: OK - $classes classes over $(tr '\n' ' ' < "$build/frameworks"), every plant noticed, the control red"
