#!/bin/sh
# tests/backports/host/coreml as a device binary under xmake emulate: the Core ML surface on the
# device's own CPU, over the real containers, with every method the registry claims called at least
# once. One heavy job (a build and an emulated boot), so run it in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/coreml/emulate.sh
#
# The containers come from .agent-work/runs/coreml-predict/models, the ones the interpreter check
# and the host differential read; embed-models.lua writes them into the test's own header, so the
# device reads byte for byte what this host reads. COREML_MINIMUM and COREML_DEVICE name the
# release and the device; 6.1.3 on an iPad 2 is the port's own band.
#
# Leaves the logs in $COREML_BUILD and exits 1 on a failed check, a crash or a boot the emulator
# could not finish.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=${COREML_ROOT:-$(cd "$here/../../../.." && pwd)}
export COREML_ROOT=$root
models=${COREML_MODELS:-$(xmake l "$root/modules/workspace.lua" run coreml-predict)/models}
build=${COREML_BUILD:-$(runs_folder charon-coreml-device)}
device=${COREML_DEVICE:-iPad2,1}
release=${COREML_MINIMUM:-6.1.3}

# the containers, embedded: the test cannot open a file on this machine
xmake l "$root/tools/coreml/embed-models.lua" "$models" "$root/tests/backports/device/coreml-models.h"

rm -rf "$build"
mkdir -p "$build"
cp "$here/emulate/xmake.lua" "$here/emulate/control" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1 || { echo "the build failed:"; tail -20 build.log; exit 1; }
xmake emulate -d "$device" -r "$release" install > install.log 2>&1 || { echo "the install failed:"; tail -20 install.log; exit 1; }
xmake emulate -d "$device" -r "$release" run /usr/libexec/coreml > "$release.log" 2>&1 || true

# The verdict line names the run - pass, fail, crash, timeout or boot-blocked - between colour codes.
sed 's/\x1b\[[0-9;]*m//g' "$release.log" > "$release.plain"
if grep -qE '^FAIL' "$release.plain"; then
    echo "$release: failures"
    grep -E '^FAIL|uncaught' "$release.plain" | head -30
    exit 1
fi
if ! grep -Eq 'pass' "$release.plain"; then
    echo "$release: not a pass"
    tail -20 "$release.plain"
    exit 1
fi
# The count is printed on a pass as well as a failure: a verdict with no list behind it is a verdict
# nobody can check, and the guest's own log is at a path inside the guest that the run cannot open.
# So the test writes the count to stderr, and this is where it is read.
if grep -qE '^coreml: [0-9]+ checks' "$release.plain"; then
    grep -E '^coreml: [0-9]+ checks' "$release.plain" | tail -1
else
    echo "$release: pass (the guest printed no count: the run's own line is the verdict above)"
    grep -E 'pass on' "$release.plain" | tail -1
fi
