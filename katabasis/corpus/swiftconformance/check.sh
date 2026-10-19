#!/bin/sh
# check.sh -- corpus/swiftconformance: a control for runtime/bridge.m's
# _dyld_register_func_for_add_image bridge (the fix for the _DictionaryStorage.allocate crash --
# katabasis round 12). fixture.swift: Widget's conformance to Hashable is a __swift5_proto record
# in THIS guest image, findable only if something told the Swift runtime this image exists and fed
# it that image's own sections -- exactly what the bridge now does. `x is Hashable` at run time
# either finds it (prints "hashable") or does not (prints "not-hashable").
#
# Built with charon's own from-source Swift toolchain (xmake package charon@swift, built from
# github.com/swiftlang/swift, no Xcode anywhere in that chain) -- NOT with Xcode's Command Line
# Tools' own swiftc, which cannot cross-compile for arm64-apple-ios: it fails with "Cannot read
# legacy layout file ... layouts-arm64.yaml" (CLT's own lib/swift/iphoneos/ resource directory
# does not exist; only lib/swift/macosx/ does, for the host platform). That file is not an
# Apple-internal artifact -- it ships in the open-source Swift repository itself
# (stdlib/toolchain/legacy_layouts/iphoneos/layouts-arm64.yaml) -- and charon@swift's own cached
# source checkout still has it even though its installed compiler's resource tree doesn't. Two
# frontend flags close the gap: -Xfrontend -read-legacy-type-info-path=<that file>, and
# -runtime-compatibility-version none (skips auto-linking the swiftCompatibilityNN/Concurrency
# back-deploy shims, which this build's resource tree doesn't carry either and this fixture's
# minimal Swift doesn't need). Found and reviewed 2026-09-27
# (coordination/reviews/2026-09-27-katabasis-fb1b557.md), which reproduced the CLT failure, traced
# it to the toolchain's resource tree rather than the SDK, and supplied the exact command below.
#
# Needs a claimed device (workspace skill device-session): CHARON_DEVICE_HOLDER and CHARON_DEVICE
# exported, the claim held. Output is kept in out/ (untracked): fixture-arm64, normal/, control/,
# run-normal.txt, run-control.txt.
#
# XL_SWIFTCONFORMANCE_ALSO_DEMO=1: additionally builds and runs the real swift/demo-arm64 the same
# way (normal vs. XL_TEST_NO_DYLD_IMAGE_BRIDGE=1), as a second, independent confirmation that the
# bridge is what separates a working Dictionary<String, Int> literal from the
# _DictionaryStorage.allocate crash -- the demo stays available as an additional check, not the
# primary one (round 12 already ran this by hand and got exactly this result; off by default here
# since it costs two more full scripts/translate.sh passes, ~3 min each).
set -eu
LAB=$(cd "$(dirname "$0")/../.." && pwd)
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$here/out}
CHARON=${CHARON:-$HOME/Git/projects/ios/charon}
R3=${XL_SWIFTCONFORMANCE_LIBS:-$LAB/.agent-work/runs/swift-c/r3/libs}
mkdir -p "$out"

# Several hashed installs of the same xmake package version can exist (one per consumer that
# pulled it); only the one whose own build kept its source cache carries the legacy-layouts file,
# so find that one by what it actually has, not by picking the first match -- the path itself is
# never hardcoded past the package name and version.
SWIFT=""
for candidate in "$HOME"/.xmake/packages/s/swift/*/*/; do
  layouts="${candidate}share/swift-source/stdlib/toolchain/legacy_layouts/iphoneos/layouts-arm64.yaml"
  if [ -x "${candidate}bin/swiftc" ] && [ -f "$layouts" ]; then
    SWIFT=$candidate
    LAYOUTS=$layouts
    break
  fi
done
if [ -z "$SWIFT" ]; then
  echo "no charon@swift install under ~/.xmake/packages/s/swift carries its own legacy_layouts source cache -- see this file's own header comment for what that is and why it's needed (coordination/reviews/2026-09-27-katabasis-fb1b557.md)" >&2
  exit 1
fi
SDK=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)

"$SWIFT/bin/swiftc" -target arm64-apple-ios12.0 -sdk "$SDK" \
  -Xfrontend -read-legacy-type-info-path="$LAYOUTS" \
  -runtime-compatibility-version none \
  -o "$out/fixture-arm64" "$here/fixture.swift"
# fixture-arm64 itself (otool -L) links only libSystem and @rpath/libswiftCore.dylib, but
# libswiftCore's OWN internals reach into libc++/libc++abi for things this fixture's protocol-
# conformance path exercises transitively (the demangler among them) -- confirmed by an early
# version of this script that omitted them: it built and ran, but crashed on device with "call to
# an address without translated code" before ever reaching main's own print. Lifting libc++/
# libc++abi as extra guest images (exactly like the real demo) gives real implementations instead
# of the unsupported-call traps a plain libSystem-only bridge leaves for their symbols.
export XL_REPLACES="/usr/lib/libc++.1.dylib=$R3/libc++.1.dylib"
scripts_translate() {  # scripts_translate INPUT OUT
  (cd "$LAB" && sh scripts/translate.sh "$1" "$LAB/targets/swiftdemo-includes.h" "$2" "$R3/libswiftCore.dylib" "$R3/libc++.1.dylib" "$R3/libc++abi.1.dylib")
}
XL_EXTRA_CFLAGS= scripts_translate "$out/fixture-arm64" "$out/normal"
XL_EXTRA_CFLAGS="-DXL_TEST_NO_DYLD_IMAGE_BRIDGE=1" scripts_translate "$out/fixture-arm64" "$out/control"

cat > "$out/copy.lua" <<'LUA'
import("device", {rootdir = path.join(os.getenv("HOME"), "Git/projects/ios/charon/modules")})
function main(src, dst) device.copy(device.bind(os.projectdir(), nil), src, dst) end
LUA
run_on_device() {  # run_on_device LOCAL_BINARY REMOTE_NAME OUT_LOG
  (cd "$CHARON" && xmake l "$out/copy.lua" "$1" "/var/tmp/$2")
  (cd "$CHARON" && timeout 60 xmake device run "chmod +x /var/tmp/$2 && /var/tmp/$2; echo exit=\$?; rm -f /var/tmp/$2") > "$3" 2>&1 || true
}
run_on_device "$out/normal/fixture" xl-fixture-normal "$out/run-normal.txt"
run_on_device "$out/control/fixture" xl-fixture-control "$out/run-control.txt"

grep -q "^hashable$" "$out/run-normal.txt" || { echo "FAIL: normal build (bridge active) did not find Widget's conformance"; cat "$out/run-normal.txt"; exit 1; }
grep -q "^not-hashable$" "$out/run-control.txt" || { echo "FAIL: control (bridge compiled out) unexpectedly found the conformance anyway"; cat "$out/run-control.txt"; exit 1; }
echo "ok: conformance found with the bridge (hashable), not found without it (not-hashable)"

if [ "${XL_SWIFTCONFORMANCE_ALSO_DEMO:-0}" = "1" ]; then
  DEMO=${XL_SWIFTCONFORMANCE_DEMO:-$LAB/../../../swift/demo-arm64}
  [ -x "$DEMO" ] || { echo "FAIL: XL_SWIFTCONFORMANCE_ALSO_DEMO=1 but no demo binary at $DEMO"; exit 1; }
  export XL_REPLACES="/usr/lib/libc++.1.dylib=$R3/libc++.1.dylib"
  demo_translate() {  # demo_translate OUT
    (cd "$LAB" && sh scripts/translate.sh "$DEMO" "$LAB/targets/swiftdemo-includes.h" "$1" "$R3/libswiftCore.dylib" "$R3/libc++.1.dylib" "$R3/libc++abi.1.dylib")
  }
  XL_EXTRA_CFLAGS= demo_translate "$out/demo-normal"
  XL_EXTRA_CFLAGS="-DXL_TEST_NO_DYLD_IMAGE_BRIDGE=1" demo_translate "$out/demo-control"
  run_on_device "$out/demo-normal/demo" xl-demo-normal "$out/run-demo-normal.txt"
  run_on_device "$out/demo-control/demo" xl-demo-control "$out/run-demo-control.txt"
  grep -q "^exit=139$" "$out/run-demo-control.txt" || { echo "FAIL: demo control did not crash (exit 139) as expected"; cat "$out/run-demo-control.txt"; exit 1; }
  if grep -q "^exit=139$" "$out/run-demo-normal.txt"; then
    echo "FAIL: demo normal build still crashed the same way"
    cat "$out/run-demo-normal.txt"
    exit 1
  fi
  echo "ok: demo control still crashes (exit 139) without the bridge, normal build runs past it"
fi
