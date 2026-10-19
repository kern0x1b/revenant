#!/bin/sh
# tests/backports/device/coredata-wal-snapshot.m in the emulator at 6.1.3: with a Core Data store
# opened on a write-ahead log, does a second connection's read stay on its snapshot after a write? That
# is the one measurement facts/CoreData/QueryGeneration.md and the two query-generation rows turn on,
# and it cannot be asked of the host - macOS's Core Data opens its own stores and Apple's
# swift-corelibs-foundation carries no Core Data at all.
#
# One heavy job - a build and an emulated boot - so it runs in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/coredatanames/emulate.sh
# It prints the verdict either way, and both verdicts are a fact about the release.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
export COREDATAWAL_ROOT=$(cd "$here/../../../.." && pwd)
build=${COREDATAWAL_BUILD:-$(runs_folder charon-coredata-wal)}
device=${COREDATAWAL_DEVICE:-iPhone4,1}
release=${COREDATAWAL_RELEASE:-6.1.3}
rm -rf "$build"
mkdir -p "$build"
cat > "$build/xmake.lua" <<'LUA'
set_project("coredatawalsnapshot")
set_version("0.0.1")
-- The probe of tests/backports/device/coredata-wal-snapshot.m, built for the release and run in the
-- emulator: `xmake emulate -d iPhone4,1 -r 6.1.3 run /usr/libexec/coredatawalsnapshot`. It needs no
-- package of this repository's: it opens a store of its own and reads it.
add_repositories("charon https://github.com/kern0x1b/charon.git charon-repo-0.8.10")
add_addons("charon v0.8.13")
set_config("apple_minimum", "6.1.3")
includes("@addon/charon/apple-ios")
includes("@addon/charon/emulate")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

local root = os.getenv("COREDATAWAL_ROOT")
target("coredatawalsnapshot")
    add_rules("@addon/charon/daemon")
    add_files(path.join(root, "tests/backports/device/coredata-wal-snapshot.m"))
    add_mflags("-fobjc-arc")
    add_frameworks("CoreData", "Foundation")
    set_values("charon.version", "1.0")
    set_values("charon.control", "coredata-wal-snapshot")
LUA
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
xmake emulate -d "$device" -r "$release" install > install.log 2>&1
xmake emulate -d "$device" -r "$release" run /usr/libexec/coredatawalsnapshot > run.log 2>&1 || true
sed 's/\x1b\[[0-9;]*m//g' run.log | grep -E "^(release:|the store|the first|the second|verdict|the release)" || {
    echo "the probe said nothing:"; tail -20 run.log; exit 1
}
if ! grep -Eq 'pass.{0,12} on iPhone' run.log; then
    echo "the run was not a pass:"; sed 's/\x1b\[[0-9;]*m//g' run.log | tail -8; exit 1
fi
echo "logs=$build"
