#!/bin/sh
# mdltexture.sh - the port's MDL texture loader against Apple's own, pixel for pixel, on a real device.
#
#     sh tests/backports/host/metal-census/mdltexture.sh
#
# THIS CASE CREATES A REAL METAL DEVICE, which the other cases in this folder do not need and could not
# use when they were written: `MTLCreateSystemDefaultDevice()` answers on this machine. Measured, in
# this script's own output, and printed by the case before anything is compared:
# `<AGXG16SDevice: 0x...>`, name "Apple M4 Pro", 16 GPU cores. An earlier facts page in this folder
# said the call HANGS on a machine with no GPU and was measured hanging and killed; that was a
# statement about a machine this is not, and this case is the measurement that settles it.
#
# THE SEAM is one line: the port's loader is compiled under another class name TOGETHER WITH the
# port's own MTKTextureLoader9.m, so the port has a complete loader of its own under that name, and it
# is handed Apple's device through the port's own -initWithDevice:. The port's real device object is an
# EAGL context over OpenGL ES 2.0 and cannot be built on a host; every other line of the loader under
# test - the format table, the origin choice, the refusals, the completion handler - is the port's.
#
# THE MDLTEXTURE IS APPLE'S, and one of them, given to both sides: it is the input, not the thing under
# test, and two of them would be two inputs.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/mdltexture}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work/port"

S="$root/packages/a/apple-backports"
sdk=$(xcrun --show-sdk-path --sdk macosx)
# The macabi slice, for the reason run.sh gives: MetalKit's headers are iOSSupport headers here and a
# macOS target brings AppKit's in beside them. iOS 17.0 because MTKTextureLoaderOptionLoadAsArray is
# NS_AVAILABLE(14_0, 17_0) and this case's options dictionary names it; a warning is not silenced with
# -Wno to make a number look better.
target="-target arm64-apple-ios17.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
common="$target -fobjc-arc -Wno-unguarded-availability-new -Wno-unguarded-availability"
frameworks="-framework Foundation -framework Metal -framework MetalKit -framework ModelIO -framework CoreGraphics -framework UIKit"
includes="-I $S -I $S/MetalKit -I $S/Metal -I $S/ModelIO -I $work/port"

# THE PORT'S LOADER, IN ONE TRANSLATION UNIT THIS SCRIPT WRITES.
#
# The rename is a #define INSIDE that unit and not a -D on the command line. Both spell the same thing,
# and the command-line one was measured not working here: the same file with the same flags and the same
# -D produced an object carrying `_OBJC_CLASS_$_MTKTextureLoader` in one invocation and
# `_OBJC_CLASS_$_charonHost_MTLTextureLoader` in another, from one command line, with no difference a
# reader could find. A rename that is not reproducible is not a seam, and metal-census's run.sh already
# includes a port source this way (`-include "$METALKIT/MTKTextureLoader9.m"`), so this follows it. The
# binary is asked for the renamed symbol below and the run stops if it is not there.
cat > "$work/port/loader.m" <<'PORTTU'
/* Written by tests/backports/host/metal-census/mdltexture.sh: the port's own MetalKit loader under a
 * class name this host does not have, so Apple's keeps the real one and the two can be compared.
 * Both port files go in one unit because the loader under test is a CATEGORY and a category needs its
 * host class: the case asks -newTextureWithMDLTexture: on a class that has to EXIST and has to have a
 * -device, and MTKTextureLoader9.m is where both come from. */
#define MTKTextureLoader charonHost_MTKTextureLoader
#include "MTKTextureLoader9.m"
#include "MTKTextureLoaderMDL10.m"
PORTTU
# THE PRISTINE UNIT, kept beside the one that is compiled. `mutate` rewrites loader.m to point at a
# mutant copy, so a second mutation that started from loader.m would inherit the FIRST one's include
# and every later mutant would be the first mutation again - which is what happened, and what the
# three identical red lines showed.
cp "$work/port/loader.m" "$work/port/loader-pristine.m"

# ALWAYS REBUILDS and removes the binary first, so a link that fails cannot leave the previous run's
# binary behind to be read as this run's answer.
build() {   # $1 output name
    rm -f "$work/$1" "$work/$1-case.o" "$work/$1-port.o"
    # shellcheck disable=SC2086
    xcrun clang $common -c "$here/mdltexture.m" -o "$work/$1-case.o" > "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the case) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -3 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common $includes -c "$work/port/loader.m" -o "$work/$1-port.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the port's loader, renamed) does not build" >&2
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

echo "the port's loader against Apple's own:"
build real

# THE PORT'S CLASS MUST BE IN THE BINARY UNDER THE RENAMED NAME. MetalKit is linked, so a case that read
# the framework's class would agree with itself and the whole comparison would be worth nothing.
if ! nm -g "$work/real" 2>/dev/null | grep -q "_OBJC_CLASS_\$_charonHost_MTKTextureLoader"; then
    echo "FAIL: the binary does not define _OBJC_CLASS_\$_charonHost_MTKTextureLoader" >&2
    echo "  the case would then be measuring Apple's own loader and calling it the port's" >&2
    exit 1
fi
echo "  the port's loader is DEFINED in the binary: _OBJC_CLASS_\$_charonHost_MTKTextureLoader"
timeout 300 "$work/real" || { echo "FAIL: the MDL loader differential failed" >&2; exit 1; }

# THE MUTATIONS. A case that compares two textures and passes on any pair of them measures nothing, so
# each of the three things the port decides is broken on purpose and must turn the case red:
#   M1 the format table: the two-channel entry answers the four-channel format.
#   M2 the row order: the origin option reads the OTHER accessor.
#   M3 the refusals: an sRGB request is loaded instead of refused.
#
# The mutant is a COPY of the port's loader file and the unit includes THAT copy, so the mutation is what
# gets compiled; a mutation that changed nothing would still be green, and `cmp` says it changed.
# The replacement is done by python, not by sed: BSD sed's BRE read `{ *out` as a repetition of the
# space and substituted NOTHING, without an error and without changing the file - so the check below
# caught a mutation that had not been applied. `cmp` is what says the copy differs, and a literal
# text replacement has no metacharacters to get wrong.
mutate() {   # $1 label, $2 old text, $3 new text
    python3 - "$S/MetalKit/MTKTextureLoaderMDL10.m" "$work/port/$1.m" "$2" "$3" <<'PYMUT'
import sys
src, out, old, new = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = open(src).read()
assert text.count(old) == 1, "the mutation must match exactly one place: %r appears %d times" % (old, text.count(old))
open(out, "w").write(text.replace(old, new, 1))
PYMUT
    if cmp -s "$work/port/$1.m" "$S/MetalKit/MTKTextureLoaderMDL10.m"; then
        echo "FAIL: the mutation $1 did not change the file, so it would run the real code" >&2
        exit 1
    fi
    sed "s|MTKTextureLoaderMDL10.m|$1.m|" "$work/port/loader-pristine.m" > "$work/port/loader-$1.m"
}
expect_red() {   # $1 mutant name, $2 what it broke
    if timeout 300 "$work/$1" > "$work/$1.out" 2>&1; then
        echo "FAIL  $1 ($2) is NOT red - this behaviour is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$1.out" | sed 's/^ *FAIL /  /')
    if [ -z "$line" ]; then
        echo "FAIL  $1 ($2) produced no assertion line - see $work/$1.out" >&2
        sed -n 1,5p "$work/$1.out" | sed 's/^/    /' >&2
        exit 1
    fi
    echo "  red  $2: $line"
}
with_mutant() {   # $1 label
    cp "$work/port/loader-$1.m" "$work/port/loader.m"
    build "$1"
    # THE MUTANT REALLY IS THE ONE COMPILED: its marker has to be in the object the binary was linked
    # from, or a stale object would answer and the red below would be the wrong one's.
    if ! nm -g "$work/$1-port.o" 2>/dev/null | grep -q "_OBJC_CLASS_\$_charonHost_MTKTextureLoader"; then
        echo "FAIL: the mutant $1 did not produce the port's class" >&2
        exit 1
    fi
}

echo "the mutations, one per thing the port decides:"
mutate m1 'if (channels == 2) { *out = MTLPixelFormatRG8Unorm; return YES; }' \
          'if (channels == 2) { *out = MTLPixelFormatRGBA8Unorm; return YES; }   /* MUTATION */'
with_mutant m1; expect_red m1 "the two-channel entry of the format table"

mutate m2 'NSData *texels = bottomLeft ? [texture texelDataWithBottomLeftOrigin] : [texture texelDataWithTopLeftOrigin];' \
          'NSData *texels = bottomLeft ? [texture texelDataWithTopLeftOrigin] : [texture texelDataWithBottomLeftOrigin];   /* MUTATION */'
with_mutant m2; expect_red m2 "the origin option's choice of accessor"

# The sRGB branch's CONDITION, not its message: dropping the message leaves the error's
# NSLocalizedDescriptionKey nil, which raises inside the port and aborts - a red with no assertion line,
# which this harness refuses to count because a mutation red for the wrong reason is one nobody can
# trust. Making the branch unreachable instead loads the texture, and the case says so.
mutate m3 '} else if ([options[MTKTextureLoaderOptionSRGB] boolValue]) {' \
          '} else if (0 && [options[MTKTextureLoaderOptionSRGB] boolValue]) {   /* MUTATION */'
with_mutant m3; expect_red m3 "the sRGB refusal"

echo "mdltexture: the differential is green on a real device, and all three mutants are red"
# THE SCRATCH IS REMOVED HERE, except the mutants' output, which is the evidence.
rm -f "$work"/real "$work"/m1 "$work"/m2 "$work"/m3 "$work"/*.o