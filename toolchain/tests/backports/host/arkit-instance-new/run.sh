#!/bin/sh
# run.sh - the instance -new of ARRaycastQuery, ARRaycastResult and ARTrackedRaycast.
#
# The SDK declares each one `- (instancetype)new NS_UNAVAILABLE;` from iOS 13.0: the headers are read here, and so is
# the generator's spec (spec/ARKit/declarations.tsv), which must say the same. The Catalyst copy of ARKit then answers
# the way check.m's expected lines say: no own definition, respondsToSelector: NO, and an unrecognised-selector call.
# The port defines none of the three (grep below), so it answers the same way.

set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../../.." && pwd)
runs=${RUNS:-$repo/.agent-work/runs/arkit-instance-new}
rm -rf "$runs"
mkdir -p "$runs"

sdk26=${REVENANT_GEN_SDK:-$HOME/Git/projects/ios/charon/.agent-work/sdk-26.2/iPhoneOS26.2.sdk}
hdr=$sdk26/System/Library/Frameworks/ARKit.framework/Headers
spec=$repo/packages/a/apple-backports/spec/ARKit/declarations.tsv
for c in ARRaycastQuery ARRaycastResult ARTrackedRaycast; do
    grep -qx -- "- (instancetype)new NS_UNAVAILABLE;" "$hdr/$c.h" || { echo "FAIL: $c.h does not declare -new unavailable"; exit 1; }
    grep -q "^method	c:objc(cs)$c(im)new	.*\*unavailable ios=13.0/" "$spec" || { echo "FAIL: the spec does not say $c -new is unavailable from 13.0"; exit 1; }
    if grep -q -- "-new\b\|(im)new\| new\]" "$repo/packages/a/apple-backports/ARKit/$c.m" 2>/dev/null; then
        echo "FAIL: the port defines $c -new"; exit 1
    fi
done

sdk=$(xcrun --sdk macosx --show-sdk-path)
ios=$sdk/System/iOSSupport/System/Library/Frameworks
target="-target $(uname -m)-apple-ios14.0-macabi"
xcrun clang -fobjc-arc -w -O1 $target -isysroot "$sdk" -iframework "$ios" -I "$here" \
    "$here/check.m" -framework Foundation -framework ARKit -o "$runs/check"
"$runs/check" > "$runs/host.txt"
cat "$runs/host.txt"

want=$runs/want.txt
cat > "$want" <<'WANT'
ARRaycastQuery instance-new own=NO
  respondsToSelector:new = NO
  call raised NSInvalidArgumentException
ARRaycastResult instance-new own=NO
  respondsToSelector:new = NO
  call raised NSInvalidArgumentException
ARTrackedRaycast instance-new own=NO
  respondsToSelector:new = NO
  call raised NSInvalidArgumentException
WANT
if diff "$want" "$runs/host.txt" > "$runs/diff.txt"; then
    echo "VERDICT ok: the three instance -new answers match the SDK's NS_UNAVAILABLE declarations"
else
    cat "$runs/diff.txt"; echo "FAIL: the host's answers differ from the expected lines"; exit 1
fi
