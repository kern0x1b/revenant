#!/bin/sh
# Writes device/scenekit-defaults-expectations.h from the host's SceneKit: what a new object of each class the port
# carries answers, through the same cases the device test runs against the port.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=$here/../../device
build=${SCENEKIT_DEFAULTS_BUILD:-$(runs_folder revenant-scenekit-defaults-refresh)}
rm -rf "$build"
mkdir -p "$build"
cat > "$build/main.m" <<'M'
#import "scenekit-defaults-cases.h"
int main(void)
{
    @autoreleasepool {
        printf("// The answers of the host's SceneKit, written by host/scenekit-defaults/refresh.sh from scenekit-defaults-cases.m.\n");
        revenant_scenekit_default_cases(^(NSString *name, NSString *value) {
            printf("    {\"%s\", \"%s\"},\n", [name UTF8String], [value UTF8String]);
        });
    }
    return 0;
}
M
xcrun clang -fobjc-arc -Wall -I"$device" "$build/main.m" "$device/scenekit-defaults-cases.m" \
    -framework Foundation -framework AppKit -framework SceneKit -framework QuartzCore -o "$build/refresh"
"$build/refresh" > "$device/scenekit-defaults-expectations.h"
wc -l "$device/scenekit-defaults-expectations.h" | awk '{print $1 " lines"}'
