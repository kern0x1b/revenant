#!/bin/sh
# descriptors26.sh - the Metal 4 descriptors against Apple's own objects, and the mutations the case
# must notice.
#
#     sh tests/backports/host/metal-census/descriptors26.sh
#     SELF_TEST=1 sh tests/backports/host/metal-census/descriptors26.sh   # prove_defined's own halves
#
# NO DEVICE IS EVER CREATED, and the reason is that a DESCRIPTOR ASKS FOR NONE - both sides are
# [[X alloc] init - which facts/Metal/DeviceOnThisMachine.md measures on a machine that has one. The
# oracle is Apple's own object of the same class, and the port is compared to it member by member.
#
# THE PORT'S CLASSES CARRY APPLE'S OWN NAMES in the port, because iOS 6 carries no class of any of
# them and an application that does [[MTL4RenderPipelineDescriptor alloc] init] must find one. On the
# host BOTH COPIES EXIST, so the port's are RENAMED while they are compiled for it and the host
# framework keeps the Apple names - the arrangement descriptors16.sh uses, and the reason a comparison
# can be made at all rather than the case reading the host's class and calling it the port's. The
# rename is a #define INSIDE the translation unit this script writes and not a -D on the command line:
# the same file with the same flags and the same -D produced an object carrying Apple's name in one
# invocation and the port's in another, from one command line (see mdltexture.sh), and a rename that is
# not reproducible is not a seam.
#
# TWO OBJECTS ARE COMPILED AND LINKED: the 26.0 file and the 11.0 tile-attachment file, because the
# tile descriptor's colour attachments are an 11.0 class and an object holds the API of ONE release.
# Each is compiled under the same rename set, so the case sees one coherent port.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/descriptors26}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work"

S="$root/packages/a/apple-backports"
sdk=$(xcrun --show-sdk-path --sdk macosx)
# macOS 26.0: the case compares MTL4* members, and the release that declares them is the honest
# target. At a lower one every MTL4 member is an unguarded-availability warning, and a warning is not
# silenced with -Wno to make a number look better.
target="-target arm64-apple-macos26.0 -isysroot $sdk"
common="$target -fobjc-arc"
frameworks="-framework Foundation -framework Metal"
includes="-I $S -I $S/Metal -I $S/Foundation -I $work/port"

class_list="MTL4PipelineOptions MTL4StaticLinkingDescriptor MTL4PipelineStageDynamicLinkingDescriptor \
MTL4RenderPipelineDynamicLinkingDescriptor MTL4RenderPipelineBinaryFunctionsDescriptor \
MTL4RenderPipelineColorAttachmentDescriptor MTL4RenderPipelineColorAttachmentDescriptorArray \
MTL4PipelineDescriptor MTL4RenderPipelineDescriptor MTL4ComputePipelineDescriptor \
MTL4TileRenderPipelineDescriptor MTL4MeshRenderPipelineDescriptor MTL4FunctionDescriptor \
MTL4SpecializedFunctionDescriptor MTL4StitchedFunctionDescriptor MTL4LibraryFunctionDescriptor \
MTL4AccelerationStructureGeometryDescriptor MTL4AccelerationStructureTriangleGeometryDescriptor \
MTL4AccelerationStructureBoundingBoxGeometryDescriptor MTL4AccelerationStructureCurveGeometryDescriptor \
MTL4AccelerationStructureMotionTriangleGeometryDescriptor MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor \
MTL4AccelerationStructureMotionCurveGeometryDescriptor MTL4RenderPassDescriptor \
MTLTileRenderPipelineColorAttachmentDescriptor MTLTileRenderPipelineColorAttachmentDescriptorArray"

prove_defined() {   # $1 nm output
    for name in $class_list; do
        symbol="_OBJC_CLASS_\$_charonHost_$name"
        found=$(printf '%s\n' "$1" | awk -v s="$symbol" 'index($0, s){n++} END{print n+0}')
        if [ "$found" -eq 0 ]; then
            echo "MISSING $symbol - the case would measure the HOST's Metal, not the port's" >&2
            return 1
        fi
    done
    count=0
    for name in $class_list; do count=$((count + 1)); done
    echo "  the port's classes are DEFINED in the binary: $count of $count"
}

if [ -n "${SELF_TEST:-}" ]; then
    selfdir="$root/.agent-work/runs/metal-census/descriptors26-self-test"
    work_ok "$selfdir" || { echo "FAIL: the self-test scratch is not under .agent-work" >&2; exit 1; }
    rm -rf "$selfdir"; mkdir -p "$selfdir" || exit 1
    fake="$selfdir/symbols"
    : > "$fake"
    for name in $class_list; do
        [ "$name" = "MTL4LibraryFunctionDescriptor" ] && continue   # the one left out
        printf '%s S %s%s%s\n' "0000000000000100" "_OBJC_CLASS_\$_" "charonHost_" "$name" >> "$fake"
    done
    if prove_defined "$(cat "$fake")"; then
        echo "FAIL: the self-test passed with a class missing from the symbol table" >&2
        rm -rf "$selfdir"; exit 1
    fi
    echo "  ok   the self-test's NEGATIVE: the class that is not defined is named"
    : > "$fake"
    for name in $class_list; do printf '%s S %s%s%s\n' "0000000000000100" "_OBJC_CLASS_\$_" "charonHost_" "$name" >> "$fake"; done
    if ! prove_defined "$(cat "$fake")"; then
        echo "FAIL: the self-test's full list was refused, so prove_defined is not usable" >&2
        rm -rf "$selfdir"; exit 1
    fi
    echo "  ok   the self-test's POSITIVE: the full list of $count passes"
    rm -rf "$selfdir"
    exit 0
fi

# THE PORT'S TWO FILES, IN ONE TRANSLATION UNIT under the rename, so the #define reaches both and the
# case sees one coherent port. ALWAYS REBUILDS and removes the binary first, so a link that fails
# cannot leave the previous run's binary behind to be read as this run's answer.
mkdir -p "$work/port"
cat > "$work/port/port.m" <<'PORTTU'
/* Written by tests/backports/host/metal-census/descriptors26.sh: the port's Metal 4 descriptors under
 * class names this host does not have, so Apple's keeps the real ones and the two can be compared. */
#define MTL4PipelineOptions charonHost_MTL4PipelineOptions
#define MTL4StaticLinkingDescriptor charonHost_MTL4StaticLinkingDescriptor
#define MTL4PipelineStageDynamicLinkingDescriptor charonHost_MTL4PipelineStageDynamicLinkingDescriptor
#define MTL4RenderPipelineDynamicLinkingDescriptor charonHost_MTL4RenderPipelineDynamicLinkingDescriptor
#define MTL4RenderPipelineBinaryFunctionsDescriptor charonHost_MTL4RenderPipelineBinaryFunctionsDescriptor
#define MTL4RenderPipelineColorAttachmentDescriptor charonHost_MTL4RenderPipelineColorAttachmentDescriptor
#define MTL4RenderPipelineColorAttachmentDescriptorArray charonHost_MTL4RenderPipelineColorAttachmentDescriptorArray
#define MTL4PipelineDescriptor charonHost_MTL4PipelineDescriptor
#define MTL4RenderPipelineDescriptor charonHost_MTL4RenderPipelineDescriptor
#define MTL4ComputePipelineDescriptor charonHost_MTL4ComputePipelineDescriptor
#define MTL4TileRenderPipelineDescriptor charonHost_MTL4TileRenderPipelineDescriptor
#define MTL4MeshRenderPipelineDescriptor charonHost_MTL4MeshRenderPipelineDescriptor
#define MTL4FunctionDescriptor charonHost_MTL4FunctionDescriptor
#define MTL4SpecializedFunctionDescriptor charonHost_MTL4SpecializedFunctionDescriptor
#define MTL4StitchedFunctionDescriptor charonHost_MTL4StitchedFunctionDescriptor
#define MTL4LibraryFunctionDescriptor charonHost_MTL4LibraryFunctionDescriptor
#define MTL4AccelerationStructureGeometryDescriptor charonHost_MTL4AccelerationStructureGeometryDescriptor
#define MTL4AccelerationStructureTriangleGeometryDescriptor charonHost_MTL4AccelerationStructureTriangleGeometryDescriptor
#define MTL4AccelerationStructureBoundingBoxGeometryDescriptor charonHost_MTL4AccelerationStructureBoundingBoxGeometryDescriptor
#define MTL4AccelerationStructureCurveGeometryDescriptor charonHost_MTL4AccelerationStructureCurveGeometryDescriptor
#define MTL4AccelerationStructureMotionTriangleGeometryDescriptor charonHost_MTL4AccelerationStructureMotionTriangleGeometryDescriptor
#define MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor charonHost_MTL4AccelerationStructureMotionBoundingBoxGeometryDescriptor
#define MTL4AccelerationStructureMotionCurveGeometryDescriptor charonHost_MTL4AccelerationStructureMotionCurveGeometryDescriptor
#define MTL4RenderPassDescriptor charonHost_MTL4RenderPassDescriptor
#define MTLTileRenderPipelineColorAttachmentDescriptor charonHost_MTLileRenderPipelineColorAttachmentDescriptor
#define MTLTileRenderPipelineColorAttachmentDescriptorArray charonHost_MTLTileRenderPipelineColorAttachmentDescriptorArray
#include "MTL4Descriptors26.m"
#include "MTL4AccelerationGeometry26.m"
#include "MTL4RenderPass26.m"
#include "MTLTileRenderPipelineAttachments11.m"
PORTTU
cp "$work/port/port.m" "$work/port/port-pristine.m"

# THE VALUE BINARY: the value case with the port's object beside it. M8 and M9 are the equality
# mutations and they are red against THIS binary, because the questions they break are asked here and not
# in the big case - which is why asking them there was not enough.
build_value() {   # $1 output name, then the port objects to link
    rm -f "$work/$1" "$work/$1-case.o"
    # shellcheck disable=SC2086
    xcrun clang $common -c "$here/descriptors26-value.m" -o "$work/$1-case.o" > "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the value case) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -3 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    # ONE port object, and the comment is worth having: build() compiles BOTH port files into ONE
    # translation unit, so this object carries the tile classes as well as the 26.0 ones and a second
    # object was a link error rather than a link line.
    # shellcheck disable=SC2086
    xcrun clang $common $frameworks -o "$work/$1" "$work/$1-case.o" "$2" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 does not link" >&2
        sed -n '/Undefined symbols/,$p' "$work/$1.log" | sed -n '2,6p' | sed 's/^/    /' >&2
        exit 1
    }
}


# THE SAMPLE-POSITION BOUNDS, OUT OF PROCESS, ONE INVOCATION PER BOUND AND PER SIDE. Metal's own refusals
# here are ASSERTIONS, which stop the process, so a case that asks one of them in the same binary as
# everything else dies before it has compared anything. The port's refusals are NSExceptions, so its
# side is asked the same way and prints what it said.
#
# BOTH SIDES MUST REFUSE. The port's side must print "refused, " and exit 0; Apple's side must NOT print
# "accepted" and must NOT exit 0. An assertion's text is in the case's own comment rather than parsed
# out of a signal: what the harness compares is the SHAPE both sides agree on, which is the part a
# caller can rely on.
sample_bounds() {   # $1 the bound, $2 a label for the line
    port_out=$("$work/bounds" "$1" port 2>&1) && port_rc=0 || port_rc=$?
    case "$port_out" in
        *"refused, "*) printf "  ok   %s: the PORT refuses it and says why: %s\n" "$2" "$(printf '%s' "$port_out" | sed -n 's/^port: refused, //p')" ;;
        *) echo "FAIL  $2: the PORT did not refuse it: $port_out" >&2; exit 1 ;;
    esac
    [ "$port_rc" -eq 0 ] || { echo "FAIL  $2: the port side exited $port_rc" >&2; exit 1; }
    apple_out=$("$work/bounds" "$1" apple 2>&1) && apple_rc=0 || apple_rc=$?
    case "$apple_out" in
        *"accepted"*) echo "FAIL  $2: APPLE's own object ACCEPTED it, so the port is refusing something Metal allows: $apple_out" >&2; exit 1 ;;
    esac
    if [ "$apple_rc" -eq 0 ]; then
        echo "FAIL  $2: APPLE's own object exited 0, so it did not refuse it either: $apple_out" >&2
        exit 1
    fi
    printf "  ok   %s: APPLE's own object refuses it too (exit %s)\n" "$2" "$apple_rc"
}

build() {   # $1 output name
    rm -f "$work/$1" "$work/$1-case.o" "$work/$1-port.o"
    # shellcheck disable=SC2086
    xcrun clang $common -c "$here/descriptors26.m" -o "$work/$1-case.o" > "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the case) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -3 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common $includes -c "$work/port/port.m" -o "$work/$1-port.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the port, renamed) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -3 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common $frameworks -o "$work/$1" "$work/$1-case.o" "$work/$1-port.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 does not link" >&2
        sed -n '/Undefined symbols/,$p' "$work/$1.log" | sed -n '2,6p' | sed 's/^/    /' >&2
        exit 1
    }
}

echo "the differential, against Apple's own objects, with no device created:"
SDK16=""
for candidate in "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk; do
    if [ -f "$candidate/SDKSettings.json" ]; then SDK16="$candidate"; break; fi
done
if [ -n "$SDK16" ]; then
    # THE DEVICE OBJECT, where the names are NOT renamed, must define all of them under Apple's own
    # names: the 6.1.3 gate refused a series once because the registry listed classes as implemented
    # while nothing defined those names. Checked here rather than left to a gate.
    # BOTH DEVICE OBJECTS ARE COMPILED ONCE, before the names are checked: the loop over the names was
    # inside the compile loop once, so only the first name was ever checked against a second compile of
    # the first file.
    for source in MTL4Descriptors26 MTL4AccelerationGeometry26 MTL4RenderPass26 MTLTileRenderPipelineAttachments11; do
        if ! xcrun clang -target armv7-apple-ios6.1.3 -isysroot "$SDK16" -fobjc-arc -Os -g0 -Wall \
             -Wno-unguarded-availability-new -Wno-unguarded-availability \
             -Werror=objc-missing-property-synthesis -Werror=incomplete-implementation \
             -I "$S/Metal" -I "$S" -c "$S/Metal/$source.m" -o "$work/device-$source.o" 2>>"$work/device.log"; then
            echo "RUN FAILED  the device object $source.m does not build" >&2
            sed -n '/error:/,$p' "$work/device.log" | head -3 | sed 's/^/    /' >&2
            exit 1
        fi
    done
    missing=""
    for name in $class_list; do
        if ! xcrun nm -gU "$work"/device-MTL*.o 2>/dev/null | grep -q "_OBJC_CLASS_\$_$name"; then
            missing="$missing $name"
        fi
    done
    if [ -n "$missing" ]; then
        echo "FAIL: the device objects do not define these classes under APPLE's names:" >&2
        for name in $missing; do echo "    _OBJC_CLASS_\$_$name" >&2; done
        echo "  a caller doing [[$name alloc] init] would find no class at all" >&2
        exit 1
    fi
    echo "  the DEVICE objects define all of them under Apple's own names (MTL4PipelineOptions and 16 more)"
fi

build real
prove_defined "$(nm -g "$work/real" 2>/dev/null)" || exit 1
timeout 120 "$work/real" || { echo "FAIL: the Metal 4 descriptor differential failed" >&2; exit 1; }

# THE CONTROL: a mutation that does NOT compile is "RUN FAILED", NEVER RED. It compiled once with a
# wrong -I depth, left the previous binary in place, and a green run was read off an object that no
# longer existed.
echo "the control: a mutation that does not compile is RUN FAILED, not red"
cp "$work/port/port-pristine.m" "$work/port/broken.m"
printf '\nthis is not valid Objective-C;\n' >> "$work/port/broken.m"
rm -f "$work/broken" "$work/broken-case.o" "$work/broken-port.o"
# shellcheck disable=SC2086
if xcrun clang $common $frameworks -o "$work/broken" "$here/descriptors26.m" "$work/port/broken.m" \
     -I "$S" -I "$S/Metal" > "$work/broken.log" 2>&1; then
    echo "FAIL: the control's broken mutation COMPILED, so it proves nothing" >&2
    exit 1
fi
if [ -e "$work/broken" ]; then
    echo "FAIL: the control left a binary behind, which is how a stale object read as green" >&2
    exit 1
fi
echo "  ok   RUN FAILED: the broken mutation did not build, and no binary was left to run"

# THE MUTATIONS. One per thing the port decides that a header does not state, and one per member
# nothing else shares. A mutation is a COPY of the port's file and the unit includes THAT copy, so the
# mutation is what gets compiled; `cmp` says it changed.
# $1 label, $2 file, $3 class, $4 old text, $5 new text, $6 which occurrence (default 1). The
# occurrence is there because -init and -reset spell the same default twice in four of these classes,
# and "appears 2" is a harness that stops rather than a decision about which one to change.
mutate() {   # $1 label, $2 file, $3 class, $4 old text, $5 new text, [6 occurrence]
    python3 - "$S/Metal/$2" "$work/port/$1.m" "$3" "$4" "$5" "${6:-1}" <<'PY'
import sys
src, out, cls, old, new, nth = sys.argv[1:7]
nth = int(nth)
text = open(src).read()
i = text.index("@implementation %s" % cls)
j = text.find("\n@end", i)
assert 0 < j, "the mutation must find its class's own body: %r" % cls
body = text[i:j]
# AT LEAST the nth: -init and -reset spell the same default in four of these classes, so the count is
# not required to be one. What it must be is AT LEAST the occurrence asked for - a pattern that matches
# nothing has no occurrence to change, and that is the mistake worth stopping on.
assert body.count(old) >= nth, "the mutation must match at least %d place(s) in %s: %r appears %d" % (nth, cls, old, body.count(old))
parts = body.split(old)
body = old.join(parts[:nth]) + new + old.join(parts[nth:])
open(out, "w").write(text[:i] + body + text[j:])
PY
    [ -s "$work/port/$1.m" ] || { echo "FAIL: the mutation $1 wrote nothing" >&2; exit 1; }
    # ONLY ITS OWN INCLUDE IS REPLACED, and the include is spelled with QUOTES and no slash, so the
    # substitution has to match that. Pointing both includes at one copy compiled the 26.0 classes twice
    # and the run stopped with "reimplementation of class"; a pattern of "/$2.m" matched nothing at
    # all, the unit stayed the pristine one, and M1 came back GREEN - which is the failure this harness
    # exists to prevent, caught by its own mutation.
    sed "s|\"$2\"|\"$1.m\"|" "$work/port/port-pristine.m" > "$work/port/port-$1.m"
    if cmp -s "$work/port/port-$1.m" "$work/port/port-pristine.m"; then
        echo "FAIL: the mutation $1 did not change the unit, so it would run the real code" >&2
        exit 1
    fi
    cp "$work/port/port-$1.m" "$work/port/port.m"
    build "$1"
    # The 11.0 object of this mutant under a stable name, because the value binary links it beside the
    # mutant 26.0 one: the value case asks the tile attachment, which lives in the other file.
    # The port OBJECT of this mutant, kept for build_value: the equality mutants are measured against the
    # value binary, and that binary links this object rather than the big case's.
}
# $1 the mutant name, $2 what it broke. The BINARY is named by the mutant, not by the sentence: an
# earlier spelling passed the sentence as $1 and then tried to run a binary of that name, which does
# not exist, and reported it as "no assertion line" - a harness defect that reads as a red mutation.
# A red for the VALUE binary, which the equality mutations are measured against.
expect_red_value() {   # $1 mutant name, $2 what it broke
    if timeout 120 "$work/$1" > "$work/$1.out" 2>&1; then
        echo "FAIL  $1 ($2) is NOT red - this equality is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$1.out" | sed 's/^ *FAIL /  /')
    if [ -z "$line" ]; then
        echo "FAIL  $1 ($2) produced no assertion line - see $work/$1.out" >&2
        sed -n 1,4p "$work/$1.out" | sed 's/^/    /' >&2
        exit 1
    fi
    echo "  red  $2: $line"
}

expect_red() {   # $1 mutant name, $2 what it broke
    if timeout 120 "$work/$1" > "$work/$1.out" 2>&1; then
        echo "FAIL  $1 ($2) is NOT red - this class is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$1.out" | sed 's/^ *FAIL /  /')
    if [ -z "$line" ]; then
        echo "FAIL  $1 ($2) produced no assertion line - see $work/$1.out" >&2
        sed -n 1,4p "$work/$1.out" | sed 's/^/    /' >&2
        exit 1
    fi
    echo "  red  $2: $line"
}

echo "the mutations: one per thing the port decides that a header does not state"
mutate m1 MTL4Descriptors26.m MTL4RenderPipelineColorAttachmentDescriptor \
    "_writeMask = MTLColorWriteMaskAll;" "_writeMask = MTLColorWriteMaskBlue;"
expect_red m1 "the attachment's fresh write mask"

# The first M2 was the base's options SETTER, and it was not red because nothing in the case ever sets
# options to nil - a mutation nothing observes proves nothing, and a green run here would have been the
# harness agreeing with itself. This one is a member the case does compare.
mutate m2 MTL4Descriptors26.m MTL4PipelineOptions \
    "copy.shaderReflection = _shaderReflection;" "copy.shaderReflection = MTL4ShaderReflectionNone;"
expect_red m2 "the options' copy carrying shaderReflection"

# occurrence 1 is -init and occurrence 2 is -reset, and both spell the default; the harness is told
# which one it is changing rather than being left to guess.
mutate m3 MTL4Descriptors26.m MTL4RenderPipelineDescriptor \
    "_rasterSampleCount = 1;" "_rasterSampleCount = 0;" 1
expect_red m3 "the render pipeline's fresh rasterSampleCount"

# A WRITE COPIES, which the header states and which the case checks on both sides. The FIRST M4 was the
# reset of a nil, and it was not red: the getter makes a descriptor when the slot is empty, so emptying
# the slot and resetting it are the same thing through the only way in - a reset nothing can observe is
# not proved by a green run, and the port keeps the reset because the header asks for it.
mutate m4 MTL4Descriptors26.m MTL4RenderPipelineColorAttachmentDescriptorArray \
    "_slots[attachmentIndex] = [attachment copy];" "_slots[attachmentIndex] = attachment;"
expect_red m4 "the array's copy semantics on a write"

mutate m5 MTL4Descriptors26.m MTL4PipelineStageDynamicLinkingDescriptor \
    "_maxCallStackDepth = 1;" "_maxCallStackDepth = 0;"
expect_red m5 "the stage's fresh maxCallStackDepth"

mutate m6 MTL4Descriptors26.m MTL4RenderPipelineDescriptor \
    "_vertexDescriptor = [[MTLVertexDescriptor alloc] init];" "_vertexDescriptor = nil;" 1
expect_red m6 "the render pipeline's fresh vertex descriptor"

mutate m7 MTLTileRenderPipelineAttachments11.m MTLTileRenderPipelineColorAttachmentDescriptorArray \
    "if (!_slots[attachmentIndex])
        _slots[attachmentIndex] = [[MTLTileRenderPipelineColorAttachmentDescriptor alloc] init];" \
    "if (!_slots[attachmentIndex])
        _slots[attachmentIndex] = nil;"
expect_red m7 "the tile array's getter"

# M8 AND M9 ARE THE EQUALITY ONES, and they are the mutations a reader cannot do without: a class that
# compared NOTHING answers "equal" to everything and every question above except the fourth; a class that
# compared every member but ONE answers equal on exactly the member it forgot.
mutate m8 MTL4Descriptors26.m MTL4PipelineOptions \
    "    if (self.shaderReflection != ((MTL4PipelineOptions *)object).shaderReflection) return NO;" "" 1
build_value m8 "$work/m8-port.o"
expect_red_value m8 "the options' equality forgetting shaderReflection"

mutate m9 MTL4Descriptors26.m MTL4ComputePipelineDescriptor \
    "    if (self.requiredThreadsPerThreadgroup.depth != ((MTL4ComputePipelineDescriptor *)object).requiredThreadsPerThreadgroup.depth) return NO;" "" 1
build_value m9 "$work/m9-port.o"
expect_red_value m9 "the compute descriptor's equality forgetting the depth of the threadgroup size"

# APPLE'S OWN ANSWERS TO THE SAME QUESTIONS, IN A BINARY WITH NO PORT CLASS IN IT, and the diff of the two
# runs. Asking Apple's -isEqual: inside the differential TRAPS - measured, a Trace/BPT trap in
# objc_opt_respondsToSelector at the first call, with the port's classes linked the only difference - so
# the Apple side has its own case here and the comparison is a diff of two measured runs.
echo "the sample-position bounds, out of process, one invocation per bound and per side:"
# shellcheck disable=SC2086
xcrun clang $common -c "$here/descriptors26-samplebounds.m" -o "$work/bounds-case.o" > "$work/bounds.log" 2>&1 || {
    echo "RUN FAILED  the sample-bound case does not build" >&2
    sed -n '/error:/,$p' "$work/bounds.log" | head -3 | sed 's/^/    /' >&2
    exit 1
}
# shellcheck disable=SC2086
xcrun clang $common $frameworks -o "$work/bounds" "$work/bounds-case.o" "$work/real-port.o" >> "$work/bounds.log" 2>&1 || {
    echo "RUN FAILED  the sample-bound case does not link" >&2
    sed -n '/Undefined symbols/,$p' "$work/bounds.log" | sed -n '2,6p' | sed 's/^/    /' >&2
    exit 1
}
sample_bounds count          "a count of 3 is not a sample count"
sample_bounds coordinates    "an x of 1.5 is outside [0, 1)"
sample_bounds coordinates-below "a y of -0.5 is outside [0, 1)"
sample_bounds read-smaller   "a read of count 2 with four programmed"
sample_bounds read-larger    "a read of count 8 with four programmed"
# AND THE ONE THAT IS ALLOWED, so the refusals above are not "refuse everything": a read of count 0 is
# how a caller asks how many there are, and both sides answer 4 and exit 0.
zero_port=$("$work/bounds" read-zero port 2>&1) || { echo "FAIL  a read of count 0: the port side exited non-zero: $zero_port" >&2; exit 1; }
zero_apple=$("$work/bounds" read-zero apple 2>&1) || { echo "FAIL  a read of count 0: Apple's own side exited non-zero: $zero_apple" >&2; exit 1; }
printf "  ok   a read of count 0: both sides answer %s and %s\n" \
    "$(printf '%s' "$zero_port" | sed -n 's/.*answered //p')" "$(printf '%s' "$zero_apple" | sed -n 's/.*answered //p')"

echo "Apple's own answers to the value-equality questions, in a binary of their own:"
# shellcheck disable=SC2086
xcrun clang $common -framework Foundation -framework Metal -o "$work/apple" "$here/descriptors26-apple.m" \
    > "$work/apple.log" 2>&1 || {
    echo "RUN FAILED  the Apple-side case does not build" >&2
    sed -n '/error:/,$p' "$work/apple.log" | head -3 | sed 's/^/    /' >&2
    exit 1
}
timeout 120 "$work/apple" > "$work/apple.out" 2>&1 || { echo "FAIL: the Apple-side measurement failed" >&2; exit 1; }
timeout 120 "$work/real" > "$work/port.out" 2>&1 || { echo "FAIL: the port-side case failed" >&2; exit 1; }
grep 'fresh-equal\|fresh-hash-same\|copy-equal' "$work/apple.out" > "$work/apple.value"
# THE PORT'S SIDE IS ITS OWN CASE AND ITS OWN BINARY, for the same reason: asking these questions in the
# big case's binary traps as well, and a small binary is where the trap is either gone or obvious.
# shellcheck disable=SC2086
xcrun clang $common -c "$here/descriptors26-value.m" -o "$work/value-case.o" > "$work/value.log" 2>&1 || {
    echo "RUN FAILED  the port-side value case does not build" >&2
    sed -n '/error:/,$p' "$work/value.log" | head -3 | sed 's/^/    /' >&2
    exit 1
}
# shellcheck disable=SC2086
xcrun clang $common $frameworks -o "$work/value" "$work/value-case.o" "$work/real-port.o" >> "$work/value.log" 2>&1 || {
    echo "RUN FAILED  the port-side value case does not link" >&2
    sed -n '/Undefined symbols/,$p' "$work/value.log" | sed -n '2,6p' | sed 's/^/    /' >&2
    exit 1
}
timeout 120 "$work/value" > "$work/port.out" 2>&1 || { echo "FAIL: the port-side value measurement failed" >&2; tail -5 "$work/port.out" | sed 's/^/    /' >&2; exit 1; }
grep 'fresh-equal\|fresh-hash-same\|copy-equal' "$work/port.out" > "$work/port.value"
if ! diff -u "$work/apple.value" "$work/port.value" > "$work/value.diff"; then
    echo "FAIL: the port's value equality differs from Apple's own, and the diff names it:" >&2
    head -20 "$work/value.diff" | sed 's/^/    /' >&2
    exit 1
fi
echo "  the port's value equality IS Apple's own, member for member: $(wc -l < "$work/apple.value" | tr -d ' ') answers agree"
sed -n '1,3p' "$work/apple.value" | sed 's/^/    /'

# M10 AND M11 ARE THE TWO NEW BOUNDS, and they are measured OUT OF PROCESS like the bounds are, because
# a mutant that dropped a refusal would make the PORT accept something Metal refuses - which the
# in-process differential cannot see, since it never asks a question that stops the process.
build_bounds() {   # $1 mutant name
    # shellcheck disable=SC2086
    xcrun clang $common $includes -c "$work/port/port.m" -o "$work/$1-bounds-port.o" > "$work/$1-bounds.log" 2>&1 || {
        echo "RUN FAILED  $1 (the port, renamed) does not build for the bounds case" >&2
        sed -n '/error:/,$p' "$work/$1-bounds.log" | head -3 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common $frameworks -o "$work/bounds-$1" "$work/bounds-case.o" "$work/$1-bounds-port.o" >> "$work/$1-bounds.log" 2>&1 || {
        echo "RUN FAILED  $1 does not link for the bounds case" >&2
        exit 1
    }
}
# ONLY AN ACCEPTANCE IS A RED HERE. An earlier version counted a non-zero exit as one, and the first
# M10 aborted - a red for the wrong reason, because the mutation was supposed to make the port ACCEPT
# and instead made it raise unconditionally. Anything that is not an acceptance is a FAIL.
expect_red_bounds() {   # $1 mutant name, $2 the bound, $3 what it broke
    out=$("$work/bounds-$1" "$2" port 2>&1) && rc=0 || rc=$?
    case "$out" in
        *"accepted"*)
            if [ "$rc" -ne 0 ]; then
                echo "FAIL  $3 accepted the bound and then exited $rc - a red for the wrong reason" >&2
                exit 1
            fi
            echo "  red  $3: $(printf '%s' "$out" | grep accepted)" ;;
        *)
            echo "FAIL  $3 is NOT red - the mutant did not accept the bound, so the bound is measured by nothing" >&2
            printf '%s\n' "$out" | sed 's/^/    /' >&2
            exit 1 ;;
    esac
}
mutate m10 MTL4RenderPass26.m MTL4RenderPassDescriptor \
    "            if (!CharonMetal4CoordinateIsInRange(positions[index].x))" \
    "            if (0 && !CharonMetal4CoordinateIsInRange(positions[index].x))   /* MUTATION */" 1
build_bounds m10; expect_red_bounds m10 coordinates "M10 the coordinate bound"

mutate m11 MTL4RenderPass26.m MTL4RenderPassDescriptor \
    "    if (count != 0 && count != _samplePositionCount) {" "    if (0) {" 1
build_bounds m11; expect_red_bounds m11 read-smaller "M11 the read's count bound"
build_bounds m11; expect_red_bounds m11 read-larger "M11 the read's count bound, a larger count"

echo "descriptors26: the differential is green, the Apple-side answers agree, the three sample-position bounds are refused by both sides, the control is RUN FAILED, and all eleven mutants are red"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"