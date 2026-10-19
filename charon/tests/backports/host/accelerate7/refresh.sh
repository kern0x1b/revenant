#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=$here/../../device
build=${ACCELERATE7_BUILD:-$(runs_folder charon-accelerate7-refresh)}
rm -rf "$build"
mkdir -p "$build"
cat > "$build/main.m" <<'M'
#import "accelerate7-cases.h"
int main(void)
{
    @autoreleasepool {
        printf("// The answers of the host's vImage, written by host/accelerate7/refresh.sh from accelerate7-cases.m.\n");
        charon_vimage_cases(^(NSString *name, NSString *value) {
            printf("    {\"%s\", \"%s\"},\n", [name UTF8String], [value UTF8String]);
        });
    }
    return 0;
}
M
xcrun clang -fobjc-arc -w -I"$device" "$build/main.m" "$device/accelerate7-cases.m" -framework Foundation -framework CoreGraphics -framework Accelerate -o "$build/refresh"
"$build/refresh" > "$device/accelerate7-expectations.h"
wc -l "$device/accelerate7-expectations.h" | awk '{print $1 " lines"}'
