#!/bin/sh
# run.sh — the host probe for the os_signpost family the port carries over its own os_log
# (packages/frameworks/apple-backports/Foundation/RevenantOSSignpost11.m and RevenantOSSignpost12.m).
#
# It asks the host's own os_signpost the three questions the port's records make claims about: whether
# signposts are enabled, what the two id sources answer, and whether either of them is a reserved value.
# compare.py then requires the answers the port's code comments, facts/Foundation/OSLogSignpost.md and
# registry/Foundation/oslog.json state about the host to be the answers the host actually gives, so a
# record that drifts goes red. This is the check that would have found the high-bit convention the M-Z
# review measured: the host answers 0x1 for the first generated id, with the bit clear, and the port's
# records now say exactly that.
#
# The port's own build is NOT compiled here, and the reason is measured rather than guessed: the store
# reads an interval's subsystem and category out of RevenantOSLog's ivars, so its object file needs that
# class, and RevenantOSLog declares <OS_os_log> - which on a host is Apple's real protocol, so the runtime
# mixes the port's class with the host's os_log objects. Without the class the link fails with
# "_OBJC_IVAR_$_RevenantOSLog._subsystem ... ld: symbol(s) not found"; with the class compiled in, lldb
# shows a recursion in revenant_os_log_self (objc_storeStrong -> revenant_os_log_self -> objc_storeStrong).
# Compiling it anyway is what found the unchecked cast now fixed in RevenantOSSignpost11.m - that fix is in
# the series. What cannot be done from a host is a differential of this family; this file says so rather
# than claiming one.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${BUILD:-$(runs_fresh revenant-signpost)}
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path --sdk macosx)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -F $sdk/System/Library/Frameworks -iframework $sdk/System/iOSSupport/System/Library/Frameworks -fobjc-arc -w"
libs="-framework Foundation -framework SensorKit"

xcrun clang $common "$here/record.m" "$here/cases.m" $libs -o "$build/host"
SIGNPOST_RECORDS="$build/host.json" "$build/host"
xmake l "$here/compare.lua" "$build/host.json"
