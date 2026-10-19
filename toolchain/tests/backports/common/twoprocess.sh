# twoprocess.sh: the shared body of a differential whose two sides are separate processes, the host's classes in one and the port's in the
# other. Source it after `here` and `build` are set, with the test source and the port files as arguments:
#   . "$here/../../common/twoprocess.sh" "$here/test.m" "$uikit/UIFoo.m" ...
# The host binary is the test alone. The port binary compiles the port files and the test with every class the port files implement renamed
# to CharonPort<name>, so the test's names mean the port's classes in that build. The two outputs must match line for line.
twoprocess_run() {
    tp_test=$1
    shift
    tp_sdk=$(xcrun --show-sdk-path)
    # TWOPROCESS_FRAMEWORKS adds frameworks to both links, for a port file that uses one (say "-framework UserNotifications").
    tp_frameworks=${TWOPROCESS_FRAMEWORKS:-}
    tp_common="-target arm64-apple-ios15.0-macabi -isysroot $tp_sdk -iframework $tp_sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w -I $uikit"
    # A category is not renamed: it adds its methods to the host class of its name, which the port binary has as well.
    tp_renames=$(grep -h '^@implementation ' "$@" | grep -v '(' | awk '{ print "-D" $2 "=CharonPort" $2 }' | sort -u)
    xcrun clang $tp_common "$tp_test" -framework UIKit -framework Foundation -framework CoreGraphics $tp_frameworks -o "$build/host-app"
    # shellcheck disable=SC2086
    xcrun clang $tp_common $tp_renames "$@" "$tp_test" -framework UIKit -framework Foundation -framework CoreGraphics $tp_frameworks -o "$build/port-app"
    codesign -s - --force "$build/host-app" > /dev/null 2>&1
    codesign -s - --force "$build/port-app" > /dev/null 2>&1
    "$build/host-app" > "$build/host.txt"
    "$build/port-app" > "$build/port.txt"
    tp_checks=$(wc -l < "$build/host.txt" | tr -d ' ')
    if [ "$tp_checks" -eq 0 ]; then
        echo "FAIL: no checks ran"
        return 1
    fi
    if diff "$build/host.txt" "$build/port.txt" > "$build/diff.txt"; then
        echo "$tp_checks checks, the port's classes answer as the host's do"
    else
        echo "FAIL: the port and the host differ"
        cat "$build/diff.txt"
        return 1
    fi
}
