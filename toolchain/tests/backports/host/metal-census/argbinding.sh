#!/bin/sh
# argbinding.sh - the argument bindings' round trip, and the mutations each row's case must notice.
#
#     sh tests/backports/host/metal-census/argbinding.sh
#     SELF_TEST=1 sh tests/backports/host/metal-census/argbinding.sh   # prove_defined's own halves
#
# Run from packages/a/apple-backports. ONE clang line builds the case TOGETHER WITH the port source,
# the way tests/backports/host/metal-census/stitch.sh does it: two objects cannot be linked when one
# is built for the device and the other for the host, and the failure looks like a missing main
# rather than a mismatched architecture.
#
# A MUTATION THAT DOES NOT BUILD IS "RUN FAILED", NEVER RED. It says so because it happened here: a
# mutation compiled with a wrong -I depth left the previous binary in place, so the run reported a
# GREEN against an object that no longer existed, and a mutation that silently did nothing read as a
# pass. Every build below removes its outputs first, and a build that fails is named and exits
# non-zero instead of being counted as a red test.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/argbinding}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$(dirname "$0")/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
S="$root/packages/a/apple-backports"
SRC="$S/Metal/MTLArgumentBinding16.m"
rm -rf "$work"
mkdir -p "$work"

sdk=$(xcrun --show-sdk-path --sdk macosx)
# the same line stitch.sh uses, plus the SAME EAGL stub the port's own header needs.
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks"
common="$common -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc"
common="$common -I $S/Metal -I $S -I $S/MetalKit -I $root/tests/backports/host/metalblit/gl-stub"

# THE PORT'S CLASSES MUST BE DEFINED IN THE BINARY, not resolved to a dylib. Metal has an API on the
# host as well, so a case can pass by calling Apple's rather than the port's - which would make every
# assertion here a statement about Apple's class. The count is what matters, not an address: an
# address can be a dylib's, a defined count cannot.
prefix='_OBJC_CLASS_$_'
class_list="CharonMetalBinding CharonMetalBufferBinding CharonMetalTextureBinding CharonMetalThreadgroupBinding CharonMetalObjectPayloadBinding"
prove_defined() {   # $1 nm output
    for name in $class_list; do
        symbol="${prefix}${name}"
        defined=$(printf '%s\n' "$1" | awk -v s="$symbol" 'index($0, s){n++} END{print n+0}')
        if [ "$defined" -eq 0 ]; then
            echo "MISSING $symbol - the case would measure the HOST's Metal, not the port's" >&2
            return 1
        fi
    done
    count=$(printf '%s\n' "$1" | awk -v p="$prefix" 'index($0, p "CharonMetal"){n++} END{print n+0}')
    expected=0
    for symbol in $class_list; do expected=$((expected + 1)); done
    if [ "$count" -eq 0 ] || [ "$count" -ne "$expected" ]; then
        echo "FAIL: $count of the port's $expected class symbols are defined in the binary" >&2
        return 1
    fi
    echo "  the port's classes are DEFINED in the binary: $count of $expected"
}

# SELF-TEST of prove_defined, against a fake nm: one class missing from the symbol table must be
# NAMED, and the full list must pass - or the function accepts a table with a hole in it.
if [ -n "${SELF_TEST:-}" ]; then
    selfdir="$root/.agent-work/runs/metal-census/argbinding-self-test"
    work_ok "$selfdir" || { echo "FAIL: the self-test scratch is not under .agent-work" >&2; exit 1; }
    rm -rf "$selfdir"; mkdir -p "$selfdir" || exit 1
    fake="$selfdir/symbols"
    for name in $class_list; do
        if [ "$name" = "CharonMetalObjectPayloadBinding" ]; then continue; fi   # the one that is missing
        printf '%s S %s%s\n' "0000000000000100" "$prefix" "$name" >> "$fake"
    done
    if prove_defined "$(cat "$fake")"; then
        echo "FAIL: the self-test passed with a class missing from the symbol table" >&2
        rm -rf "$selfdir"; exit 1
    fi
    echo "  ok   the self-test's NEGATIVE: the class that is not defined is named"
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

# $1 output name, $2 port source. ALWAYS REBUILDS: a stale object left behind by a failed build is
# what let a mutation that did nothing read as a green run.
# The binding case links Apple's Metal ON PURPOSE, and only to ask a host MTLDevice for an argument
# encoder, which it does not have. The encoder case links Foundation only - that difference is the
# measurement, and the otool check below holds it.
fnd="-framework Foundation"
metal="-framework Foundation -framework Metal"

build() {   # $1 output name, $2 case source, $3 port source
    rm -f "$work/$1" "$work/$1.o"
    xcrun clang $common $metal -o "$work/$1" "$2" "$3" > "$work/$1.link" 2>&1 || {
        echo "RUN FAILED  $1 does not build - this is a build failure, not a red test" >&2
        sed -n '/error:/,$p' "$work/$1.link" | head -1 | sed 's/^/    /' >&2
        exit 1
    }
}

# $1 label, $2 output name. RED means the case ran and named this row. A green run here is a FAILURE:
# a row whose own mutant is green is a row that nothing measures, which is the hole this script exists
# to close. A run that produced no FAIL line at all is also a failure - that is a case that did not
# get as far as an assertion, and it must never be counted as red.
expect_red() {   # $1 label, $2 output name
    if "$work/$2" > "$work/$2.out" 2>&1; then
        echo "FAIL  $1 is NOT red - this row is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$2.out" | sed 's/^ *FAIL /  /')
    if [ -z "$line" ]; then
        echo "FAIL  $1 produced no assertion line - see $work/$2.out" >&2
        exit 1
    fi
    echo "  red  $line"
}

# A mutation is SCOPED TO ITS CLASS, not matched by text. Each of the five -type getters answers one
# of three different constants, so a plain text replace hits whichever comes first in the file - which
# is how an early revision of this script "mutated" the base while reporting a green run.
mutate_type() {   # $1 mutant name, $2 class, $3 replacement
    cp "$SRC" "$work/$1.m"
    python3 - "$work/$1.m" "$2" "$3" <<'PY2'
import re, sys
path, cls, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
i = text.index("@implementation %s\n" % cls)
head, body = text[:i], text[i:]
j = body.index("- (MTLBindingType)type")
k = body.index("\n}", j)
seg, n = re.subn(r"    return MTLBindingType\w+;", "    %s   // MUTATION" % new, body[j:k], count=1)
assert n == 1, "no -type return in %s" % cls
open(path, "w").write(head + body[:j] + seg + body[k:])
PY2
}

echo "the round trip:"
build real "$here/argbinding.m" "$SRC"
prove_defined "$(nm -g "$work/real" 2>/dev/null)" || exit 1
"$work/real" || { echo "FAIL: the binding round trip failed" >&2; exit 1; }

echo "the encoder case, in a binary that links no Metal at all:"
# a SEPARATE binary, linking the port object and Foundation only, so Apple's Metal cannot answer in
# the port's place - which is what makes its class query a statement about the port.
rm -f "$work/encoder"
xcrun clang $common $fnd -o "$work/encoder" "$here/argencoder.m" "$SRC" > "$work/encoder.link" 2>&1 || {
    echo "RUN FAILED  encoder does not build" >&2
    sed -n '/error:/,$p' "$work/encoder.link" | head -1 | sed 's/^/    /' >&2
    exit 1
}
# the DEPENDENCY lines only: otool's first line is the file's own path, and the scratch directory
# is named metal-census, so a bare grep -i metal matched the path and reported a link that is not there
if otool -L "$work/encoder" | tail -n +2 | grep -q "Metal\.framework"; then
    echo "FAIL: the encoder case links a Metal dylib, so it could measure Apple's class" >&2
    exit 1
fi
"$work/encoder" || { echo "FAIL: the encoder case failed" >&2; exit 1; }

# THE CONTROL the failure mode needs: a mutation that does NOT compile must be RUN FAILED and a
# non-zero exit, and must never be reported as a red test.
echo "the control: a mutation that does not compile is RUN FAILED, not red"
cp "$SRC" "$work/broken.m"
printf '\nthis is not valid Objective-C;\n' >> "$work/broken.m"
rm -f "$work/broken" "$work/broken.o"
if xcrun clang $common $metal -o "$work/broken" "$here/argbinding.m" "$work/broken.m" > "$work/broken.link" 2>&1; then
    echo "FAIL: the control's broken mutation COMPILED, so it proves nothing" >&2
    exit 1
fi
if [ -e "$work/broken" ]; then
    echo "FAIL: the control left a binary behind, which is how a stale object read as green" >&2
    exit 1
fi
echo "  ok   RUN FAILED: the broken mutation did not build, and no binary was left to run"

# M0..M4, one per binding row, each breaking ONLY that class's -type. The four subclasses inherit
# everything else from the base, so -type is the one member a row owns, and it is the one each of
# these mutants breaks.
echo "the mutations: one per row, each breaking only that row"
mutate_type m0 CharonMetalBinding "return MTLBindingTypeTexture;"
mutate_type m1 CharonMetalBufferBinding "return MTLBindingTypeThreadgroupMemory;"
mutate_type m2 CharonMetalTextureBinding "return MTLBindingTypeBuffer;"
mutate_type m3 CharonMetalThreadgroupBinding "return MTLBindingTypeTexture;"
mutate_type m4 CharonMetalObjectPayloadBinding "return MTLBindingTypeBuffer;"

build mutant-m0 "$here/argbinding.m" "$work/m0.m"; expect_red "M0 MTLBinding -type" mutant-m0
build mutant-m1 "$here/argbinding.m" "$work/m1.m"; expect_red "M1 MTLBufferBinding -type" mutant-m1
build mutant-m2 "$here/argbinding.m" "$work/m2.m"; expect_red "M2 MTLTextureBinding -type" mutant-m2
build mutant-m3 "$here/argbinding.m" "$work/m3.m"; expect_red "M3 MTLThreadgroupBinding -type" mutant-m3
build mutant-m4 "$here/argbinding.m" "$work/m4.m"; expect_red "M4 MTLObjectPayloadBinding -type (34)" mutant-m4

# The two flags are ONE shared implementation in the base, so they cannot be broken per row and a
# per-row mutant for them would be a mutant of nothing. This one breaks the shared answer instead,
# and the base's own flag assertion is what names it.
echo "the mutation: the shared -used answer"
cp "$SRC" "$work/m5.m"
python3 - "$work/m5.m" <<'PY3'
import sys
path = sys.argv[1]
text = open(path).read()
old = '[binding setValue:@(used) forKey:@"used"];'
assert old in text, "the constructor's used assignment was not found"
# the two flags are ONE shared implementation, so they cannot be broken per row and a per-row mutant
# for them would be a mutant of nothing. This breaks the shared write instead, and the base's own
# flag assertion is what names it - the base was built with used=NO.
open(path, "w").write(text.replace(old, "[binding setValue:@YES forKey:@\"used\"];   // MUTATION", 1))
PY3
build mutant-m5 "$here/argbinding.m" "$work/m5.m"; expect_red "M5 the shared -used" mutant-m5

echo "argbinding: the round trip is green, the control is RUN FAILED, and all five row mutants are red"
