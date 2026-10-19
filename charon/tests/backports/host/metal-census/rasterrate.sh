#!/bin/sh
# rasterrate.sh - the 13.0 rasterization-rate holders against Apple's own objects, and the mutation
# each class must notice.
#
#     sh tests/backports/host/metal-census/rasterrate.sh
#
# Run from packages/a/apple-backports. The port is compiled with the four classes RENAMED and the case
# is not, so the two sets coexist and each side is a different class - the runtime WILL bind a class
# of the same name to the framework's, and on this host Metal.framework implements all four, so an
# unrenamed port is silently not the port.
#
# NO DEVICE IS CREATED and none is needed: every class is [[X alloc] init], and
# a descriptor asks a device nothing (facts/Metal/DeviceOnThisMachine.md measures that).
#
# A MUTATION THAT DOES NOT BUILD IS "RUN FAILED", NEVER RED, for the reason it is so in every
# harness here: a mutation compiled with a wrong -I depth once left the previous binary in place and a
# green run was read off an object that no longer existed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/rasterrate}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
S="$root/packages/a/apple-backports"
SRC="$S/Metal/MTLRasterizationRate13.m"
rm -rf "$work"
mkdir -p "$work"

sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios16.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks"
common="$common -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc"
common="$common -I $S/Metal -I $S -I $S/MetalKit -I $root/tests/backports/host/metalblit/gl-stub"

classes="MTLRasterizationRateSampleArray MTLRasterizationRateLayerDescriptor MTLRasterizationRateLayerArray MTLRasterizationRateMapDescriptor"
renames=""
for name in $classes; do renames="$renames -D$name=charonHost_$name"; done

# THE PORT'S FOUR CLASSES MUST BE DEFINED IN THE BINARY, under the names it renames them to, or the
# case would be measuring the framework's classes and passing.
prove_defined() {   # $1 nm output
    missing=""
    for name in $classes; do
        printf '%s\n' "$1" | awk -v n="charonHost_$name" \
            '{ if ($NF == "_OBJC_CLASS_$_" n) f = 1 } END { exit !f }' || missing="$missing $name"
    done
    if [ -n "$missing" ]; then
        echo "FAIL: the binary does not define these under their renamed names:" >&2
        for name in $missing; do echo "    charonHost_$name" >&2; done
        return 1
    fi
    echo "  the port's four classes are DEFINED in the binary under the renamed names: 4 of 4"
}

# THE DEVICE OBJECT, where nothing is renamed: the four must be defined under APPLE'S OWN NAMES,
# because iOS 6 carries no class of any of them and a caller on 6.1.3 binds to those names.
prove_named_on_device() {   # $1 an object built for the device
    missing=""
    for name in $classes; do
        xcrun nm -gU "$1" 2>/dev/null | awk -v n="$name" \
            '{ if ($NF == "_OBJC_CLASS_$_" n) f = 1 } END { exit !f }' || missing="$missing $name"
    done
    if [ -n "$missing" ]; then
        echo "FAIL: the device object does not define these under Apple's own names:" >&2
        for name in $missing; do echo "    $name" >&2; done
        return 1
    fi
    echo "  the DEVICE object defines all 4 under Apple's own names: _OBJC_CLASS_\$_MTLRasterizationRateMapDescriptor and 3 more"
}

build() {   # $1 output name, $2 port source
    rm -f "$work/$1" "$work/$1-port.o" "$work/$1-case.o"
    # shellcheck disable=SC2086
    xcrun clang $common $renames -c "$2" -o "$work/$1-port.o" > "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the port, renamed) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common -c "$here/rasterrate.m" -o "$work/$1-case.o" >> "$work/$1.log" 2>&1 || {
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

# A mutation is SCOPED TO ITS CLASS, not matched by text.
mutate() {   # $1 mutant name, $2 class, $3 old text, $4 new text
    cp "$SRC" "$work/$1.m"
    python3 - "$work/$1.m" "$2" "$3" "$4" <<'PY'
import sys
path, cls, old, new = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = open(path).read()
i = text.index("@implementation %s\n" % cls)
head, body = text[:i], text[i:]
assert old in body, "the mutation must match the code it is mutating: %r" % old
open(path, "w").write(head + body.replace(old, new, 1))
PY
}

expect_red() {   # $1 label, $2 output name
    if "$work/$2" > "$work/$2.out" 2>&1; then
        echo "FAIL  $1 is NOT red - this class is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$2.out" | sed 's/^ *FAIL /  /')
    if [ -n "$line" ]; then
        echo "  red  $line"
        return 0
    fi
    # NO ASSERTION LINE, BUT IT DID NOT PASS: a trap or a signal is still a red, and saying so is
    # more useful than calling the harness broken. This is a case that ABORTED, and the abort is the
    # evidence: the mutation reached a path the case cannot survive, which is what a mutation is for.
    echo "  red  $1 ABORTED rather than naming an assertion - still not green; see $work/$2.out"
    return 0
}

echo "the four holders, against Apple's own map, with no device created:"
SDK16=""
for candidate in "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk; do
    if [ -f "$candidate/SDKSettings.json" ]; then SDK16="$candidate"; break; fi
done
if [ -n "$SDK16" ]; then
    xcrun clang -target armv7-apple-ios6.1.3 -isysroot "$SDK16" -fobjc-arc -Os -g0 -Wall \
        -Wno-unguarded-availability-new -Wno-unguarded-availability \
        -Werror=incomplete-implementation \
        -I "$S/Metal" -I "$S" -I "$S/MetalKit" -c "$SRC" -o "$work/device.o" 2>"$work/device.log" || {
        echo "RUN FAILED  the device object does not build" >&2
        sed -n '/error:/,$p' "$work/device.log" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    prove_named_on_device "$work/device.o" || exit 1
fi

build real "$SRC"
prove_defined "$(nm -g "$work/real" 2>/dev/null)" || exit 1
timeout 120 "$work/real" || { echo "FAIL: the rasterization-rate differential failed" >&2; exit 1; }

# THE CONTROL: a mutation that does NOT compile is RUN FAILED with a non-zero exit, never red.
echo "the control: a mutation that does not compile is RUN FAILED, not red"
cp "$SRC" "$work/broken.m"
printf '\nthis is not valid Objective-C;\n' >> "$work/broken.m"
rm -f "$work/broken-port.o"
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

# ONE MUTANT PER CLASS. Two of these are the defects this family actually had, so a green run here
# would have been the case agreeing with a broken port.
mutate m1 MTLRasterizationRateMapDescriptor \
    "        _screenSize = MTLSizeMake(0, 0, 0);" "        _screenSize = MTLSizeMake(1, 0, 0);   // MUTATION"
build mutant-m1 "$work/m1.m"; expect_red "M1 MTLRasterizationRateMapDescriptor screenSize" mutant-m1

mutate m2 MTLRasterizationRateLayerArray \
    "    NSUInteger run = 0;" "    NSUInteger run = 1;   // MUTATION: the leading run starts at 1"
build mutant-m2 "$work/m2.m"; expect_red "M2 MTLRasterizationRateLayerArray count, and so the map layerCount" mutant-m2

mutate m3 MTLRasterizationRateLayerDescriptor \
    "        _sampleCount = sampleCount;" "        _sampleCount = MTLSizeMake(0, 0, 0);   // MUTATION"
build mutant-m3 "$work/m3.m"; expect_red "M3 MTLRasterizationRateLayerDescriptor sampleCount" mutant-m3

mutate m4 MTLRasterizationRateSampleArray \
    "    return index < [_samples count] ? [_samples objectAtIndex:index] : nil;" \
    "    return index < 0 ? [_samples objectAtIndex:index] : nil;   // MUTATION: the bound is dead"
build mutant-m4 "$work/m4.m"; expect_red "M4 MTLRasterizationRateSampleArray a written sample" mutant-m4

echo "rasterrate: the four are green, the control is RUN FAILED, and all four mutants are red"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"
