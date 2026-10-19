#!/bin/sh
# reflection.sh - the reader over the property lists the writer produced, and a mutant that must fail.
#
#     sh tests/backports/host/metal-census/reflection.sh PLIST [PLIST...]
#
# The reader is compiled from the port's own MTLTypeReflection.m - the same file the device builds -
# so this is a check of the reader and not of a copy. The mutant is a SCRATCH copy of that file under
# .agent-work/runs/, with one change: it maps an access it does not recognise to read-write. The port
# must never make that guess, so the mutant has to fail the assertion the real reader passes.
#
# The port's own header imports <OpenGLES/EAGL.h>, which the host does not have - the same wall
# tests/backports/host/metalblit/run.sh writes down, answered there with a stub, and answered here
# with the SAME stub directory rather than a second one. The reader under test does no OpenGL: it
# reads a property list, and it is the header's import that needs the stub.
#
# Where the plists come from: the invented fixtures under tests/backports/host/air2cpu/fixtures/ are
# read by this too, and any real property list the caller names. Nothing of Apple's libraries is
# asserted about here - no kernel, no name, no value.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/reflection}
llvm=${LLVM:-$(brew --prefix llvm)}
sdk=${SDK:-$("$llvm/bin/llvm-config" --sdk 2>/dev/null || xcrun --show-sdk-path)}
# the SDK the LIBRARY builds against, which is 16.4 and not the host's: an armv7/6.1.3 object is
# compiled against the SDK that release has, and a sysroot that does not declare what the reader
# includes would fail for a reason that has nothing to do with the reader.
library_sdk=${LIBRARY_SDK:-$HOME/.xmake/packages/i/iphoneos-sdk/16.4}
SDK=""
for candidate in "$library_sdk"/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk; do
    if [ -f "$candidate/SDKSettings.json" ]; then SDK="$candidate"; break; fi
done
if [ ! -f "$SDK/SDKSettings.json" ]; then
    echo "FAIL: no iOS 16.4 SDK for the library-flag compile; set LIBRARY_SDK" >&2
    exit 1
fi
rm -rf "$work"
mkdir -p "$work"

# THE LIBRARY'S OWN FLAGS, FIRST, because a host check that only proves the reader READS a property
# list says nothing about whether the library that ships it COMPILES. The 6.1.3 gate went red on this
# very file: the host build used none of these, and -Werror=objc-missing-property-synthesis plus the
# armv7 target are what caught it. The list is modules/apple/backports.lua's compile() at line 162 and
# clang() below it, copied rather than approximated.
# BOTH reader objects, because an object carries one release's API and the reader is two of them now.
# The invocation is the gate's own: NO -I, run from the package directory, because the sources reach
# the port's headers by relative quoted imports. An earlier version of this check added -I roots of its
# own and failed for that reason alone.
library_compile() {
    ( cd "$root/packages/a/apple-backports" && \
      for object in Metal/MTLTypeReflection8.m Metal/MTLTypeReflection11.m; do
        xcrun clang -target armv7-apple-ios6.1.3 -isysroot "$SDK" -fobjc-arc -Os -g0 -Wall \
            -Wno-unguarded-availability-new -Wno-unguarded-availability \
            -Werror=objc-missing-property-synthesis -fsyntax-only "$object" 2>&1
      done ) > "$work/reader.log" || true
    # The reader's OWN diagnostics only. air2cpu is built in the same log and LLVM 23 deprecates
    # several of its APIs, and a check that greps the whole log fails on somebody else's warnings.
    if grep -E "error:" "$work/reader.log" | grep -q "MTLTypeReflection"; then
        echo "FAIL: a reader object does not compile with the library's own flags:" >&2
        grep -E "error:" "$work/reader.log" | grep "MTLTypeReflection" | sed 's/^/  /' >&2
        exit 1
    fi
}
library_compile


# air2cpu, built here, because a check that depends on a binary someone left in .agent-work reads
# nothing at all when that binary is gone - and says so here rather than passing quietly.
"$llvm/bin/clang++" -std=c++17 "-DCHAIR_AIR2CPU_ABI=\"$root/packages/a/apple-backports/air2cpu-abi.h\"" \
    $($llvm/bin/llvm-config --cxxflags | sed 's/-fno-exceptions//') \
    "$root/tools/air2cpu/air2cpu.cpp" -o "$work/air2cpu" \
    $($llvm/bin/llvm-config --ldflags --libs core irreader bitreader support) -Wl,-rpath,"$llvm/lib"

# The plists to read: the ones the invented fixtures produce, unless the caller names their own.
if [ $# -eq 0 ]; then
    for fixture in scale reflect accesses; do
        ll="$root/tests/backports/host/air2cpu/fixtures/$fixture.ll"
        # A MISSING FIXTURE IS A FAILURE, loudly, by name. The previous version skipped it with
        # `|| continue`, and that is how the reader was delivered with three fixtures absent from the
        # stack while the check still reported success: a check that quietly reads less than it claims
        # is worse than one that does not run.
        if [ ! -f "$ll" ]; then
            echo "FAIL: the fixture $fixture.ll is not in the tree at $ll" >&2
            exit 1
        fi
        "$llvm/bin/llvm-as" "$ll" -o "$work/$fixture.bc"
        "$work/air2cpu" "$work/$fixture.bc" "$work/$fixture.c" "$work/$fixture.plist" >/dev/null 2>&1 || true
        if [ ! -s "$work/$fixture.plist" ]; then
            echo "FAIL: $fixture.ll produced no property list, so the reader would be read over nothing" >&2
            exit 1
        fi
        set -- "$@" "$work/$fixture.plist"
    done
else
    work_input="$@"
    set -- $work_input
fi
[ $# -gt 0 ] || { echo "no property list to read; build air2cpu and pass one"; exit 2; }

# The real reader, and the mutant: one line apart.
cp "$root/packages/a/apple-backports/Metal/MTLTypeReflection8.m" "$work/mutant.m"
python3 - "$work/mutant.m" <<'PY'
import sys
path = sys.argv[1]
source = open(path).read()
# THE MUTATION is in the 8.0 object now - the reader is two objects since the release split - and it
# is MTLArgument's -access, which is where the guess lived. Anything the build does not recognise
# becomes read-write, and an argument declared write-only is neither readable nor read-write.
old = """- (MTLArgumentAccess)access
{
    return CharonAccessFromWord(_argument[@"access"]);
}"""
new = """- (MTLArgumentAccess)access
{
    // THE MUTATION: anything this build does not recognise becomes read-write, which is the guess the
    // port must not make.
    return [_argument[@"access"] isEqualToString:@"read-only"] ? MTLArgumentAccessReadOnly
                                                               : MTLArgumentAccessReadWrite;
}"""
assert old in source, "the mutation must match the real code it is mutating"
open(path, "w").write(source.replace(old, new))
PY

build() {
    xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
        -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc \
        -I"$root/packages/a/apple-backports/Metal" -I"$root/packages/a/apple-backports" \
        -I"$root/tests/backports/host/metalblit/gl-stub" \
        -o "$2" "$1" -framework Foundation -framework Metal -framework CoreGraphics 2>"$3"
}
cp "$here/reflection.m" "$work/mutant-test.m"
python3 - "$work/mutant-test.m" <<'PY2'
import sys
p = sys.argv[1]
s = open(p).read()
# the mutant test includes the MUTANT reader, and its own assertions are the same ones - so the only
# difference between the two binaries is the reader, which is the point
s = s.replace('#import "MTLTypeReflection.m"', '#import "mutant.m"\n#import "mutant11.m"')
open(p, "w").write(s)
PY2

build "$here/reflection.m" "$work/real" "$work/real.build" || { echo "the real reader does not build:"; cat "$work/real.build"; exit 1; }
# The mutant binary: the same test, with the MUTANT reader in place of the real one, so the only
# difference between the two binaries is the code under test and the assertions are identical.
# THE LIBRARY'S OWN FLAGS, FIRST, because a host check that only proves the reader READS a property
# list says nothing about whether the library that ships it COMPILES. The 6.1.3 gate went red on this
# very file: the host build used none of these, and -Werror=objc-missing-property-synthesis plus the
# armv7 target are what caught it. The list is modules/apple/backports.lua's compile() at line 162 and
# clang() below it, copied rather than approximated.
build() {
    xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
        -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc \
        -I"$root/packages/a/apple-backports/Metal" -I"$root/packages/a/apple-backports" \
        -I"$root/tests/backports/host/metalblit/gl-stub" -o "$work/mutant" "$work/mutant-test.m" \
        -framework Foundation -framework Metal -framework CoreGraphics 2>"$work/mutant.build"
}
build || { echo "the MUTANT does not build, so it cannot go red:"; cat "$work/mutant.build"; exit 1; }

echo "the real reader:"
"$work/real" "$@" || { echo "FAIL: the real reader failed"; exit 1; }

echo
echo "the mutant, which maps an unknown access to read-write:"
set +e
"$work/mutant" "$@" > "$work/mutant.out" 2>&1
status=$?
set -e
# The mutant is expected to disagree about the accesses. It still reads the file; what it must not do
# is report the same answers. Its own check counts every argument as read-write unless told otherwise,
# so the way to catch it is that it no longer agrees with the file.
if [ "$status" -ne 0 ]; then
    echo "  the mutant exited $status:"
    sed 's/^/    /' "$work/mutant.out" | head -12
fi
# /bin/sh has no process substitution, so both runs are written to files and diffed. Their output is
# the aggregate the test prints - the argument counts and the access counts - and the access counts
# are where the mutation shows.
"$work/real" "$@" > "$work/real.out" 2>&1 || true
"$work/mutant" "$@" > "$work/mutant.out" 2>&1 || true
if diff -q "$work/real.out" "$work/mutant.out" >/dev/null 2>&1; then
    echo "FAIL: the mutant agrees with the real reader, so the mutation is no longer testing anything."
    exit 1
fi
echo "PASS: the mutant disagrees, which is what the guess would do to a caller."
