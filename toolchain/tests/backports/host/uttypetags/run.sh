#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/frameworks/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh revenant-uttypetags)}
mkdir -p "$BUILD/shim/MobileCoreServices"
echo '#include <CoreServices/CoreServices.h>' > "$BUILD/shim/MobileCoreServices/MobileCoreServices.h"
renames="-DUTTypeIsDynamic=RevenantHostUTTypeIsDynamic -DUTTypeIsDeclared=RevenantHostUTTypeIsDeclared -DUTTypeCopyAllTagsWithClass=RevenantPortUTTypeCopyAllTagsWithClass"
xcrun clang -fobjc-arc -w -I"$BUILD/shim" $renames -c "$UIKIT/UTTypeDynamic8.m" -o "$BUILD/dynamic.o"
xcrun clang -fobjc-arc -w -I"$BUILD/shim" $renames -c "$UIKIT/UTTypeAllTags8.m" -o "$BUILD/tags.o"
xcrun clang -fobjc-arc -w "$here/differential.m" "$BUILD/dynamic.o" "$BUILD/tags.o" -framework CoreServices -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" "$here/../uttypeconstants/expected-identifiers.tsv"
