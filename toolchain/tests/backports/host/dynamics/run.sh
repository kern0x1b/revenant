#!/bin/sh
# run.sh — differential host tests for UIKit Dynamics. The backport's Dynamics sources are compiled for Mac
# Catalyst with their classes and exported symbols renamed (RevenantHost…), so each test drives the host's own
# UIDynamicAnimator (the oracle, PhysicsKit) and ours side by side in one process, over the unmodified Box2D
# 2.2.1 the recipe builds. The sources are built twice: with REVENANT_HOST_DIFFERENTIAL, which runs the host's
# integrator (sub-step (float)1/120, box without inset or skin), for every comparison with the host; and as
# shipped (iOS 7.0's integrator), for the rows facts/UIKit/UIDynamicAnimator.md §12 gives only as 7.0 predictions.
# A test whose name ends in _ios70_test.m links the second build, every other *_test.m the first. Each test is its
# own binary; a test that does not build, crashes, or ends without its summary line fails.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${DYNAMICS_SOURCES:-$here/../../../../packages/a/apple-backports/UIKit}
harness=$here/../../device
build=${DYNAMICS_BUILD:-$(runs_folder revenant-dynamics-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
frameworks="-framework UIKit -framework QuartzCore -framework CoreGraphics -framework Foundation -lc++"
warnings="-Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation -Wno-incomplete-implementation -Wno-objc-property-implementation"
. "$here/../uikit2/renames.sh"

mkdir -p "$build/box2d"
rm -rf "$build/engine" "$build/plain" "$build/host" "$build/ios70" "$build/tests"
mkdir -p "$build/engine" "$build/plain" "$build/host" "$build/ios70" "$build/tests"

# The engine: the recipe's pinned archive, built with the recipe's own flags.
box2d=$here/../box2d
BUILD=$build/box2d
. "$box2d/source.sh"
engine_flags=$flags
for file in $(cd "$source" && find Box2D -name '*.cpp' | sort); do
    xcrun clang++ $target $engine_flags -w -I"$source" -c "$source/$file" -o "$build/engine/$(echo "$file" | tr / _).o"
done
engine=$(ls "$build"/engine/*.o)

# Every Dynamics source the backport has; the 9.0 classes and UIFloatRange's symbols join when their files exist.
files=""
for file in "$sources"/UIDynamic*.mm "$sources"/UI*Behavior.mm "$sources"/UIRegion.m "$sources"/UIFieldBehavior.m "$sources"/UIDynamicItemGroup.m "$sources"/UIFloatRange.m; do
    # UIDynamicBehavior.mm and UIDynamicItemBehavior.mm match both patterns: each file once.
    case " $files " in *" $file "*) continue ;; esac
    if [ -f "$file" ]; then
        files="$files $file"
    fi
done
[ -n "$files" ] || { echo "FAIL: no Dynamics source in $sources"; exit 1; }

code="-fobjc-arc -fvisibility=hidden $warnings -I$source"
# The package compiles every .mm as Box2D's archive is built, without RTTI and with hidden inline functions
# (compile() in modules/apple/backports.lua); a class deriving from a Box2D one needs Box2D's typeinfo otherwise.
objcxx="-fno-rtti -fvisibility-inlines-hidden"
flags_of() {
    case $1 in *.mm) echo "$code $objcxx" ;; *) echo "$code" ;; esac
}
for file in $files; do
    xcrun clang $target $(flags_of "$file") -DREVENANT_HOST_DIFFERENTIAL=1 -w -c "$file" -o "$build/plain/$(basename "$file").o"
done
renames "$(ls "$build"/plain/*.o)" > "$build/renames.flags"
host=""
ios70=""
for file in $files; do
    xcrun clang $target $(flags_of "$file") -DREVENANT_HOST_DIFFERENTIAL=1 $(cat "$build/renames.flags") -c "$file" -o "$build/host/$(basename "$file").o"
    xcrun clang $target $(flags_of "$file") $(cat "$build/renames.flags") -c "$file" -o "$build/ios70/$(basename "$file").o"
    host="$host $build/host/$(basename "$file").o"
    ios70="$ios70 $build/ios70/$(basename "$file").o"
done

# What the tests share: the harness, the oracle driver and item (dynamics.m), and a reader of our Box2D world.
xcrun clang $target -fobjc-arc -Wall -I"$harness" -c "$harness/check.m" -o "$build/tests/check.o"
xcrun clang $target -fobjc-arc -Wall -I"$harness" -I"$here" -c "$here/dynamics.m" -o "$build/tests/dynamics.o"
xcrun clang $target -fobjc-arc -Wall $objcxx -I"$source" -I"$here" -c "$here/engine.mm" -o "$build/tests/engine.o"
shared="$build/tests/check.o $build/tests/dynamics.o $build/tests/engine.o"

status=0
count=0
for test in "$here"/*_test.m; do
    [ -f "$test" ] || continue
    count=$((count + 1))
    name=$(basename "$test" _test.m)
    case $name in
    *_ios70) objects=$ios70 ;;
    *) objects=$host ;;
    esac
    if ! xcrun clang $target -fobjc-arc -Wall -I"$harness" -I"$here" "$test" $shared $objects $engine $frameworks -o "$build/tests/$name"; then
        echo "FAIL $name: the test did not build"
        status=1
        continue
    fi
    if "$build/tests/$name" > "$build/$name.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok ' "$build/$name.log" || true
    passed=$(grep -c '^ok ' "$build/$name.log" || true)
    failed=$(grep -c '^FAIL' "$build/$name.log" || true)
    if [ "$result" = 0 ] && ! grep -q '^checks=[1-9][0-9]* failures=0$' "$build/$name.log"; then
        echo "FAIL $name: exited 0 without reporting a check"
        result=1
    fi
    echo "$name: passed=$passed failed=$failed exit=$result log=$build/$name.log"
    [ "$result" = 0 ] || status=1
done
[ "$count" -gt 0 ] || { echo "FAIL: no *_test.m in $here"; exit 1; }
exit $status
