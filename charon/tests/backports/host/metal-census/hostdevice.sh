#!/bin/sh
# hostdevice.sh - is there a Metal device on the machine these host cases run on?
#
#     sh tests/backports/host/metal-census/hostdevice.sh
#
# It exists because a dozen pages in facts/Metal and facts/MetalKit, and the cases beside them, used
# to give as the reason they create no device that `MTLCreateSystemDefaultDevice()` HANGS on a machine
# with no GPU - and two of them said it was measured hanging and killed. That is a claim about a
# machine, and this is the measurement of the machine. On this one the call answers, in well under a
# second:
#
#     ok   MTLCreateSystemDefaultDevice() answers
#            it is <AGXG16SDevice: 0x...>, name "Apple M4 Pro"
#            lowPower=0 headless=0 hasUnifiedMemory=1 maxThreadsPerThreadgroup=1024
#
# It then does one REAL thing with that device - a texture written and read back - so "it answers" is
# not read as "it works", and it answers the question the old claim was really about: a descriptor
# needs no device at all, because both sides are `[[X alloc] init]`. That is why the descriptor
# families create none, and it is the true reason; the hang was not.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
work=${WORK:-$root/.agent-work/runs/metal-census/hostdevice}
# ONE guard for every script that removes a scratch path - see work-guard.sh.
. "$here/work-guard.sh"
work_ok "$work" || { echo "FAIL: WORK=$work is not a usable scratch path; see work-guard.sh" >&2; exit 1; }
rm -f "$work/hostdevice"
mkdir -p "$work"

sdk=$(xcrun --show-sdk-path --sdk macosx)
xcrun clang -target arm64-apple-macos14.0 -isysroot "$sdk" -fobjc-arc -O0 \
    -framework Foundation -framework Metal -o "$work/hostdevice" "$here/hostdevice.m" || {
    echo "RUN FAILED  the case does not build or link" >&2
    exit 1
}
timeout 120 "$work/hostdevice" || { echo "FAIL: the host device measurement failed" >&2; exit 1; }

# THE CONTROL THE OLD CLAIM NEEDED AND DID NOT HAVE: a name no framework exports, asked the way a
# device is asked. A case that answered "there is a device" for anything would have passed then too.
echo "the control: a Metal class of a name that does not exist"
cat > "$work/control.m" <<'EOF'
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("%s\n", NSClassFromString(@"ZZZNoSuchNameCharonR16") ? "FOUND (wrong)" : "nil (right)");
    return NSClassFromString(@"ZZZNoSuchNameCharonR16") ? 1 : 0;
}
EOF
xcrun clang -target arm64-apple-macos14.0 -isysroot "$sdk" -fobjc-arc -O0 \
    -framework Foundation -framework Metal -o "$work/control" "$work/control.m" || {
    echo "RUN FAILED  the control does not build" >&2
    exit 1
}
timeout 60 "$work/control" || { echo "FAIL: the control found a class of a name that does not exist" >&2; exit 1; }
rm -f "$work/hostdevice" "$work/control" "$work/control.m"
echo "hostdevice: the machine has a Metal device, it works, and a descriptor needs none"