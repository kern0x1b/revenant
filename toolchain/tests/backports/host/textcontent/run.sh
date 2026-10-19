#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh charon-textcontent)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness"
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
sources="UITextField+ContentType.m UITextView+ContentType.m UISearchBar+ContentType.m"
rm -rf "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
mkdir -p "$BUILD/plain" "$BUILD/prefixed" "$BUILD/renamed"
renames=""
for file in UITextContentType UITextContentType11 UITextContentType12; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$UIKIT/$file.m" -o "$BUILD/$file.o"
    for name in $(xcrun nm -gU "$BUILD/$file.o" | awk 'NF == 3 {print $3}' | sed 's/^_//'); do
        renames="$renames -D$name=CharonHost$name"
    done
done
for file in UITextContentType UITextContentType11 UITextContentType12; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet $renames -c "$UIKIT/$file.m" -o "$BUILD/$file-renamed.o"
done
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$UIKIT" -c "$UIKIT/CharonTextContentType.m" -o "$BUILD/storage.o"
for source in $sources; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$UIKIT" -c "$UIKIT/$source" -o "$BUILD/plain/$source.o"
done
printf '#import <UIKit/UIKit.h>\n' > "$BUILD/prefixed/declarations.h"
for source in $sources; do
    python3 "$here/../prefix_selectors.py" "$UIKIT/$source" "$BUILD/prefixed/$source" charonHost_ --declarations="$BUILD/prefixed/declarations.h" -fobjc-arc $target $quiet -I"$UIKIT" -- "$BUILD"/plain/*.o
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$UIKIT" -include "$BUILD/prefixed/declarations.h" -c "$BUILD/prefixed/$source" -o "$BUILD/renamed/$source.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__charon_catlist/g' "$BUILD/renamed/$source.o"
done
xcrun clang -fobjc-arc $target $quiet "$here/differential.m" "$here/../foundation2/host-attach.c" "$BUILD"/UITextContentType*-renamed.o "$BUILD/storage.o" "$BUILD"/renamed/*.o \
    -framework UIKit -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
