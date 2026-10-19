#!/bin/sh
# tests/swiftui/consumer: the package as a port takes it. A program that imports SwiftUI is built against the module the
# package installs and links its library, and what the build leaves behind is read afterwards: a package that installed a
# module without its library, or a library that carries no object of the module, is a failure here and not a surprise in
# somebody else's port. This is the check the queue asks for ("publish it as a package other recipes can add_deps"), and the
# one the fleet has no gate for (the coordinator's build-gate builds apple-backports only, and no gate compiles a Swift
# module that is not an overlay of the runtime).
#
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/swiftui/consumer/run.sh
#
# One heavy job: it installs charon@swiftui into the shared store and builds one program for armv7. The recipe's own digest
# is its buildhash, so a changed recipe is a different package and needs no force (charon AGENTS.md, Traps: the shared
# ~/.xmake store). SWIFTUI_ROOT names the checkout when this is not run from one; SWIFTUI_MINIMUM is the release the port
# builds for, 6.1.3 by default: what an armv7 device of the fleet runs.
#
# Known on this machine (2026-09-28): the install of charon@swiftui needs a swift-runtime of its own buildhash, and the
# store holds none for an armv7 build at 6.0 or 6.1.3, so xmake builds the runtime first — which fails in the runtime's own
# UIKit overlay ("'UITargetedPreview' is only available in iOS 13.0 or newer", UIKit.swift:713, the UIPointerEffect enum of
# swift-5.2.5's overlay, in the runtime's own source under ~/.xmake/cache/packages/2609/s/swift-runtime). The package's build
# step is therefore proved by hand for now (see the delivery), and this test takes over when the runtime builds again.
#
# The project it configures and builds lives under .agent-work/runs of the worktree, never in a temporary directory: the
# configured tree is evidence (it is what the resolution decided and what the build wrote) and the system temporary
# directory is wiped. The worktree's .agent-work is excluded in the repository, so nothing of it is ever tracked.
#
# One run at a time, and the lock that says so is a directory of this script's own, outside the store: two runs of the same
# project wait on the same package in the shared store, and a run that waits on a run of its own has two xmakes at 0% CPU
# and no output to say why. mkdir is the lock: it is atomic, it is ours, and a run that finds a stale one says so rather
# than waiting on it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
export SWIFTUI_ROOT=${SWIFTUI_ROOT:-$(cd "$here/../../.." && pwd)}
build=${SWIFTUI_BUILD:-$(cd "$here/../../.." && pwd)/.agent-work/runs/swiftui-consumer}
mkdir -p "$build"
if ! mkdir "$build/run.lock" 2>/dev/null; then
    echo "consumer: another run of this test is in $build (its lock is $build/run.lock, from $(stat -f %Sm "$build/run.lock"))" >&2
    exit 1
fi
trap 'rmdir "$build/run.lock" 2>/dev/null || true' EXIT INT TERM
echo "consumer: one run at a time, this one holds $build/run.lock"
# A project this tree already configured is resumed, not replaced: the resolution xmake wrote is what the build continues
# from, and it is the evidence of what the resolution decided, so nothing here throws it away to start over.
if [ ! -d "$build/project/.xmake" ]; then
    mkdir -p "$build"
    cp -R "$here" "$build/project"
    echo "consumer: configured a project in $build/project"
else
    echo "consumer: resuming the configured project in $build/project"
fi
# The locks of a run that was stopped are kept, not waited on. A lock left by a process that is gone is not a lock anyone
# holds: xmake waits for it, holds the store's own package locks while it waits, and a resolution that waits for a lock
# nobody holds is a job that never finishes. Each one is moved aside with its date, so what the stopped run was doing is
# still there to read.
for lock in "$build/project/xmake-addons.lock" "$build/project/.xmake"/*/*/project.lock; do
    [ -e "$lock" ] || continue
    kept="$build/stopped-run-locks/$(date +%Y%m%d-%H%M%S)-$(basename "$lock")"
    mkdir -p "$(dirname "$kept")"
    mv "$lock" "$kept"
    echo "consumer: the lock of a stopped run is kept aside, not waited on: $kept"
done
cd "$build/project"
# The configuration's own output goes to the log, not to /dev/null: a resolution that asks something is a resolution that
# waits, and a question nobody can read is a job that never finishes. Its input is the null device, so a question it asks
# anyway is answered with nothing rather than held open on the terminal of whoever started the job.
xmake f -y -c < /dev/null > "$build/configure.log" 2>&1 || { tail -40 "$build/configure.log"; exit 1; }
xmake -y < /dev/null >"$build/build.log" 2>&1 || { tail -40 "$build/build.log"; exit 1; }

binary=$(find "$build/project/build" -name consumer -type f -perm -u+x 2>/dev/null | head -1)
[ -n "$binary" ] || { echo "consumer: the build produced no binary"; tail -40 "$build/build.log"; exit 1; }

# The three things the package promises, read from the shared store rather than from the build tree: the module a port
# compiles against, its textual interface, and the library a port links.
store=${XMAKE_GLOBALDIR:-$HOME/.xmake}
library=$(find "$store/packages/s/swiftui" -name libEidolonSwiftUI.a 2>/dev/null | head -1)
[ -n "$library" ] || { echo "consumer: charon@swiftui installed no libEidolonSwiftUI.a under $store"; exit 1; }
installdir=$(dirname "$(dirname "$library")")
module=$installdir/lib/swift/iphoneos/SwiftUI.swiftmodule
[ -f "$module/armv7-apple-ios.swiftmodule" ] || { echo "consumer: no armv7 module in $module"; exit 1; }
[ -f "$module/SwiftUI.swiftinterface" ] || { echo "consumer: no interface in $module"; exit 1; }

# The module's own object is in the binary. A library that linked and carries nothing of SwiftUI is a library of no use:
# a top-level symbol of the module mangles as $s7SwiftUI, the module name and its length.
if ! nm -gU "$binary" 2>/dev/null | grep -q '\$s7SwiftUI'; then
    echo "consumer: the binary carries nothing of the SwiftUI module"; exit 1
fi
# And the module reached the compile: the interface names the declarations the program took from it, which is what a reader
# of the package reads.
grep -q "public struct VStack" "$module/SwiftUI.swiftinterface" || {
    echo "consumer: the interface names no VStack"; exit 1; }

# The resolution is in the log of the run, so what it decided is read with the rest.
echo "consumer: the resolution said"
sed -n '1,20p' "$build/configure.log"
echo "consumer: built against the module, linked the library, read the interface"
echo "  library:  $library"
echo "  module:   $module"
echo "  binary:   $binary"
