#!/bin/sh
# check.sh — a guest image that defines a name a host library also has (NSString, getpid) answers a bind only when
# the bind names that image: the superclass pointer, a class reference and a call stub, each. Two images that share
# a file name are told apart by install name, two with one install name are refused, and a guest image stands for a
# system library only where --replaces says so. Needs xlate/build.
set -eu
LAB=$(cd "$(dirname "$0")/../.." && pwd)
SDK=$(ls -d $HOME/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$here/out}
mkdir -p "$out"
xlate=$LAB/xlate/build/xlate
CC="xcrun clang -target arm64-apple-ios12.0 -isysroot $SDK -w"
$CC -dynamiclib -install_name @rpath/libfake.dylib -lobjc "$here/fake.m" -o "$out/libfake.dylib"
$CC -dynamiclib -install_name @rpath/libbridge.dylib "$here/bridge.c" -o "$out/libbridge.dylib"
$CC -framework Foundation "$here/app.m" -o "$out/host-app"
$CC "$here/app.m" "$out/libfake.dylib" -framework Foundation -o "$out/guest-app"
kind() {
  "$xlate" --objc-manifest "$out/$1.json" "$out/$1" "$out/libfake.dylib"
  python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['images'][0]['classes'][0]['superclass']['kind'])" "$out/$1.json"
}
[ "$(kind host-app)" = import ] || { echo "FAIL: a bind to Foundation's NSString was taken by libfake"; exit 1; }
[ "$(kind guest-app)" = local ] || { echo "FAIL: a bind to libfake's NSString was not resolved to libfake"; exit 1; }

# The class reference and the stub are not in the manifest: they are resolved when the image is lifted. A bind that
# a guest image answers leaves no reference to the host symbol in the module; one it does not answer does.
$CC -framework Foundation "$here/classref.m" -o "$out/host-classref"
$CC "$here/classref.m" "$out/libfake.dylib" -framework Foundation -o "$out/guest-classref"
$CC "$here/call.c" -o "$out/host-call"
$CC "$here/call.c" "$out/libfake.dylib" -o "$out/guest-call"
nm -u "$out/host-classref" "$out/libfake.dylib" | grep '^_' | sort -u > "$out/passthrough.txt"
# A passthrough bind is a declaration of the host symbol in the lifted module.
lift() {
  "$xlate" --base 0x10000000 --output "$out/$1.bc" --layout "$out/$1.layout" --passthrough "$out/passthrough.txt" \
    --state-header "$out/$1.h" --bridge "$out/libbridge.dylib" "$out/$1" "$out/libfake.dylib" "$out/libbridge.dylib" 2> "$out/$1.err"
  /opt/homebrew/opt/llvm/bin/llvm-dis "$out/$1.bc" -o "$out/$1.ll"
}
lift host-classref
lift guest-classref
grep -qF '@"OBJC_CLASS_$_NSString" = external' "$out/host-classref.ll" || { echo "FAIL: a class reference to Foundation's NSString was taken by libfake"; exit 1; }
! grep -qF '@"OBJC_CLASS_$_NSString"' "$out/guest-classref.ll" || { echo "FAIL: a class reference to libfake's NSString was not resolved to libfake"; exit 1; }

# A call stub to libSystem's getpid has no answer in a guest image that merely defines getpid, and strict says so.
if "$xlate" --base 0x10000000 --output "$out/host-call.bc" --layout "$out/host-call.layout" --passthrough "$out/passthrough.txt" \
  --state-header "$out/host-call.h" "$out/host-call" "$out/libfake.dylib" 2> "$out/host-call.err"; then
  echo "FAIL: a call stub to libSystem's getpid was taken by libfake"; exit 1
fi
grep -q 'call stub for unresolved import _getpid' "$out/host-call.err" || { echo "FAIL: xlate refused host-call for another reason"; cat "$out/host-call.err"; exit 1; }
"$xlate" --base 0x10000000 --output "$out/guest-call.bc" --layout "$out/guest-call.layout" --passthrough "$out/passthrough.txt" \
  --state-header "$out/guest-call.h" "$out/guest-call" "$out/libfake.dylib" 2> "$out/guest-call.err" || { echo "FAIL: a call stub to libfake's getpid was not resolved to libfake"; cat "$out/guest-call.err"; exit 1; }

# Two images with one file name and two install names, and a class each defines under one name: a bind takes the
# image whose install name it spells, not the one that comes first.
mkdir -p "$out/a" "$out/b"
$CC -dynamiclib -install_name @rpath/libcoll.dylib -lobjc "$here/coll_a.m" -o "$out/a/libcoll.dylib"
$CC -dynamiclib -install_name @rpath/sub/libcoll.dylib -lobjc "$here/coll_b.m" -o "$out/b/libcoll.dylib"
$CC -dynamiclib -install_name @rpath/libfrombx.dylib -lobjc "$here/frombx.m" "$out/b/libcoll.dylib" -o "$out/libfrombx.dylib"
$CC -lobjc "$here/froma.m" "$out/a/libcoll.dylib" "$out/libfrombx.dylib" -o "$out/coll-app"
"$xlate" --objc-manifest "$out/coll.json" "$out/coll-app" "$out/libfrombx.dylib" "$out/a/libcoll.dylib" "$out/b/libcoll.dylib" 2> "$out/coll.err"
python3 - "$out/coll.json" <<'PY' || { echo "FAIL: a bind to one of two same-named libraries was answered by the other"; exit 1; }
import json, sys
d = json.load(open(sys.argv[1]))
classes = {}
for index, image in enumerate(d["images"]):
    for c in image["classes"]:
        classes.setdefault(c["data"]["name"], []).append((index, c))
shared = {index: c["address"] for index, c in classes["Shared"]}
assert len(shared) == 2, shared
def superclass(name):
    [(_, c)] = classes[name]
    assert c["superclass"]["kind"] == "local", (name, c["superclass"])
    return c["superclass"]["address"]
# Images in argument order: 0 the app, 1 libfrombx, 2 a/libcoll (the app's link), 3 b/libcoll (libfrombx's).
assert superclass("FromA") == shared[2], ("FromA", superclass("FromA"), shared)
assert superclass("FromB") == shared[3], ("FromB", superclass("FromB"), shared)
PY

# Two images that are the same library are refused, naming both files.
cp "$out/a/libcoll.dylib" "$out/libcoll-copy.dylib"
if "$xlate" --objc-manifest "$out/dup.json" "$out/coll-app" "$out/a/libcoll.dylib" "$out/libcoll-copy.dylib" 2> "$out/dup.err"; then
  echo "FAIL: two images of one install name were accepted"; exit 1
fi
grep -q "libcoll-copy.dylib and .*/a/libcoll.dylib are both @rpath/libcoll.dylib" "$out/dup.err" || { echo "FAIL: the refusal does not name both images"; cat "$out/dup.err"; exit 1; }

# A bind to a system path is the host's library unless the invoker says a guest image stands for it.
mkdir -p "$out/guest"
$CC -dynamiclib -install_name /usr/lib/libsyscoll.1.dylib -lobjc "$here/coll_a.m" -o "$out/libsyscoll.1.dylib"
$CC -dynamiclib -install_name @rpath/libsyscoll.1.dylib -lobjc "$here/coll_a.m" -o "$out/guest/libsyscoll.1.dylib"
$CC -lobjc "$here/sysbound.m" "$out/libsyscoll.1.dylib" -o "$out/sys-app"
sub_kind() {
  python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['images'][0]['classes'][0]['superclass']['kind'])" "$1"
}
"$xlate" --objc-manifest "$out/sys-plain.json" "$out/sys-app" "$out/guest/libsyscoll.1.dylib" 2> "$out/sys-plain.err"
[ "$(sub_kind "$out/sys-plain.json")" = import ] || { echo "FAIL: a system-path bind was taken by an image of the same file name"; exit 1; }
grep -q -- "--replaces /usr/lib/libsyscoll.1.dylib=" "$out/sys-plain.err" || { echo "FAIL: no message offers --replaces"; cat "$out/sys-plain.err"; exit 1; }
"$xlate" --replaces /usr/lib/libsyscoll.1.dylib="$out/guest/libsyscoll.1.dylib" --objc-manifest "$out/sys-replaced.json" "$out/sys-app" "$out/guest/libsyscoll.1.dylib" 2> "$out/sys-replaced.err"
[ "$(sub_kind "$out/sys-replaced.json")" = local ] || { echo "FAIL: --replaces did not make the guest image answer the system-path bind"; exit 1; }
"$xlate" --replaces /usr/lib/libsyscoll.1.dylib="$out/nothing.dylib" --objc-manifest "$out/sys-bad.json" "$out/sys-app" "$out/guest/libsyscoll.1.dylib" 2> /dev/null && { echo "FAIL: --replaces naming a file that is no input was accepted"; exit 1; }
# One library named twice, or an image's own install name, is a choice between two answers by argument order: refused.
if "$xlate" --replaces /usr/lib/libsyscoll.1.dylib="$out/guest/libsyscoll.1.dylib" --replaces /usr/lib/libsyscoll.1.dylib="$out/a/libcoll.dylib" --objc-manifest "$out/sys-twice.json" "$out/sys-app" "$out/guest/libsyscoll.1.dylib" "$out/a/libcoll.dylib" 2> "$out/sys-twice.err"; then
  echo "FAIL: --replaces naming one library twice was accepted"; exit 1
fi
grep -q -- "--replaces /usr/lib/libsyscoll.1.dylib is given twice" "$out/sys-twice.err" || { echo "FAIL: the refusal of a library named twice says something else"; cat "$out/sys-twice.err"; exit 1; }
if "$xlate" --replaces @rpath/libcoll.dylib="$out/guest/libsyscoll.1.dylib" --objc-manifest "$out/sys-own.json" "$out/sys-app" "$out/guest/libsyscoll.1.dylib" "$out/a/libcoll.dylib" 2> "$out/sys-own.err"; then
  echo "FAIL: --replaces on an image's own install name was accepted"; exit 1
fi
grep -q -- "that is the install name of .*/a/libcoll.dylib" "$out/sys-own.err" || { echo "FAIL: the refusal of an install name says something else"; cat "$out/sys-own.err"; exit 1; }

# A library an image re-exports whole is answered for by that image: the app binds libreexported's function through
# libreexporter (LC_REEXPORT_DYLIB), and it counts as answered in the list translate.sh reads.
$CC -dynamiclib -install_name @rpath/libreexported.dylib "$here/reexported.c" -o "$out/libreexported.dylib"
$CC -dynamiclib -install_name @rpath/libreexporter.dylib "$here/reexporter.c" -Wl,-reexport_library,"$out/libreexported.dylib" -Wl,-rpath,"$out" -o "$out/libreexporter.dylib"
$CC "$here/callre.c" "$out/libreexporter.dylib" -Wl,-rpath,"$out" -o "$out/re-app"
otool -L "$out/re-app" | grep -q libreexporter.dylib || { echo "FAIL: the fixture does not bind through libreexporter"; exit 1; }
"$xlate" --objc-manifest "$out/re.json" --resolved-out "$out/re-resolved.txt" "$out/re-app" "$out/libreexporter.dylib" "$out/libreexported.dylib" 2> "$out/re.err"
grep -qxF _xl_reexported "$out/re-resolved.txt" || { echo "FAIL: a name libreexporter re-exports whole from libreexported was not listed as answered"; exit 1; }
"$xlate" --objc-manifest "$out/re-alone.json" --resolved-out "$out/re-alone-resolved.txt" "$out/re-app" "$out/libreexporter.dylib" 2> "$out/re-alone.err"
! grep -qxF _xl_reexported "$out/re-alone-resolved.txt" || { echo "FAIL: a re-export whose target is no input was listed as answered"; exit 1; }

# translate.sh takes what no host library has to supply from xlate's own answers, not from what the images export: an
# app that binds the host's NSString next to an embedded image that defines its own still needs NSString bridged, and
# one that binds the embedded image's does not.
cp "$LAB/p3/includes.h" "$out/includes.h"
for shape in host guest; do
  rm -rf "$out/$shape-xl"
  "$LAB/scripts/translate.sh" "$out/$shape-app" "$out/includes.h" "$out/$shape-xl" "$out/libfake.dylib" > "$out/$shape-xl.log" 2>&1 || { echo "FAIL: translate.sh on $shape-app"; tail -20 "$out/$shape-xl.log"; exit 1; }
done
grep -qxF '_OBJC_CLASS_$_NSString' "$out/host-xl/imports.txt" || { echo "FAIL: the host's NSString was dropped from imports.txt because an embedded image defines that name"; exit 1; }
! grep -qxF '_OBJC_CLASS_$_NSString' "$out/host-xl/guest-resolved.txt" || { echo "FAIL: a bind to the host's NSString was listed as answered by a guest image"; exit 1; }
! grep -qxF '_OBJC_CLASS_$_NSString' "$out/guest-xl/imports.txt" || { echo "FAIL: a bind to libfake's NSString was left in imports.txt"; exit 1; }
grep -qxF '_OBJC_CLASS_$_NSString' "$out/guest-xl/guest-resolved.txt" || { echo "FAIL: a bind to libfake's NSString was not listed as answered by it"; exit 1; }
echo "ok"
