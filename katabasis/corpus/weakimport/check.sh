#!/bin/sh
# check.sh — weak imports, by what the translated program does and by what strict says.
#   1. A call stub is weak or strong by its own image: a library that checks for getppid does not excuse an executable
#      that calls it. Where the image has bind entries for its stubs it says so twice, and only an image without them
#      (one pulled out of a shared cache, unbind.py) depends on the stub's own symbol-table flag: that case is the one
#      the exit status tells old from new by. Needs xlate/build.
#   2. The program runs on the iPad 2 twice, built natively for iOS 6 and translated from arm64, and both print what
#      expected.txt says: the translation is right where it prints what the device itself prints. The two outputs are
#      kept as out/run-native.txt and out/run.txt. Needs a claimed device (workspace skill device-session):
#      CHARON_DEVICE_HOLDER and CHARON_DEVICE exported, the claim held.
set -eu
LAB=$(cd "$(dirname "$0")/../.." && pwd)
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$here/out}
CHARON=${CHARON:-$HOME/Git/projects/ios/charon}
mkdir -p "$out"
xlate=$LAB/xlate/build/xlate
CC="xcrun clang -target arm64-apple-ios12.0 -isysroot $SDK -O2 -w"

$CC -dynamiclib -install_name @rpath/libweaklib.dylib "$here/weaklib.c" -o "$out/libweaklib.dylib"
$CC "$here/strong.c" "$out/libweaklib.dylib" -o "$out/strong"
$CC "$here/weakonly.c" "$out/libweaklib.dylib" -o "$out/weakonly"
python3 "$here/unbind.py" "$out/strong" "$out/strong-unbound"
python3 "$here/unbind.py" "$out/libweaklib.dylib" "$out/libweaklib-unbound.dylib"
: > "$out/passthrough.txt"
lift() {
  "$xlate" --base 0x10000000 --output "$out/$1.bc" --layout "$out/$1.layout" --passthrough "$out/passthrough.txt" \
    --state-header "$out/$1.h" "$out/$1" "$out/${2:-libweaklib.dylib}" 2> "$out/$1.err"
}
if lift strong; then echo "FAIL: strong's call stub to getppid passed because libweaklib imports it weakly"; exit 1; fi
grep -q 'strong: call stub for unresolved import _getppid' "$out/strong.err" || { echo "FAIL: strong was refused for another reason"; cat "$out/strong.err"; exit 1; }
! grep -q 'libweaklib.dylib: call stub' "$out/strong.err" || { echo "FAIL: libweaklib's weak stub was refused"; exit 1; }
# The same executable without its bind entries: the stub is refused for its own symbol-table flag alone.
if lift strong-unbound; then echo "FAIL: a strong stub with no bind entry passed because libweaklib imports getppid weakly"; exit 1; fi
grep -q 'strong-unbound: call stub for unresolved import _getppid' "$out/strong-unbound.err" || { echo "FAIL: strong-unbound was refused for another reason"; cat "$out/strong-unbound.err"; exit 1; }
# And the library that checks, without its bind entries: its weak stub is still weak, by its own flag.
lift weakonly libweaklib-unbound.dylib || { echo "FAIL: a weak stub with no bind entry was refused"; cat "$out/weakonly.err"; exit 1; }
lift weakonly || { echo "FAIL: a call stub that only libweaklib makes, weakly, was refused"; cat "$out/weakonly.err"; exit 1; }

$CC "$here/main.c" -o "$out/WeakImport-arm64"
cp "$LAB/p3/includes.h" "$out/includes.h"
"$LAB/scripts/translate.sh" "$out/WeakImport-arm64" "$out/includes.h" "$out/xl"
LD=$(ls $HOME/.xmake/packages/l/ld64/956.6/*/bin/ld | head -1)
xcrun clang -target armv7-apple-ios6.0 -isysroot "$SDK" -fuse-ld="$LD" -Wl,-no_pie -O2 -w "$here/main.c" -o "$out/WeakImportNative"
ldid -S "$out/WeakImportNative"
cat > "$out/copy.lua" <<'LUA'
import("device", {rootdir = path.join(os.getenv("HOME"), "Git/projects/ios/charon/modules")})
function main(src, dst) device.copy(device.bind(os.projectdir(), nil), src, dst) end
LUA
(cd "$CHARON" && xmake l "$out/copy.lua" "$out/xl/WeakImport" /var/tmp/WeakImport && xmake l "$out/copy.lua" "$out/WeakImportNative" /var/tmp/WeakImportNative)
(cd "$CHARON" && xmake device run "chmod +x /var/tmp/WeakImportNative && /var/tmp/WeakImportNative; rm -f /var/tmp/WeakImportNative") > "$out/run-native.txt"
(cd "$CHARON" && xmake device run "chmod +x /var/tmp/WeakImport && /var/tmp/WeakImport; rm -f /var/tmp/WeakImport") > "$out/run.txt"
diff "$here/expected.txt" "$out/run-native.txt" || { echo "FAIL: iOS 6 itself printed something else than expected.txt"; exit 1; }
diff "$here/expected.txt" "$out/run.txt" || { echo "FAIL: the translated program printed something else than iOS 6 does"; exit 1; }
echo "ok"
