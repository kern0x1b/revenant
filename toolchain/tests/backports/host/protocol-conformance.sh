#!/bin/sh
# protocol-conformance.sh - the acceptance test for every protocol row marked `implemented`: the criterion in
# protocol-conformance.lua, run with the pinned toolchain the gate uses and the protocol headers the generator writes.
# No python. The exit status is the Lua check's: 0 every row conformant and every mutant red, 1 the gap rows are owed
# work, 3 the check itself is broken.
#
#     sh tests/backports/host/protocol-conformance.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../.." && pwd)
SDK=""
for candidate in "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk; do
    if [ -f "$candidate/SDKSettings.json" ]; then SDK="$candidate"; break; fi
done
[ -n "$SDK" ] || { echo "FAIL: no iOS 16.4 SDK" >&2; exit 1; }
# THE PINNED CLANG, the one tests/addon/protocol-sources.sh pins: a clang other than the library's answers a different question.
CLANG=${CLANG:-$HOME/.xmake/packages/l/llvm/23.1.1/6a8c97aaa69241df9ed69ac86f13a045/bin/clang}
[ -x "$CLANG" ] || { echo "FAIL: no clang at $CLANG; set CLANG to the pinned one" >&2; exit 2; }
work=${WORK:-$root/.agent-work/runs/protocol-conformance}
rm -rf "$work"
mkdir -p "$work/gen"
# The Metal protocol header is written at build time from spec/protocol-headers.tsv, so the check reads the same header the build does.
xmake l "$root/tools/gen.lua" protocolheaders --tree "$root" --framework Metal --out "$work/gen" > "$work/gen.log" 2>&1
CONF_ROOT="$root" CONF_SDK="$SDK" CONF_CLANG="$CLANG" CONF_GEN="$work/gen" CONF_WORK="$work" \
    xmake lua "$here/protocol-conformance.lua"
