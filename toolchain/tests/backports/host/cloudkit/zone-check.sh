#!/bin/bash
echo "FAIL host/cloudkit/zone-check.sh: its Python steps are gone and not yet ported to Lua: compare.py; the inline block PY at line 115; the inline block PY at line 173" >&2
exit 1
# The zone differential's own check, and the only thing that attests it.
#
# It runs FIVE things, and the first two exist because a change to this family that passes only the
# first two has not been checked:
#
#   1. every CloudKit source compiles for the port's own target - armv7-apple-ios6.1.3 against the 16.4
#      device SDK. The port compiles against headers that have no CKRecordZoneEncryptionScope and no
#      encryptionScope, while the host harness compiles against 26.2 headers that have both, so a
#      declaration written for one sysroot is a redefinition or an unknown type on the other. That is not
#      a hypothetical: this series shipped it once.
#   2. the host harness builds and links with no CloudKit framework.
#   3. the UNPLANTED comparison reads no difference, through compare.py, over binaries built here from a
#      cleared directory.
#   4. the PLANTED control fires - a plant in a scratch copy, never in a tracked file, with a sentinel
#      symbol checked in the linked binary BEFORE the plant is allowed to count, so a stale link fails
#      loudly instead of quietly reporting the previous answer.
#   5. the operation initializers are read out of the host's own CloudKit and compared with the answers
#      the facts record - a different question from the three above, which are all about values - and
#      its own control fires, on the recorded answer this time.
#
# A check that cannot fail is not evidence, so a script that only did 1 and 2 would be claiming a
# comparison it never ran. It runs all five and exits non-zero if any of them does not hold.
#
#     bash tests/backports/host/cloudkit/zone-check.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../common/runs.sh" "$HERE"
cd "$HERE/../../../.." || exit 1
CL=packages/a/apple-backports/CloudKit
INC="-I packages/a/apple-backports -I $CL"
WARN="-Werror=objc-missing-property-synthesis"
WORK=$(runs_folder revenant-zone-check)
HOST_SDK=$(xcrun --show-sdk-path --sdk macosx)
fails=0

# The 16.4 SDK is picked by asking the store for an iPhoneOS16.4 and taking the first candidate that
# really is one, by its own SDKSettings.json. A hardcoded digest is a path that stops existing.
# The SDK the port's own target is measured against. CHARKIT_SDK_16 names one, as the message below
# always promised; without it the shared store's iPhoneOS 16.4 is found by the path its recipe lays
# down - .../16.4/<digest>/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs
# /iPhoneOS16.4.sdk - which the glob here did not spell, so it matched nothing and the first stage of
# this check reported "no 16.4 SDK with an SDKSettings.json naming it" over an SDK that is installed.
sdk16=${CHARKIT_SDK_16:-}
for candidate in "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk; do
    if [ -n "$sdk16" ]; then break; fi
    if [ -f "$candidate/SDKSettings.json" ] &&
       grep -q '"CanonicalName":"iphonesimulator16.4"\|"CanonicalName":"iphoneos16.4"' "$candidate/SDKSettings.json"; then
        sdk16="$candidate"; break
    fi
done

echo "== 1. the port's own target, armv7-apple-ios6.1.3 against iPhoneOS16.4 =="
if [ -z "$sdk16" ]; then
    echo "  no 16.4 SDK with an SDKSettings.json naming it; set CHARKIT_SDK_16 to one"
    fails=$((fails + 1)); sdk16=""
else
    echo "  SDK: $sdk16"
    n=0; bad=0
    for f in $CL/*.m; do
        n=$((n + 1))
        if ! xcrun clang -target armv7-apple-ios6.1.3 -isysroot "$sdk16" -fobjc-arc -Wall \
                $WARN -fsyntax-only $INC "$f" 2>"$WORK.err"; then
            bad=$((bad + 1)); echo "  FAIL $(basename "$f")"; head -2 "$WORK.err"
        fi
    done
    echo "  $n sources, $((n - bad)) exit 0, $bad non-zero"
    [ "$bad" -ne 0 ] && fails=$((fails + 1))
fi

echo "== 2. the host harness, no framework linked =="
rm -rf "$WORK"; mkdir -p "$WORK/obj" "$WORK/plant"
for f in $CL/*.m; do
    xcrun clang -c -target arm64-apple-ios13.1-macabi -isysroot "$HOST_SDK" -fobjc-arc \
        $INC -o "$WORK/obj/$(basename "${f%.m}").o" "$f" 2>/dev/null
done
# CKRecords10.o is beside CKRecords8.o and not optional: CKRecord's 10.0 half - the parent, the share
# and the two wrappers that build one - is in that object and CKRecords8.m forwards to it, so the class
# is one object and the two halves of it (see CloudKit/CKRecords10.m).
link_port() {   # $1 = the CKRecords8 object to use, $2 = the binary
    xcrun clang -target arm64-apple-ios13.1-macabi -isysroot "$HOST_SDK" -fobjc-arc \
        -framework Foundation -framework CoreLocation $INC -I tests/backports/host/cloudkit \
        -o "$2" tests/backports/host/cloudkit/zone-port.m tests/backports/host/cloudkit/database-cases.m \
        "$1" "$WORK/obj/CKConstants8.o" "$WORK/obj/CKRecords10.o" 2>"$WORK.link.log"
}
if link_port "$WORK/obj/CKRecords8.o" "$WORK/zone-port"; then
    echo "  exit 0, binary $(stat -f %z "$WORK/zone-port") bytes"
else
    echo "  FAIL the link:"; head -4 "$WORK.link.log"; fails=$((fails + 1))
fi
xcrun clang -target arm64-apple-ios13.1-macabi -isysroot "$HOST_SDK" \
    -framework Foundation -framework CloudKit -o "$WORK/host" \
    tests/backports/host/cloudkit/database-host.m tests/backports/host/cloudkit/database-cases.m \
    2>"$WORK.host.log" || { echo "  FAIL the host build:"; head -3 "$WORK.host.log"; fails=$((fails + 1)); }

echo "== 3. the unplanted comparison, through compare.py =="
if [ -x "$WORK/zone-port" ] && [ -x "$WORK/host" ]; then
    CLOUDKIT_DATABASE="$WORK/host.json" "$WORK/host" >/dev/null 2>&1
    CLOUDKIT_ZONE="$WORK/port.json" "$WORK/zone-port" >/dev/null 2>&1
    out=$(python3 tests/backports/host/cloudkit/compare.py "$WORK/host.json" "$WORK/port.json" 2>&1)
    code=$?
    echo "$out" | sed 's/^/  /'
    if [ "$code" -ne 0 ]; then
        echo "  FAIL the unplanted comparison must read no difference"; fails=$((fails + 1))
    fi
else
    echo "  skipped: a binary is missing"; fails=$((fails + 1))
fi

echo "== 4. the planted control, in a scratch copy, sentinel checked first =="
if [ -x "$WORK/zone-port" ]; then
    cp $CL/CKRecords8.m "$WORK/plant/CKRecords8.m"
    python3 - "$WORK/plant/CKRecords8.m" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
zone = text.index("@implementation CKRecordZone {")
at = text.index("- (BOOL)isEqual:(id)other", zone)      # inside CKRecordZone, not CKRecordZoneID's
text = text[:at] + "int RevenantPlantMarker = 1;\n\n- (NSInteger)capabilities { return 7; }\n\n" + text[at:]
open(path, "w").write(text)
PY
    xcrun clang -c -target arm64-apple-ios13.1-macabi -isysroot "$HOST_SDK" -fobjc-arc \
        $INC -o "$WORK/plant/CKRecords8.o" "$WORK/plant/CKRecords8.m" 2>"$WORK.plant.log" \
        || { echo "  FAIL the scratch copy did not compile"; fails=$((fails + 1)); }
    if link_port "$WORK/plant/CKRecords8.o" "$WORK/zone-planted" &&
       nm "$WORK/zone-planted" 2>/dev/null | grep -q RevenantPlantMarker; then
        CLOUDKIT_ZONE="$WORK/port-planted.json" "$WORK/zone-planted" >/dev/null 2>&1
        out=$(python3 tests/backports/host/cloudkit/compare.py "$WORK/host.json" "$WORK/port-planted.json" 2>&1)
        code=$?
        echo "  the sentinel IS in the linked binary, so the link is not stale"
        echo "$out" | grep -E "^[0-9]+ differ|differ:" | sed 's/^/  /'
        if [ "$code" -eq 0 ]; then
            echo "  FAIL the planted control did not fire - the comparison is not sensitive"
            fails=$((fails + 1))
        else
            echo "  the control fired: the comparison catches a wrong answer"
        fi
    else
        echo "  FAIL the planted link or the sentinel: a stale link would report the previous answer"
        fails=$((fails + 1))
    fi
else
    echo "  skipped: the port binary is missing"; fails=$((fails + 1))
fi

echo "== 5. the operation initializers, against the host's own CloudKit, with its own control =="
# A different question from the four above: the zone differential compares values, and the operation
# initializers are refusals and instantiations, which the zone cases never reach. The answers are the
# host's own, recorded beside each case in initializers-host.m, so this stage is what makes the
# measurement in facts/CloudKit/Values.md reproducible and a host that changes its mind go red.
#
# The CONTROL here is on the recorded answer rather than on a value: a scratch copy of the cases file
# with one expectation changed has to go red and name that case. Without it a case list that no longer
# matches the framework would read green, because a program that prints what it finds decides nothing
# about what it should have found.
build_initializers() {   # $1 = the cases file, $2 = the binary
    xcrun clang -target arm64-apple-ios13.1-macabi -isysroot "$HOST_SDK" -fobjc-arc -Wall \
        -framework Foundation -framework CloudKit -o "$2" "$1" 2>"$WORK.init.log"
}
if build_initializers tests/backports/host/cloudkit/initializers-host.m "$WORK/init-host"; then
    out=$(DYLD_FRAMEWORK_PATH="$HOST_SDK/System/iOSSupport/System/Library/Frameworks" \
          "$WORK/init-host" 2>&1)
    code=$?
    echo "$out" | grep -E '^#|^ +CK(Operation|Share|Database|Modify|Fetch|Query|Accept|Discover)' | sed 's/^/  /'
    if [ "$code" -ne 0 ]; then
        echo "  FAIL the host's own answer is not the one the facts hold"; fails=$((fails + 1))
    else
        echo "  ok the host answers every case the way facts/CloudKit/Values.md records"
    fi
    cp tests/backports/host/cloudkit/initializers-host.m "$WORK/plant/initializers-planted.m"
    python3 - "$WORK/plant/initializers-planted.m" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
old = '#define REFUSES @"raises NSInternalInconsistencyException: You must use a concrete subclass of CKOperation"'
new = '#define REFUSES @"raises NSInvalidArgumentException: You must instantiate one of the CKOperation subclasses"'
assert text.count(old) == 1, "the expectation the control changes is not there exactly once"
open(path, "w").write(text.replace(old, new, 1))
PY
    if build_initializers "$WORK/plant/initializers-planted.m" "$WORK/init-planted"; then
        planted=$(DYLD_FRAMEWORK_PATH="$HOST_SDK/System/iOSSupport/System/Library/Frameworks" \
                  "$WORK/init-planted" 2>&1)
        pcode=$?
        echo "$planted" | grep -E 'CKOperation\[' | sed 's/^/  /'
        if [ "$pcode" -eq 0 ]; then
            echo "  FAIL the planted control did not fire: this stage cannot see a wrong answer"
            fails=$((fails + 1))
        else
            echo "  ok the control fired: the stage reads the answer and not merely prints it"
        fi
    else
        echo "  FAIL the scratch copy did not build:"; head -3 "$WORK.init.log"; fails=$((fails + 1))
    fi
else
    echo "  FAIL the host build:"; head -3 "$WORK.init.log"; fails=$((fails + 1))
fi

echo "zone-check: $fails failing step(s)"
[ "$fails" -eq 0 ] || exit 1
exit 0
