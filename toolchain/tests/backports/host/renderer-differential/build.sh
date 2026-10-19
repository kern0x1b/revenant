#!/bin/sh
# build.sh -- the renderer's five properties and its arithmetic, asked of the system's own
# UITextDragPreviewRenderer and of the port's in one process, under Mac Catalyst.
#
# The two classes are reached differently, and that is the whole trick:
#
#   * the port's file is compiled ALONE, with -D renaming the class it implements, so it is linked
#     as a second class rather than colliding with the system's;
#   * this comparison is compiled WITHOUT the -D, so its own translation unit still names the
#     system's class, and the port's is reached by name at run time with NSClassFromString.
#
# So the -D reaches the port's translation unit alone. That is the usual reason a renamed class
# comes out "not found": the rename reached the comparison too, or the renamed object was never
# linked.
#
#   DDR_ROOT=<the checkout> FLEET_HEAVY_LANE=fast sh tests/backports/host/renderer-differential/build.sh
#
# A heavy build, so it runs through heavy.sh, and its output is the two logs it names.
set -eu

# The port checkout, found the way every other host test finds it, with DDR_ROOT as the override.
# It used to be REQUIRED and unset, so the script died on `${DDR_ROOT:?}` before compiling anything
# and the sweep had no run.sh to run: this is not an external input at all, it is this repository.
here=$(cd "$(dirname "$0")" && pwd)
root=${DDR_ROOT:-$here/../../../..}
port=$root/packages/a/apple-backports/UIKit/UITextDragPreviewRenderer11.m
build=${DDR_BUILD:-$root/.agent-work/runs/renderer-differential-build}
sdk=$(xcrun --show-sdk-path)
port_name=CharonHostCopyTextDragPreviewRenderer
mkdir -p "$build"

# The port's own file, on its own, with the rename. Its include path is the port's UIKit directory
# and nothing of the comparison's.
echo "== the port's object, compiled alone with the rename:"
set -x
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
    -DUITextDragPreviewRenderer=$port_name \
    -I "$root/packages/a/apple-backports/UIKit" \
    -c "$port" -o "$build/port.o"
set +x
nm -gU "$build/port.o" | grep -E "OBJC_CLASS_\$_" | sed 's/^/   /'

# The comparison, with no rename at all, so its TU names the system's class.
echo "== the comparison, compiled without the rename:"
set -x
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
    -I "$root/packages/a/apple-backports/UIKit" \
    -c "$here/compare.m" -o "$build/compare.o"
set +x

# The mutant: the same port file with one rect a point out, which is what a wrong adjustment is.
sed 's/^        firstLineRect->origin = CGPointMake(firstLineRect->origin.x + origin.x,$/        firstLineRect->origin = CGPointMake(firstLineRect->origin.x + origin.x + 1,/' \
    "$port" > "$build/mutant.m"
grep -c "origin.x + 1" "$build/mutant.m"
set -x
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
    -DUITextDragPreviewRenderer=$port_name \
    -I "$root/packages/a/apple-backports/UIKit" \
    -c "$build/mutant.m" -o "$build/mutant.o"

link() {
    echo "== the link line:"
    set -x
    xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
        -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" "$@" \
        -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore \
        -o "$build/probe"
    set +x
}

link "$build/compare.o" "$build/port.o"
nm -gU "$build/probe" | grep -E "OBJC_CLASS_\$_(UITextDragPreviewRenderer|$port_name)" | sed 's/^/   both classes in the binary: /'

echo "== the clean pair:"
"$build/probe" > "$build/clean.log" 2>&1 || true
tail -1 "$build/clean.log"
clean_differing=$(grep -c DIFFER "$build/clean.log" || true)

link "$build/compare.o" "$build/mutant.o"
echo "== the mutant, one rect a point out:"
"$build/probe" > "$build/mutant.log" 2>&1 || true
tail -1 "$build/mutant.log"
rect_differing=$(grep -c DIFFER "$build/mutant.log" || true)

# The second mutant: the same file with the null-or-empty condition removed, which is the wrong
# renderer as it stood before the fix. It must go red on exactly the cases the condition covers and
# on no other, so its count is the number of values the fix is responsible for.
python3 - "$port" "$build/mutant-nocondition.m" <<'PYREMOVE'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
before = s
for name in ("firstLineRect", "bodyRect", "lastLineRect"):
    s = s.replace("if (%s && !CGRectIsEmpty(*%s))" % (name, name), "if (%s)" % name)
assert s != before, "the condition was not found to remove"
open(dst, "w").write(s)
print("   the condition removed from", before.count("!CGRectIsEmpty"), "places")
PYREMOVE
grep -c "!CGRectIsEmpty" "$build/mutant-nocondition.m" || echo "   no condition left"
set -x
xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" \
    -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w \
    -DUITextDragPreviewRenderer=$port_name \
    -I "$root/packages/a/apple-backports/UIKit" \
    -c "$build/mutant-nocondition.m" -o "$build/mutant-nocondition.o"
set +x
link "$build/compare.o" "$build/mutant-nocondition.o"
echo "== the mutant with the condition removed:"
"$build/probe" > "$build/mutant-nocondition.log" 2>&1 || true
tail -1 "$build/mutant-nocondition.log"
nocondition_differing=$(grep -c DIFFER "$build/mutant-nocondition.log" || true)

# The two assertions that make this a gate and not a report. The clean pair must agree with the
# system, or the port is wrong; the no-condition mutant must not, or the fix is not what the mutant
# removes. The rect+1 mutant is inert by construction -- every recorded first-line rect is empty,
# so an offset inside the guarded branch has nothing to act on -- and is not asserted on.
clean_compared=$(awk '/^compared/ {gsub(/,/,"",$2); print $2}' "$build/clean.log")
nocondition_compared=$(awk '/^compared/ {gsub(/,/,"",$2); print $2}' "$build/mutant-nocondition.log")
status=0
if [ "$clean_differing" != "0" ]; then
    echo "FAIL: the clean pair differs from the system in $clean_differing of $clean_compared values"
    status=1
fi
if [ "$nocondition_differing" = "0" ]; then
    echo "FAIL: the no-condition mutant is green, so it does not test the fix"
    status=1
fi
[ "$status" -eq 0 ] && echo "PASS: clean 0/$clean_compared differing, no-condition mutant $nocondition_differing/$nocondition_compared"
exit $status
