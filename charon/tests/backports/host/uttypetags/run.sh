#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh charon-uttypetags)}
mkdir -p "$BUILD/shim/MobileCoreServices"
echo '#include <CoreServices/CoreServices.h>' > "$BUILD/shim/MobileCoreServices/MobileCoreServices.h"
renames="-DUTTypeIsDynamic=CharonHostUTTypeIsDynamic -DUTTypeIsDeclared=CharonHostUTTypeIsDeclared -DUTTypeCopyAllTagsWithClass=CharonPortUTTypeCopyAllTagsWithClass"
xcrun clang -fobjc-arc -w -I"$BUILD/shim" $renames -c "$UIKIT/UTTypeDynamic8.m" -o "$BUILD/dynamic.o"
xcrun clang -fobjc-arc -w -I"$BUILD/shim" $renames -c "$UIKIT/UTTypeAllTags8.m" -o "$BUILD/tags.o"
xcrun clang -fobjc-arc -w "$here/differential.m" "$BUILD/dynamic.o" "$BUILD/tags.o" -framework CoreServices -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$here/../uttypeconstants/expected-identifiers.tsv"
