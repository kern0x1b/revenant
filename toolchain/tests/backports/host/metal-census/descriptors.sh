#!/bin/sh
# descriptors.sh - the 14.0 descriptors against Apple's own objects, and the mutation the case must
# notice.
#
#     sh tests/backports/host/metal-census/descriptors.sh
#     SELF_TEST=1 sh tests/backports/host/metal-census/descriptors.sh   # prove_defined's own halves
#
# Run from packages/a/apple-backports. ONE clang line builds the case TOGETHER WITH the port source,
# the way argbinding.sh does it: the device object and the host case cannot be linked together, and
# the failure looks like a missing main rather than a mismatched architecture.
#
# NO DEVICE IS EVER CREATED, and the case is built so that it CANNOT be: a descriptor is
# [[X alloc] init] on both sides, and a descriptor asks a device nothing (facts/Metal/DeviceOnThisMachine.md
# So the oracle is Apple's own object of the same class, and the port is compared to it property by
# property. The check below refuses a case that has linked a device, because a case that made one
# would either hang or be measuring something else.
#
# A MUTATION THAT DOES NOT BUILD IS "RUN FAILED", NEVER RED - the same rule and the same reason as in
# argbinding.sh: a mutation compiled with a wrong -I depth once left the previous binary in place and
# a green run was read off an object that no longer existed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/descriptors}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
S="$root/packages/a/apple-backports"
SRC="$S/Metal/MTLDescriptors14.m"
rm -rf "$work"
mkdir -p "$work"

sdk=$(xcrun --show-sdk-path --sdk macosx)
# ios16.0, not 15.0: the case compares members the header gives iOS 16 - primitiveDataBuffer,
# primitiveDataBufferOffset, primitiveDataStride, primitiveDataElementSize, vertexFormat and
# transformationMatrixBufferOffset - and at a 15.0 target each of them is an unguarded-availability
# warning, eleven of them. The port implements them, so the honest target is the release that
# declares them, and a warning is not silenced with -Wno to make a number look better.
common="-target arm64-apple-ios16.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks"
common="$common -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc"
common="$common -I $S/Metal -I $S -I $S/MetalKit -I $root/tests/backports/host/metalblit/gl-stub"

# THE PORT'S CLASSES MUST BE DEFINED IN THE BINARY. Metal has an API on the host too, so a case can
# pass by measuring Apple's class instead of the port's.
prefix='_OBJC_CLASS_$_'
# THE PORT'S TWENTY CLASSES CARRY APPLE'S OWN NAMES, because iOS 6 carries no class of any of those
# names and an application that does [[MTLComputePassDescriptor alloc] init] must find one. An
# earlier revision of this series defined them as MTL<Name>, and the 6.1.3 gate refused the
# result: the registry listed MTLComputePassDescriptor as implemented and NOTHING defined that name.
# The nm check below is the proof, and it is on the DEVICE object where the names are NOT renamed.
class_list="MTLAccelerationStructureDescriptor MTLAccelerationStructureGeometryDescriptor MTLAccelerationStructureBoundingBoxGeometryDescriptor MTLAccelerationStructureTriangleGeometryDescriptor MTLPrimitiveAccelerationStructureDescriptor MTLInstanceAccelerationStructureDescriptor MTLVisibleFunctionTableDescriptor MTLIntersectionFunctionTableDescriptor MTLCounterSampleBufferDescriptor MTLComputePassSampleBufferAttachmentDescriptor MTLResourceStatePassSampleBufferAttachmentDescriptor MTLRenderPassSampleBufferAttachmentDescriptor MTLComputePassDescriptor MTLResourceStatePassDescriptor MTLBinaryArchiveDescriptor MTLComputePassSampleBufferAttachmentDescriptorArray MTLRenderPassSampleBufferAttachmentDescriptorArray MTLResourceStatePassSampleBufferAttachmentDescriptorArray MTLLinkedFunctions MTLIntersectionFunctionDescriptor"

# ON THE HOST BOTH COPIES EXIST, so the port's twenty are RENAMED while they are compiled for it and
# the host framework keeps the Apple names - the mapkit differential's arrangement, and the reason a
# comparison can be made at all rather than the case reading the host's class and calling it the port's.
renames=""
for name in $class_list; do renames="$renames -D$name=charonHost_$name"; done
prove_defined() {   # $1 nm output
    for name in $class_list; do
        symbol="${prefix}charonHost_${name}"
        defined=$(printf '%s\n' "$1" | awk -v s="$symbol" 'index($0, s){n++} END{print n+0}')
        if [ "$defined" -eq 0 ]; then
            echo "MISSING $symbol - the case would measure the HOST's Metal, not the port's" >&2
            return 1
        fi
    done
    count=$(printf '%s\n' "$1" | awk -v p="$prefix" 'index($0, p "charonHost_MTL"){n++} END{print n+0}')
    expected=0
    for symbol in $class_list; do expected=$((expected + 1)); done
    if [ "$count" -ne "$expected" ]; then
        echo "FAIL: $count of the port's $expected class symbols are defined in the binary" >&2
        return 1
    fi
    echo "  the port's classes are DEFINED in the binary: $count of $expected"
}

if [ -n "${SELF_TEST:-}" ]; then
    selfdir="$root/.agent-work/runs/metal-census/descriptors-self-test"
    work_ok "$selfdir" || { echo "FAIL: the self-test scratch is not under .agent-work" >&2; exit 1; }
    rm -rf "$selfdir"; mkdir -p "$selfdir" || exit 1
    fake="$selfdir/symbols"
    for name in $class_list; do
        if [ "$name" = "MTLLinkedFunctions" ]; then continue; fi   # the one that is missing
        printf '%s S %s%s%s\n' "0000000000000100" "$prefix" "charonHost_" "$name" >> "$fake"
    done
    if prove_defined "$(cat "$fake")"; then
        echo "FAIL: the self-test passed with a class missing from the symbol table" >&2
        rm -rf "$selfdir"; exit 1
    fi
    echo "  ok   the self-test's NEGATIVE: the class that is not defined is named"
    : > "$fake"
    for name in $class_list; do printf '%s S %s%s%s\n' "0000000000000100" "$prefix" "charonHost_" "$name" >> "$fake"; done
    if ! prove_defined "$(cat "$fake")"; then
        echo "FAIL: the self-test's full list was refused, so prove_defined is not usable" >&2
        rm -rf "$selfdir"; exit 1
    fi
    echo "  ok   the self-test's POSITIVE: the full list of ${class_list} passes"
    rm -rf "$selfdir"
    exit 0
fi

# $1 output name, $2 case source, $3 port source. ALWAYS REBUILDS.
# THE PORT IS COMPILED WITH THE RENAMES AND THE CASE IS NOT, and that is the whole point: the
# renames exist so the port's twenty classes can carry Apple's own NAMES in the port and a different
# name on this host, and applying them to the case as well would rename Apple's OWN declarations
# inside <Metal/Metal.h> into the same names the case declares - a duplicate interface, which is
# exactly what it did when the two were compiled in one command.
build() {   # $1 output name, $2 case source, $3 port source
    rm -f "$work/$1" "$work/$1.o" "$work/$1-case.o" "$work/$1-port.o"
    # shellcheck disable=SC2086
    xcrun clang $common $renames -c "$3" -o "$work/$1-port.o" > "$work/$1.link" 2>&1 || {
        echo "RUN FAILED  $1 (the port, renamed) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.link" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common -c "$2" -o "$work/$1-case.o" >> "$work/$1.link" 2>&1 || {
        echo "RUN FAILED  $1 (the case) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.link" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common -framework Foundation -framework Metal -o "$work/$1" \
        "$work/$1-case.o" "$work/$1-port.o" >> "$work/$1.link" 2>&1 || {
        echo "RUN FAILED  $1 does not link" >&2
        sed -n '/Undefined symbols/,$p' "$work/$1.link" | sed -n '2,5p' | sed 's/^/    /' >&2
        exit 1
    }
    # A case that linked a device could hang or measure something else, and this family must not.
    if otool -L "$work/$1" | tail -n +2 | grep -q "MTLDevice.h\|newArgumentEncoder"; then
        echo "FAIL: $1 appears to have reached for a device" >&2
        exit 1
    fi
}

# A mutation is SCOPED TO ITS CLASS, not matched by text: several of these getters answer the same
# constant, and a plain text replace hits whichever comes first in the file.
mutate_scoped() {   # $1 mutant name, $2 class, $3 old return, $4 new return
    cp "$SRC" "$work/$1.m"
    python3 - "$work/$1.m" "$2" "$3" "$4" <<'PY'
import re, sys
path, cls, old, new = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = open(path).read()
i = text.index("@implementation %s\n" % cls)
head, body = text[:i], text[i:]
assert old in body, "the mutation must match the code it is mutating: %r" % old
body = body.replace(old, new, 1)
open(path, "w").write(head + body)
PY
}

expect_red() {   # $1 label, $2 output name
    if "$work/$2" > "$work/$2.out" 2>&1; then
        echo "FAIL  $1 is NOT red - this class is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$2.out" | sed 's/^ *FAIL /  /')
    if [ -z "$line" ]; then
        echo "FAIL  $1 produced no assertion line - see $work/$2.out" >&2
        exit 1
    fi
    echo "  red  $line"
}

# THE GATE'S OWN CHECK, in the harness that proves the rows: the 6.1.3 gate refused this series once
# because the registry listed these twenty as implemented while NOTHING defined those names - the
# port called them CharonMetal<Name>. So the DEVICE object, where the names are NOT renamed, must
# define all twenty under Apple's own names, and that is checked here rather than left to a gate.
prove_named_on_device() {
    sdk=$1; objs=$2
    missing=""
    for name in $class_list; do
        if ! xcrun nm -gU $objs 2>/dev/null | grep -q "_OBJC_CLASS_\$_$name"; then
            missing="$missing $name"
        fi
    done
    if [ -n "$missing" ]; then
        echo "FAIL: the device object does not define these classes under APPLE'S names:" >&2
        for name in $missing; do echo "    _OBJC_CLASS_\$_$name" >&2; done
        echo "  a caller doing [[$name alloc] init] would find no class at all" >&2
        return 1
    fi
    echo "  the DEVICE object defines all 20 under Apple's own names: _OBJC_CLASS_\$_MTLComputePassDescriptor and 19 more"
}

echo "the differential, against Apple's own objects, with no device created:"
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
    prove_named_on_device "$SDK16" "$work/device.o" || exit 1
fi

build real "$here/descriptors.m" "$SRC"
prove_defined "$(nm -g "$work/real" 2>/dev/null)" || exit 1
timeout 120 "$work/real" || { echo "FAIL: the descriptor differential failed" >&2; exit 1; }

# THE CONTROL the failure mode needs: a mutation that does NOT compile is RUN FAILED with a non-zero
# exit, and is never counted as a red test.
echo "the control: a mutation that does not compile is RUN FAILED, not red"
cp "$SRC" "$work/broken.m"
printf '\nthis is not valid Objective-C;\n' >> "$work/broken.m"
rm -f "$work/broken" "$work/broken.o"
# shellcheck disable=SC2086
if xcrun clang $common -framework Foundation -framework Metal -o "$work/broken" \
    "$here/descriptors.m" "$work/broken.m" > "$work/broken.link" 2>&1; then
    echo "FAIL: the control's broken mutation COMPILED, so it proves nothing" >&2
    exit 1
fi
if [ -e "$work/broken" ]; then
    echo "FAIL: the control left a binary behind, which is how a stale object read as green" >&2
    exit 1
fi
echo "  ok   RUN FAILED: the broken mutation did not build, and no binary was left to run"

echo "the mutations: one per class that owns a member no other class shares"
mutate_scoped m1 MTLVisibleFunctionTableDescriptor \
    "@synthesize functionCount = _functionCount;" \
    "- (NSUInteger)functionCount { return 0; }   // MUTATION: the count is dropped"
build mutant-m1 "$here/descriptors.m" "$work/m1.m"
expect_red "M1 MTLVisibleFunctionTableDescriptor -functionCount" mutant-m1

mutate_scoped m2 MTLIntersectionFunctionTableDescriptor \
    "@synthesize functionCount = _functionCount;" \
    "- (NSUInteger)functionCount { return 0; }   // MUTATION: the count is dropped"
build mutant-m2 "$here/descriptors.m" "$work/m2.m"
expect_red "M2 MTLIntersectionFunctionTableDescriptor -functionCount" mutant-m2

mutate_scoped m3 MTLCounterSampleBufferDescriptor \
    "@synthesize sampleCount = _sampleCount;" \
    "- (NSUInteger)sampleCount { return 0; }   // MUTATION: the count is dropped"
build mutant-m3 "$here/descriptors.m" "$work/m3.m"
expect_red "M3 MTLCounterSampleBufferDescriptor -sampleCount" mutant-m3

echo "descriptors: the differential is green, the control is RUN FAILED, and all three mutants are red"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"
