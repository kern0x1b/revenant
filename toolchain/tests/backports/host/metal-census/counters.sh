#!/bin/sh
# counters.sh - the 21 string constants of the 14.0 counter family, against Apple's own, and
# the mutation each one must notice.
#
#     sh tests/backports/host/metal-census/counters.sh
#
# Run from packages/a/apple-backports. THE PORT IS COMPILED WITH THE RENAMES AND THE CASE IS NOT.
# The port exports these eighteen under Apple's own names, because iOS 6 carries no constant of any
# of them; on this host Apple's Metal declares the same names, so the port's copies are renamed while
# they are compiled here and dlsym reads Apple's. Compiling the case with the renames as well would
# rename Apple's own declarations into the same names, which is a duplicate interface - and NOT
# renaming the port would bind the case's externs to Apple's and compare Apple's constant with itself.
#
# NO DEVICE IS EVER CREATED. These are strings and a descriptor asks a device nothing, so nothing here
# calls one (facts/Metal/DeviceOnThisMachine.md measures both).
#
# A MUTATION THAT DOES NOT BUILD IS "RUN FAILED", NEVER RED, for the reason it is so in every
# harness in this directory: a mutation compiled with a wrong -I depth once left the previous binary
# in place and a green run was read off an object that no longer existed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/counters}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
S="$root/packages/a/apple-backports"
SRC="$S/Metal/MTLCounterConstants14.m"
rm -rf "$work"
mkdir -p "$work"

sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios16.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks"
common="$common -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc"
common="$common -I $S/Metal -I $S -I $S/MetalKit -I $root/tests/backports/host/metalblit/gl-stub"

# The twenty-one, in the order the header declares them.
constants="MTLCommonCounterTimestamp MTLCommonCounterTessellationInputPatches \
MTLCommonCounterVertexInvocations MTLCommonCounterPostTessellationVertexInvocations \
MTLCommonCounterClipperInvocations MTLCommonCounterClipperPrimitivesOut \
MTLCommonCounterFragmentInvocations MTLCommonCounterFragmentsPassed \
MTLCommonCounterComputeKernelInvocations MTLCommonCounterTotalCycles \
MTLCommonCounterVertexCycles MTLCommonCounterTessellationCycles \
MTLCommonCounterPostTessellationVertexCycles MTLCommonCounterFragmentCycles \
MTLCommonCounterRenderTargetWriteCycles MTLCommonCounterSetTimestamp \
MTLCommonCounterSetStageUtilization MTLCommonCounterSetStatistic \
MTLBinaryArchiveDomain MTLCounterErrorDomain MTLDynamicLibraryDomain"

renames=""
for name in $constants; do renames="$renames -D$name=charonHost_$name"; done

# THE PORT'S EIGHTEEN MUST BE DEFINED IN THE BINARY, under the names a caller writes. These are
# symbols, not classes, so the count is of data symbols - and a port that exported none of them
# would let the case bind to Apple's and pass.
prove_defined() {   # $1 nm output of the HOST binary, which holds the port's RENAMED copies
    missing=""
    for name in $constants; do
        defined=$(printf '%s\n' "$1" | grep -c " [_A-Z]charonHost_$name\$")
        [ "$defined" -eq 0 ] && missing="$missing $name"
    done
    if [ -n "$missing" ]; then
        echo "FAIL: the binary does not define these constants, so the case would read Apple's:" >&2
        for name in $missing; do echo "    $name" >&2; done
        return 1
    fi
    echo "  the port's constants are DEFINED in the host binary under the renamed names: 21 of 21"
}

# AND THE OTHER SIDE OF IT: on the DEVICE, where nothing is renamed, the eighteen must be defined
# under APPLE'S OWN NAMES, because a caller writing MTLCommonCounterTimestamp must find that symbol
# and iOS 6 carries no constant of that name. A port that exported them only under a Charon name
# would be a row that says implemented and a caller that finds nothing.
prove_named_on_device() {   # $1 an object built for the device
    missing=""
    for name in $constants; do
        xcrun nm -gU "$1" 2>/dev/null | grep -q " [_A-Z]$name\$" || missing="$missing $name"
    done
    if [ -n "$missing" ]; then
        echo "FAIL: the device object does not define these under APPLE'S own names:" >&2
        for name in $missing; do echo "    $name" >&2; done
        return 1
    fi
    echo "  the DEVICE object defines all 21 under Apple's own names: _MTLCommonCounterTimestamp and 20 more"
}

# $1 output name, $2 port source. ALWAYS REBUILDS.
build() {   # $1 output name, $2 port source
    rm -f "$work/$1" "$work/$1-port.o" "$work/$1-case.o"
    # shellcheck disable=SC2086
    xcrun clang $common $renames -c "$2" -o "$work/$1-port.o" > "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the port, renamed) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common -c "$here/counters.m" -o "$work/$1-case.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the case) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common -framework Foundation -framework Metal -o "$work/$1" \
        "$work/$1-case.o" "$work/$1-port.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 does not link" >&2
        sed -n '/Undefined symbols/,$p' "$work/$1.log" | sed -n '2,4p' | sed 's/^/    /' >&2
        exit 1
    }
}

# A mutation is SCOPED TO ITS CONSTANT, by its own definition line, so changing one value cannot
# change another's.
mutate() {   # $1 mutant name, $2 constant name, $3 replacement value
    cp "$SRC" "$work/$1.m"
    python3 - "$work/$1.m" "$2" "$3" <<'PY'
import re, sys
path, name, value = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
# the constant's own DEFINITION, which is the line the name starts the statement on
pattern = re.compile(r"^(MTLCommonCounter(?:Set)?\w*|NSErrorDomain) const %s = @\"[^\"]*\";$" % re.escape(name),
                     re.M)
# the DEFINITION line, which is the one that assigns the string
assert pattern.search(text), "the mutation must match the constant it is mutating: %s" % name
open(path, "w").write(pattern.sub(r'\1 const %s = @"%s";' % (name, value), text, count=1))
PY
}

expect_red() {   # $1 label, $2 output name
    if "$work/$2" > "$work/$2.out" 2>&1; then
        echo "FAIL  $1 is NOT red - this constant is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$2.out" | sed 's/^ *FAIL /  /')
    if [ -z "$line" ]; then
        echo "FAIL  $1 produced no assertion line - see $work/$2.out" >&2
        exit 1
    fi
    echo "  red  $line"
}

echo "the eighteen constants, against Apple's own, with no device created:"
# The device object, where the names are NOT renamed.
SDK16=""
for candidate in "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk; do
    if [ -f "$candidate/SDKSettings.json" ]; then SDK16="$candidate"; break; fi
done
if [ -n "$SDK16" ]; then
    xcrun clang -target armv7-apple-ios6.1.3 -isysroot "$SDK16" -fobjc-arc -Os -g0 -Wall \
        -Wno-unguarded-availability-new -Wno-unguarded-availability \
        -Werror=objc-missing-property-synthesis -Werror=incomplete-implementation \
        -I "$S/Metal" -I "$S" -I "$S/MetalKit" -c "$SRC" -o "$work/device.o" 2>"$work/device.log" || {
        echo "RUN FAILED  the device object does not build" >&2
        sed -n '/error:/,$p' "$work/device.log" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    prove_named_on_device "$work/device.o" || exit 1
fi

build real "$SRC"
prove_defined "$(nm -g "$work/real" 2>/dev/null)" || exit 1
timeout 120 "$work/real" || { echo "FAIL: the constant differential failed" >&2; exit 1; }

# THE CONTROL the failure mode needs: a mutation that does NOT compile is RUN FAILED with a non-zero
# exit, and is never counted as a red test.
echo "the control: a mutation that does not compile is RUN FAILED, not red"
cp "$SRC" "$work/broken.m"
printf '\nthis is not valid Objective-C;\n' >> "$work/broken.m"
rm -f "$work/broken" "$work/broken-port.o" "$work/broken-case.o"
# shellcheck disable=SC2086
if xcrun clang $common $renames -c "$work/broken.m" -o "$work/broken-port.o" > "$work/broken.log" 2>&1; then
    echo "FAIL: the control's broken mutation COMPILED, so it proves nothing" >&2
    exit 1
fi
if [ -e "$work/broken" ]; then
    echo "FAIL: the control left a binary behind, which is how a stale object read as green" >&2
    exit 1
fi
echo "  ok   RUN FAILED: the broken mutation did not build, and no binary was left to run"

# ONE MUTANT PER CONSTANT. Each changes exactly one value, and each must go red on its own line.
i=0
for name in $constants; do
    i=$((i + 1))
    mutate "m$i" "$name" "charonMutatedValue$i"
    build "mutant-m$i" "$work/m$i.m"
    expect_red "M$i $name" "mutant-m$i"
done

echo "counters: the twenty-one are green, the control is RUN FAILED, and all 21 mutants are red"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"
