#!/bin/sh
# check.sh -- corpus/jumptable: a control for xlate/src/xlate.cpp's JumpTables::Resolve, which
# discovers the addresses a computed (register-indirect) branch can reach at build time by
# evaluating the guest byte table it dispatches through for every index its guards admit. Chasing
# the demo's crash past _DictionaryStorage.allocate (round 13: counts.sorted{} faults with "jump
# to an address that does not start a translated function") traced to exactly this mechanism
# missing a real target inside libswiftCore's demangler (swift::Demangle::__runtime::
# getUnspecialized): its table dispatch is guarded by two conditions --
# `(kind - 13) unsigned >= 6` (excluding [13, 18], handled by an earlier special case) and
# `kind <= 0x10f` -- so the domain reaching the table read is {0..12} u {19..271}, a gap in the
# middle. The old code accepted the first contiguous run (0..12), then broke out of the whole
# scan the instant it saw index 13 fall outside the domain, on the assumption (stated in the old
# comment) that the domain is one contiguous range. It silently never even attempted every address
# reachable only through 19..271, with no diagnostic (not even a "cannot decode function" line --
# the address was simply never a candidate).
#
# dispatch.s reproduces the shape directly (the exact instructions, not a C switch, which is not
# reliably lowered to this on demand): kind in {2, 3} is diverted to a special case BEFORE the
# table is read at all, so the admitted domain here is {0, 1} u {4, 5} -- a gap of its own, and
# kind 4/5's case bodies are reachable only past it, same as the real bug.
#
# Host-only, no device: this checks xlate's own build-time discovery (LayoutAndResolve + the main
# lift loop's JumpTables call), not a translated program's runtime behavior -- feeding dispatch.s
# straight to xlate and reading how many jump-table targets it reports finding.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$here/out}
LAB=$(cd "$here/../.." && pwd)
SDK=$(ls -d "$HOME"/.xmake/packages/i/iphoneos-sdk/16.4/*/Developer.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS16.4.sdk | head -1)
mkdir -p "$out"

# main.c is the driver (libc-free, so xlate lifts it without an unresolved-import call stub; its own
# header says why). Built here, not run: the verdict is xlate's reported count, not the guest's.
xcrun clang -target arm64-apple-ios12.0 -isysroot "$SDK" -O2 -w -o "$out/jumptable-arm64" "$here/main.c" "$here/dispatch.s"

: > "$out/passthrough.txt"
"$LAB/xlate/build/xlate" --base 0x10000000 --output "$out/out.bc" \
  --layout "$out/layout.txt" --state-header "$out/xl_state.h" \
  --passthrough "$out/passthrough.txt" "$out/jumptable-arm64" > "$out/xlate.log" 2>&1
cat "$out/xlate.log"

# 4 distinct case bodies exist (kind 0, 1, 4, 5 each reach a different one; 2 and 3 are diverted
# before the table read and are not part of this count); the old code found only 2 (0 and 1, the
# contiguous run before the gap). grep the exact reported count rather than just "not zero", so a
# regression that finds some-but-not-all targets (e.g. 2 or 3) is caught too, not just a total
# regression back to missing the table entirely.
grep -q ", 4 jump table targets," "$out/xlate.log" || {
  echo "FAIL: xlate did not report finding all 4 case bodies past the gap (see $out/xlate.log)"
  exit 1
}
echo "ok"
