#!/bin/sh
# stitch.sh - the stitching round trip, and the mutations the test must notice.
#
#     sh tests/backports/host/metal-census/stitch.sh
#
# Run from packages/a/apple-backports. ONE clang line builds the test TOGETHER WITH the port source,
# the way tests/backports/host/security/run-cases.sh does it: two objects cannot be linked when one is
# built for the device and the other for the host, and the failure looks like a missing main rather
# than a mismatched architecture. The test and the source go in together, as sources, for the host.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/stitch}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$(dirname "$0")/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
S="$root/packages/a/apple-backports"
SRC="$S/Metal/MTLFunctionStitching15.m"
rm -rf "$work"
mkdir -p "$work"

sdk=$(xcrun --show-sdk-path --sdk macosx)
# the same line security's driver uses, plus the EAGL stub that the port's own header needs - the
# wall metalblit/run.sh writes down, and the SAME stub rather than a second one.
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks"
common="$common -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc"
common="$common -I $S/Metal -I $S -I $S/MetalKit -I $root/tests/backports/host/metalblit/gl-stub"

# The PORT'S CLASSES MUST BE DEFINED IN THE BINARY, not resolved to a dylib. Metal has an API on the
# host as well, so a test can pass by calling Apple's rather than the port's - which would make every
# assertion here a statement about Apple's class. The count is what matters, not an address: an address
# can be a dylib's, a defined count cannot.
prefix='_OBJC_CLASS_$_'
# SIX classes, not five: MTLRenderPipelineFunctionsDescriptor is carried in the same object, and
# leaving it out let the test pass while measuring APPLE class instead of the port own.
class_list="MTLFunctionStitchingGraph MTLFunctionStitchingInputNode MTLFunctionStitchingFunctionNode MTLFunctionStitchingAttributeAlwaysInline MTLStitchedLibraryDescriptor MTLRenderPipelineFunctionsDescriptor"
prove_defined() {   # $1 binary
        for name in $class_list; do
        symbol="${prefix}${name}"
        # nm prints ADDRESS TYPE NAME, so the type letter is the SECOND field: a DEFINED class is
        # "S _OBJC_CLASS_$_X" and an unresolved one is only in nm -u
        defined=$(printf '%s\n' "$1" | awk -v s="$symbol" 'index($0, s){n++} END{print n+0}')
        if [ "$defined" -eq 0 ]; then
            echo "MISSING $symbol - the test would measure the HOST's Metal, not the port's" >&2
            return 1
        fi
    done
    # nm -g prints "<address> <type> <symbol>", so the count is a LINE count for the port's own class
    # names, not a two-field pattern - the previous ERE had a bare $ that could never match, and the
    # green run printed 0.
    count=$(printf '%s\n' "$1" | awk -v p="$prefix" 'index($0, p "MTL"){n++} END{print n+0}')
    expected=0
    for symbol in $class_list; do expected=$((expected + 1)); done
    if [ "$count" -eq 0 ] || [ "$count" -ne "$expected" ]; then
        echo "FAIL: $count of the port's $expected class symbols are defined in the binary" >&2
        return 1
    fi
    echo "  the port's classes are DEFINED in the binary: $count of $expected"
}

# SELF-TEST of prove_defined, against a fake nm: one class missing from the symbol table must be
# NAMED. The alternative - compiling a file with the class #if 0'd out - cannot work, because the
# test itself uses the class and so does not compile; that is a BUILD failure and names nothing,
# which is not what this control is for.
if [ -n "${SELF_TEST:-}" ]; then
    selfdir="$root/.agent-work/runs/metal-census/stitch-self-test"
    work_ok "$selfdir" || { echo "FAIL: the self-test scratch is not under .agent-work" >&2; exit 1; }
    rm -rf "$selfdir"; mkdir -p "$selfdir" || exit 1
    fake="$selfdir/symbols"
    for name in $class_list; do
        if [ "$name" = "MTLRenderPipelineFunctionsDescriptor" ]; then continue; fi   # the one that is missing
        printf '%s S %s%s\n' "0000000000000100" "$prefix" "$name" >> "$fake"
    done
    if prove_defined "$(cat "$fake")"; then
        echo "FAIL: the self-test passed with a class missing from the symbol table" >&2
        rm -rf "$selfdir"; exit 1
    fi
    echo "  ok   the self-test's NEGATIVE: the class that is not defined is named"
    # and the POSITIVE half: the FULL list must pass, or the function accepts a table with a hole in it
    : > "$fake"
    for name in $class_list; do printf '%s S %s%s\n' "0000000000000100" "$prefix" "$name" >> "$fake"; done
    if ! prove_defined "$(cat "$fake")"; then
        echo "FAIL: the self-test's full list was refused, so prove_defined is not usable" >&2
        rm -rf "$selfdir"; exit 1
    fi
    echo "  ok   the self-test's POSITIVE: the full list of ${class_list} passes"
    rm -rf "$selfdir"
    exit 0
fi

# $1 output binary, $2 stitching source. The DEVICE object this function used to compile is gone: two
# sources with -c and a single -o is a hard error on every run, its log was written and read by
# nothing, and `|| true` hid both. Nothing consumed it - prove_defined reads the LINKED BINARY below,
# and every mutant links its own - so the step is DROPPED rather than repaired.
build() {   # $1 output binary, $2 stitching source
    xcrun clang $common -o "$work/$1" "$here/stitch.m" "$2" > "$work/$1.link" 2>&1 || {
        echo "FAIL: $1 does not build" >&2
        # the FIRST compiler error, and the LINKER's block, which is where the missing symbol is NAMED
        sed -n '/error:/,$p' "$work/$1.link" | head -1 | sed 's/^/    /' >&2
        sed -n '/Undefined symbols/,$p' "$work/$1.link" | sed -n '2,6p' | sed 's/^/    /' >&2
        exit 1
    }
}

echo "the round trip:"
build real "$SRC"
prove_defined "$(nm -g "$work/real" 2>/dev/null)" || exit 1
"$work/real" || { echo "FAIL: the stitching round trip failed" >&2; exit 1; }

echo "the mutation: a graph that forgets its nodes"
cp "$SRC" "$work/m1.m"
python3 - "$work/m1.m" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
old = "        _nodes = [nodes copy] ?: @[];"
assert old in text, "the mutation must match the code it is mutating"
open(path, "w").write(text.replace(old, "        _nodes = @[];   // MUTATION", 1))
PY
build mutant-nodes "$work/m1.m" m1-device.o
if "$work/mutant-nodes" > "$work/m1.out" 2>&1; then
    echo "FAIL: the mutant that forgets the nodes is NOT red" >&2; exit 1
fi
echo "  ok   red, at: $(grep -m1 'FAIL' "$work/m1.out")"

echo "the mutation: a copy that returns the object instead of a copy"
cp "$SRC" "$work/m2.m"
python3 - "$work/m2.m" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
old = "    return [[MTLFunctionStitchingGraph alloc] initWithFunctionName:_functionName\n                                                              nodes:_nodes\n                                                         outputNode:_outputNode\n                                                         attributes:_attributes"
assert old in text, "the mutation must match the code it is mutating"
# the whole multi-line return becomes the alias, so the file still parses: a mutation that does not
# compile would be a FAILURE OF THE BUILD, not of the test, and would prove nothing
new = "    return self;   // MUTATION: a copy that is an alias"
assert old in text, "the mutation must match the code it is mutating"
open(path, "w").write(text.replace(old, new, 1))
PY
build mutant-alias "$work/m2.m" m2-device.o
if "$work/mutant-alias" > "$work/m2.out" 2>&1; then
    echo "FAIL: the aliasing mutant is NOT red" >&2; exit 1
fi
echo "  ok   red, at: $(grep -m1 'FAIL' "$work/m2.out")"
echo "the mutation: a binary-functions descriptor that forgets the vertex list"
cp "$SRC" "$work/m3.m"
python3 - "$work/m3.m" <<'PY3'
import sys
path = sys.argv[1]
text = open(path).read()
old = "    _vertexAdditionalBinaryFunctions = [vertexAdditionalBinaryFunctions copy];"
new = "    _vertexAdditionalBinaryFunctions = @[];   // MUTATION: the vertex list is forgotten"
assert old in text, "the mutation must match the code it is mutating"
open(path, "w").write(text.replace(old, new, 1))
PY3
build mutant-binaries "$work/m3.m" m3-device.o
if "$work/mutant-binaries" > "$work/m3.out" 2>&1; then
    echo "FAIL: the mutant that forgets the vertex list is NOT red" >&2; exit 1
fi
echo "  ok   red, at: $(grep -m1 'FAIL' "$work/m3.out")"
echo "stitch: the round trip is green and all three mutants are red"
