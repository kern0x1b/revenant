#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${LAYOUT_SOURCES:-$here/../../../../packages/frameworks/apple-backports/UIKit}
harness=${LAYOUT_HARNESS:-$here/../../device}
build=${LAYOUT_BUILD:-$(runs_folder revenant-layout-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
files="NSLayoutConstraint+Activation.m UIView+LayoutMargins.m NSLayoutAnchor.m UIView+Anchors.m UILayoutGuide.m UIView+LayoutGuides.m UIStackView.m"
eight="NSLayoutConstraint+Activation.m UIView+LayoutMargins.m"
frameworks="-framework UIKit -framework QuartzCore -framework CoreGraphics -framework Foundation"
rm -rf "$build"
mkdir -p "$build/plain"
for file in $files; do
    xcrun clang $target -fobjc-arc -fvisibility=hidden -w -c "$sources/$file" -o "$build/plain/$file.o"
done
rename() {
    awk '{
        t = $0
        if (t ~ /^set[A-Z]/) { rest = substr(t, 4); print "-D" t "=setRevenantHost" rest; print "-D" tolower(substr(rest, 1, 1)) substr(rest, 2) "=revenantHost" rest }
        else if (t ~ /^is[A-Z]/) { rest = substr(t, 3); print "-D" t "=isRevenantHost" rest; print "-D" tolower(substr(rest, 1, 1)) substr(rest, 2) "=revenantHost" rest }
        else print "-D" t "=revenantHost" toupper(substr(t, 1, 1)) substr(t, 2)
    }' | sort -u
}
status=0
for variant in legacy native; do
    chosen=""
    for file in $files; do
        if [ "$variant" = native ]; then case " $eight " in *" $file "*) continue;; esac; fi
        chosen="$chosen $file"
    done
    plain=""
    for file in $chosen; do plain="$plain $build/plain/$file.o"; done
    classes=$(nm -g $plain | sed -n 's/.* S _OBJC_CLASS_\$_\(.*\)/-D\1=RevenantHost\1/p' | sort -u)
    selectors=$(nm $plain | sed -n 's/.*[-+]\[[A-Za-z_]*([A-Za-z]*) \([A-Za-z_]*\).*\]$/\1/p' | grep -v '^revenant_' | rename)
    shim=""
    extra=""
    if [ "$variant" = legacy ]; then
        extra="-DNSFoundationVersionNumber=revenantHostFoundationVersionNumber"
        printf 'const double revenantHostFoundationVersionNumber = 993.0;\n' > "$build/legacy-version.c"
        xcrun clang $target -c "$build/legacy-version.c" -o "$build/legacy-version.o"
        shim="$build/legacy-version.o"
    fi
    printf '%s\n' $classes $selectors $extra > "$build/$variant.flags"
    mkdir -p "$build/$variant"
    objects=""
    for file in $chosen; do
        xcrun clang $target -fobjc-arc -fvisibility=hidden -Wall -Wno-deprecated-declarations $(cat "$build/$variant.flags") -c "$sources/$file" -o "$build/$variant/$file.o" 2>/dev/null
        objects="$objects $build/$variant/$file.o"
    done
    xcrun clang $target -fobjc-arc -dynamiclib -install_name "@rpath/libRevenantHostLayout-$variant.dylib" $objects $shim $frameworks -o "$build/libRevenantHostLayout-$variant.dylib"
    xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/layout_test.m" "$harness/check.m" -L"$build" -lRevenantHostLayout-$variant -Wl,-rpath,"$build" $frameworks -o "$build/layout_test-$variant"
    if "$build/layout_test-$variant" > "$build/$variant.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok \|^info \|^known \|^  system \|^  ours ' "$build/$variant.log" || true
    echo "$variant: exit=$result log=$build/$variant.log"
    [ "$result" = 0 ] || status=1
done
exit $status
