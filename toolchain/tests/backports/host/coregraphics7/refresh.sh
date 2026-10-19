#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=$here/../../device
build=${COREGRAPHICS7_BUILD:-$(runs_folder revenant-coregraphics7-refresh)}
rm -rf "$build"
mkdir -p "$build"
cat > "$build/main.m" <<'M'
#import "coregraphics7-cases.h"
int main(void)
{
    @autoreleasepool {
        printf("// The answers of the host's CoreGraphics, written by host/coregraphics7/refresh.sh from coregraphics7-cases.m.\n");
        revenant_cg7_cases(^(NSString *name, NSString *value) {
            printf("    {\"%s\", \"%s\"},\n", [name UTF8String], [value UTF8String]);
        });
    }
    return 0;
}
M
xcrun clang -fobjc-arc -w -I"$device" "$build/main.m" "$device/coregraphics7-cases.m" -framework Foundation -framework CoreGraphics -o "$build/refresh"
"$build/refresh" > "$device/coregraphics7-expectations.h"
wc -l "$device/coregraphics7-expectations.h"
