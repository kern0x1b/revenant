#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
UIKIT=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
BUILD=${BUILD:-$(runs_fresh revenant-uttype)}
# The port includes MobileCoreServices, which the host calls CoreServices.
mkdir -p "$BUILD/shim/MobileCoreServices"
echo '#include <CoreServices/CoreServices.h>' > "$BUILD/shim/MobileCoreServices/MobileCoreServices.h"
renames="-DUTTypeIsDynamic=RevenantHostUTTypeIsDynamic -DUTTypeIsDeclared=RevenantHostUTTypeIsDeclared"
xcrun clang -fobjc-arc -w -I"$BUILD/shim" $renames -c "$UIKIT/UTTypeDynamic8.m" -o "$BUILD/port.o"
xcrun clang -fobjc-arc -w "$here/differential.m" "$BUILD/port.o" -framework CoreServices -framework Foundation -o "$BUILD/differential"
"$BUILD/differential"
