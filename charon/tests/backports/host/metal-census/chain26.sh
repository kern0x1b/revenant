#!/bin/sh
# chain26.sh - the top of the Metal 4 command chain, against Apple's own objects, and the two
# mutations the case has to notice.
#
#     sh tests/backports/host/metal-census/chain26.sh
#
# WHAT THIS COVERS AND WHY IT IS NOT THE WHOLE CHAIN. Apple 4 is present on this machine and a live
# queue can be made through -[MTLDevice newMTL4CommandQueue], so the queue and the two descriptors have
# an oracle. Two things do not, and the case prints both from APPLE'S side so the claim is a measurement:
#
#   * -[MTLDevice newCommandQueueWithDescriptor:] raises on this SDK - Apple's own queue sends
#     -disableIOFencing to the descriptor and the SDK's descriptor does not implement it;
#   * -[MTL4CommandQueue beginCommandBufferWithAllocator:] is not implemented on Apple's own queue here,
#     so there is no live Metal 4 command buffer to compare against and nothing below it either.
#
# AND THE QUEUE ITSELF IS ABSENT FROM THIS CASE FOR A THIRD REASON, which is not Apple's: the port's
# queue wraps the port's CharonMetalQueue, which holds an EAGL context over OpenGL ES 2.0, and
# OpenGLES/EAGL.h is a DEVICE framework - a host binary cannot compile it. So the queue, its two device
# factories and the capture scope over it are in the next batch with the rest of the chain, and the two
# descriptors and the error domain - which hold only values - are here.
#
# THE PORT'S TWO DESCRIPTORS ARE RENAMED through a #define inside the translation unit this script
# writes, and NOT with a -D on the command line: the same file with the same flags and the same -D
# produced an object carrying Apple's name in one invocation and the port's in another (see
# descriptors26.sh). The binary is asked for the renamed symbols and the run stops if they are absent.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/chain26}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -rf "$work"
mkdir -p "$work/port"

S="$root/packages/a/apple-backports"
sdk=$(xcrun --show-sdk-path --sdk macosx)
target="-target arm64-apple-macos26.0 -isysroot $sdk"
common="$target -fobjc-arc"
frameworks="-framework Foundation -framework Metal"
includes="-I $S -I $S/Metal -I $S/Foundation -I $work/port"

# THE PORT'S FILE, RENAMED. Only the four names this case needs are renamed: the two descriptors, the
# queue class, and the device factory that makes one - the capture manager's Metal 4 scope method is on
# a class Apple's framework also has, and the port's own is reached through the existing Metal 3 method
# it forwards to, so nothing else has to move.
cat > "$work/port/port.m" <<'PORTTU'
/* Written by tests/backports/host/metal-census/chain26.sh: the port's Metal 4 command chain under
 * names this host does not have, so Apple's keeps the real ones and the two can be compared. */
#define MTL4CommandQueueDescriptor charonHost_MTL4CommandQueueDescriptor
#define MTL4CommandBufferOptions charonHost_MTL4CommandBufferOptions
#include "MTL4CommandChain26.m"
PORTTU
cp "$work/port/port.m" "$work/port/port-pristine.m"

build() {   # $1 output name
    rm -f "$work/$1" "$work/$1-case.o" "$work/$1-port.o"
    # shellcheck disable=SC2086
    xcrun clang $common -c "$here/descriptors26-chain.m" -o "$work/$1-case.o" > "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the case) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -3 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common $includes -c "$work/port/port.m" -o "$work/$1-port.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 (the port, renamed) does not build" >&2
        sed -n '/error:/,$p' "$work/$1.log" | head -4 | sed 's/^/    /' >&2
        exit 1
    }
    # shellcheck disable=SC2086
    xcrun clang $common $frameworks -o "$work/$1" "$work/$1-case.o" "$work/$1-port.o" >> "$work/$1.log" 2>&1 || {
        echo "RUN FAILED  $1 does not link" >&2
        sed -n '/Undefined symbols/,$p' "$work/$1.log" | sed -n '2,6p' | sed 's/^/    /' >&2
        exit 1
    }
}

echo "the top of the Metal 4 command chain, against Apple's own objects:"
build real

# THE PORT'S SYMBOLS MUST BE THERE UNDER THE RENAMED NAMES. Metal is linked and Apple 4 is present on
# this machine, so a case that read Apple's own objects would agree with itself and every line above
# would be worth nothing.
for name in _OBJC_CLASS_\$_charonHost_MTL4CommandQueueDescriptor _OBJC_CLASS_\$_charonHost_MTL4CommandBufferOptions; do
    if ! nm -g "$work/real" 2>/dev/null | grep -q "$name"; then
        echo "FAIL: the binary does not define $name" >&2
        echo "  the case would then be measuring Apple's own framework and calling it the port's" >&2
        exit 1
    fi
done
echo "  the port's descriptors are DEFINED in the binary, under their renamed names"
timeout 120 "$work/real" || { echo "FAIL: the command chain differential failed" >&2; exit 1; }

# THE CONTROL: a mutation that does not compile is "RUN FAILED", never red, and no binary may be left.
echo "the control: a mutation that does not compile is RUN FAILED, not red"
cp "$work/port/port-pristine.m" "$work/port/broken.m"
printf '\n@interface CharonBrokenByTheControl\n' >> "$work/port/broken.m"
rm -f "$work/broken" "$work/broken-port.o"
# shellcheck disable=SC2086
if xcrun clang $common $includes -c "$work/port/broken.m" -o "$work/broken-port.o" > "$work/broken.log" 2>&1; then
    echo "FAIL: the control's broken mutation COMPILED, so it proves nothing" >&2
    exit 1
fi
if [ -e "$work/broken" ]; then
    echo "FAIL: the control left a binary behind, which is how a stale object reads as green" >&2
    exit 1
fi
# AND THE COMPILER MUST HAVE SAID WHY: a control that fails because nothing ran is the same defect as
# one that fails for the wrong reason, so the log has to carry an error line.
if ! grep -q 'error:' "$work/broken.log"; then
    echo "FAIL: the control did not build but the log has no error line - see $work/broken.log" >&2
    exit 1
fi
echo "  ok   RUN FAILED: the broken mutation did not build, and the compiler said why: $(grep -m1 'error:' "$work/broken.log" | cut -c1-90)"
echo "  ok   and no binary was left to run"

# THE MUTATIONS: one per thing the port decides here. The descriptor's label being a COPY, and the
# queue's label being kept at all - the second because a getter that returned the descriptor's or
# nothing would pass every other check in the case.
# The mutation is a COPY OF THE PORT'S OWN SOURCE with the change, and the wrapper unit includes THAT
# copy - not a change to the wrapper, which holds only #defines and would never contain the text. The
# first version of this mutated the wrapper and stopped with "the mutation must match exactly one
# place: appears 0", which is the harness saying it was about to mutate nothing.
mutate() {   # $1 label, $2 old text, $3 new text
    python3 - "$S/Metal/MTL4CommandChain26.m" "$work/port/$1-source.m" "$2" "$3" <<'PYEOF'
import sys
src, out, old, new = sys.argv[1:5]
text = open(src).read()
assert text.count(old) == 1, "the mutation must match exactly one place: %r appears %d" % (old, text.count(old))
open(out, "w").write(text.replace(old, new, 1))
PYEOF
    [ -s "$work/port/$1-source.m" ] || { echo "FAIL: the mutation $1 wrote nothing" >&2; exit 1; }
    sed "s|MTL4CommandChain26.m|$1-source.m|" "$work/port/port-pristine.m" > "$work/port/port.m"
    if cmp -s "$work/port/port.m" "$work/port/port-pristine.m"; then
        echo "FAIL: the mutation $1 did not change the unit, so it would run the real code" >&2
        exit 1
    fi
    build "$1"
}

expect_red() {   # $1 mutant name
    if timeout 120 "$work/$1" > "$work/$1.out" 2>&1; then
        echo "FAIL  $1 is NOT red - this behaviour is measured by nothing" >&2
        exit 1
    fi
    line=$(grep -m1 'FAIL' "$work/$1.out" | sed 's/^ *FAIL /  /')
    if [ -z "$line" ]; then
        echo "FAIL  $1 produced no assertion line - see $work/$1.out" >&2
        sed -n 1,4p "$work/$1.out" | sed 's/^/    /' >&2
        exit 1
    fi
    echo "  red  $line"
}

echo "the mutations: one per thing the port decides here"
# M1 IS THE DESCRIPTOR'S LABEL NOT BEING COPIED. The header says `copy`, and the case checks it by
# changing the caller's string after the fact - a getter that kept the caller's NSMutableString would
# answer the changed text.
mutate m1 '    _label = [label copy];' '    _label = label;'
expect_red m1

# M2 IS THE DESCRIPTOR FORGETTING THE LABEL ENTIRELY, which a copy check alone would not see: a
# descriptor whose -copyWithZone: dropped it answers nil while the set still worked.
mutate m2 '    copy.label = _label;
    copy.feedbackQueue = _feedbackQueue;' '    copy.feedbackQueue = _feedbackQueue;'
expect_red m2

echo "chain26: the differential is green, the control is RUN FAILED, and both mutants are red"
# THE SCRATCH IS REMOVED HERE.
rm -rf "$work"