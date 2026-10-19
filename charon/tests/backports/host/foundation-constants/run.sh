#!/bin/sh
# run.sh — every exported string constant the package carries for iOS 17.0, 18.2 and 26.0, compared
# against the host's own Foundation, with one mutant per constant.
#
#     sh tests/backports/host/foundation-constants/run.sh [--mutation]
#
# ONE clang line builds the probe TOGETHER with the port's three objects, the way
# tests/backports/host/security/run-cases.sh and metal-census/stitch.sh do it: two objects cannot be
# linked when one is built for the device and the other for the host, and the failure reads as a
# missing main rather than a mismatched architecture. The probe's own values are the linked
# definitions and the host's come from dlsym on the Foundation image, so neither side can be the
# other's copy.
#
# The values were read from the host's own Foundation and are in
# facts/Foundation/NSURLResourceKeyStrings.md; this run is what notices a value that is not the one a
# release ships, and a mutant per constant is what shows it can.
#
# --mutation runs the fourteen mutations, one per constant: each builds a copy of one object with
# that one value broken and the run has to go red naming that constant. A mutant that does not build
# counts as RUN FAILED, never as noticed, and the run says which.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
S="$root/packages/a/apple-backports"
work=${WORK:-$root/.agent-work/runs/foundation-constants}
rm -rf "$work"
mkdir -p "$work"

sdk=$(xcrun --show-sdk-path --sdk macosx)
# arm64-apple-macabi: the port's sources compiled for the host, which is the only way a differential
# can measure the port's own code rather than Apple's.
flags="-target arm64-apple-ios15.0-macabi -isysroot $sdk -fobjc-arc -O0 -Wall -Wno-unguarded-availability-new -I$S -I$S/Foundation"
objects="FoundationIdentifiers17 FoundationIdentifiers18 FoundationIdentifiers26"
names_to_prove="NSFileProtectionCompleteWhenUserInactive NSHTTPCookieSetByJavaScript \
NSCalendarIdentifierBangla NSCalendarIdentifierDangi NSCalendarIdentifierGujarati \
NSCalendarIdentifierKannada NSCalendarIdentifierMalayalam NSCalendarIdentifierMarathi \
NSCalendarIdentifierOdia NSCalendarIdentifierTamil NSCalendarIdentifierTelugu \
NSCalendarIdentifierVietnamese NSCalendarIdentifierVikram \
NSURLUbiquitousItemIsSyncPausedKey NSURLUbiquitousItemSupportedSyncControlsKey"
count_to_prove=$(printf '%s\n' $names_to_prove | grep -c .)

sources=""
for name in $objects; do sources="$sources $S/Foundation/$name.m"; done

build() {
    clang $flags "$here/probe.m" $sources -o "$work/probe"
}
build
echo "=== the port's own definitions are in the binary, not Apple's"
# A count, not an address: an address can be a dylib's, a defined count cannot. This is what stops
# the comparison below from silently reading macOS's own copies of all fourteen names.
for name in $names_to_prove; do
    if ! nm -g "$work/probe" | awk '{print $3}' | grep -qx "_$name"; then
        echo "FAIL $name is not defined in this binary: the port's object was not linked" >&2
        exit 1
    fi
done
echo "all $count_to_prove names are defined in the binary"

echo "=== the values the package carries, against the host's own Foundation"
"$work/probe" | tee "$work/values.txt"
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "FAIL: the values do not agree with the host's Foundation (exit $rc)" >&2
    exit 1
fi

echo "=== the control: a run that compares nothing must refuse"
if "$work/probe" --none > "$work/none.txt" 2>&1; then
    echo "FAIL: a run that compared nothing passed" >&2
    exit 1
fi
tail -1 "$work/none.txt"

if [ "${1:-}" = "--mutation" ]; then
    echo "=== one mutant per constant: each must go red naming itself"
    failed=0
    names=$(awk '/^ok /{print $2}' "$work/values.txt" | grep -v CharonProbe || true)
    count=$(printf '%s\n' "$names" | grep -c . || true)
    for name in $names; do
        object=""
        for candidate in $objects; do
            if grep -q " $name = " "$S/Foundation/$candidate.m"; then object=$candidate; break; fi
        done
        [ -n "$object" ] || { echo "RUN FAILED $name: no object defines it"; failed=1; continue; }
        mutant="$work/mutant-$name.m"
        sed "s/ $name = @\"[^\"]*\"/ $name = @\"charon-mutant\"/" "$S/Foundation/$object.m" > "$mutant"
        if ! grep -q "charon-mutant" "$mutant"; then
            echo "RUN FAILED $name: the mutation changed nothing in $object.m" >&2
            failed=1
            continue
        fi
        others=""
        for candidate in $objects; do
            [ "$candidate" = "$object" ] || others="$others $S/Foundation/$candidate.m"
        done
        if ! clang $flags "$here/probe.m" "$mutant" $others -o "$work/mutant-$name" > "$work/mutant-$name.build" 2>&1; then
            echo "RUN FAILED $name: the mutant does not build (see $work/mutant-$name.build)" >&2
            failed=1
            continue
        fi
        if "$work/mutant-$name" > "$work/mutant-$name.txt" 2>&1; then
            echo "NOT NOTICED $name: the mutant still agreed with the host" >&2
            failed=1
            continue
        fi
        if ! grep -q "FAIL $name" "$work/mutant-$name.txt"; then
            echo "NOT NOTICED $name: it went red without naming it (see $work/mutant-$name.txt)" >&2
            failed=1
            continue
        fi
        echo "noticed $name: $(grep -m1 "^FAIL $name" "$work/mutant-$name.txt" | cut -c1-120)"
    done
    echo "mutants: $count, failures: $failed"
    [ "$failed" -eq 0 ] || exit 1
fi
echo "PASS: the values agree with the host's own Foundation"
