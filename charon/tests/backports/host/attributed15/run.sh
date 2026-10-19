#!/bin/sh
# run.sh — the iOS 15.0 attributed-string object against the system's own, in one process.
#
# The port's four objects on classes the host declares are compiled with their selectors prefixed
# (tests/backports/host/prefix_selectors.py, the mechanism appgroup and uikit2 use) and attached at run
# time by tests/backports/host/foundation2/host-attach.c, so [s localizedAttributedStringWithFormat:...]
# is the system's answer and [s charonHost_localizedAttributedStringWithFormat:...] is the port's, in
# one process and side by side. The Markdown object also defines a class, and a class cannot be prefixed:
# it is renamed with the -D that its own object's symbols name (tests/backports/host/uikit2/renames.sh,
# the mechanism presentationintent uses), which the same pass carries.
#
# The build lives under the worktree and not in /tmp: nothing this project builds goes to /tmp.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
SOURCES=${SOURCES:-$root/packages/a/apple-backports/Foundation}
HARNESS=${HARNESS:-$here/../../device}
BUILD=${BUILD:-$root/.agent-work/build/attributed15}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-objc-property-implementation -Wno-objc-protocol-method-implementation -Wno-nullability-completeness -Wno-unguarded-availability"
rm -rf "$BUILD"
mkdir -p "$BUILD/plain" "$BUILD/ported"
printf '#import <Foundation/Foundation.h>\n#import <UIKit/UIKit.h>\n' > "$BUILD/declarations.h"

# The four objects whose members are added to classes the host declares: every selector they carry is
# prefixed, and the category list is renamed so the host can attach it at run time.
for file in NSAttributedStringLocalizedFormat15.m NSBundle+LocalizedAttributed15.m NSAttributedStringInflection15.m NSURLSessionTask+Delegate15.m; do
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$SOURCES/$file" -o "$BUILD/plain/$file.o"
    # shellcheck disable=SC2086
    python3 "$here/../prefix_selectors.py" "$SOURCES/$file" "$BUILD/ported/$file" charonHost_ \
        --declarations="$BUILD/declarations.h" -fobjc-arc -fvisibility=hidden $target $quiet -- "$BUILD/plain/$file.o"
    # shellcheck disable=SC2086
    xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$SOURCES" \
        -c "$BUILD/ported/$file" -o "$BUILD/ported/$file.o"
    perl -0777 -pi -e 's/__objc_catlist\0\0/__charon_catlist/g' "$BUILD/ported/$file.o"
done

# The Markdown object: its class is the port's own and is renamed, its three initialisers are members of
# NSAttributedString and are prefixed. One pass does both, because the -D is handed to the rewriter.
markdown=NSAttributedStringMarkdown15.m
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$SOURCES/$markdown" -o "$BUILD/plain/$markdown.o"
. "$here/../uikit2/renames.sh"
renames "$BUILD/plain/$markdown.o" > "$BUILD/renames"
# shellcheck disable=SC2046
python3 "$here/../prefix_selectors.py" "$SOURCES/$markdown" "$BUILD/ported/$markdown" charonHost_ \
    --declarations="$BUILD/declarations.h" -fobjc-arc -fvisibility=hidden $target $quiet $(cat "$BUILD/renames") -- "$BUILD/plain/$markdown.o"
# shellcheck disable=SC2046
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -I"$SOURCES" $(cat "$BUILD/renames") \
    -c "$BUILD/ported/$markdown" -o "$BUILD/ported/$markdown.o"
perl -0777 -pi -e 's/__objc_catlist\0\0/__charon_catlist/g' "$BUILD/ported/$markdown.o"

# The keys are constants, not selectors: the port's definitions are what the test reads, and the
# system's own are read beside them through a second handle on the image, so both values are in one
# process and neither is the other's. facts/Foundation/AttributedStrings15.md carries the reading.
xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -c "$SOURCES/NSAttributedStringKeys15.m" -o "$BUILD/ported/NSAttributedStringKeys15.o"

objects=""
for object in "$BUILD/ported"/*.o; do objects="$objects $object"; done
# The test is built for the same target as the port's objects, which is why the attributes it hands
# around are its own and not a colour and a font: a Catalyst build declares neither.
# shellcheck disable=SC2046
xcrun clang -fobjc-arc -Wall $target $quiet -I"$HARNESS" \
    "$here/differential.m" "$HARNESS/check.m" "$here/../foundation2/host-attach.c" $objects \
    -F "$sdk/System/iOSSupport/System/Library/Frameworks" -framework Foundation -framework UIKit -o "$BUILD/differential"
# The test's own copy of the prefixed declarations and the tool's must agree, so a rename the tool does
# differently is a failure here and not a silent "unrecognised selector" in the middle of a comparison.
for selector in charonHost_localizedAttributedStringWithFormat \
                initCharonHostWithFormat charonHost_appendLocalizedFormat charonHost_localizedAttributedStringForKey \
                charonHost_attributedStringByInflectingString charonHost_delegate charonHost_setDelegate \
                initCharonHostWithMarkdown initCharonHostWithMarkdownString initCharonHostWithContentsOfMarkdownFileAtURL; do
    grep -q "$selector" "$BUILD/declarations.h" || { echo "ported.h names $selector and the tool's declarations header does not" >&2; exit 1; }
done
[ -x "$BUILD/differential" ] || { echo "no binary at $BUILD/differential" >&2; exit 1; }
echo "bytes $(wc -c < "$BUILD/differential" | tr -d ' ')"
"$BUILD/differential"
