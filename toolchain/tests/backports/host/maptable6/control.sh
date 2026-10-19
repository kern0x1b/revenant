#!/bin/sh
# The negative control of emulate.sh: the same suite against a copy of the port whose lookup of the runtime's weak
# references answers "none", so every weak side is watched only, as on 4.3. It must fail: exit 0 means it did, exit 1 that
# the suite passed a port whose native path was taken out and so does not tell the two paths apart. It runs on 5.1.1
# (MAPTABLE6_RELEASES, with 6.0 for the answers to compare), where the calls that read every entry's key are tried:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/maptable6/control.sh
# MAPTABLE6_ROUNDS and MAPTABLE6_BUILD are emulate.sh's; the logs are left in $MAPTABLE6_BUILD/run.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
build=${MAPTABLE6_BUILD:-$(runs_folder revenant-maptable6-control)}
rm -rf "$build"
mkdir -p "$build"
sed 's|dlsym(objc, "objc_loadWeakRetained") != NULL|0|' "$root/packages/a/apple-backports/Foundation/NSMapTable+Objects6.m" > "$build/port.m"
if cmp -s "$build/port.m" "$root/packages/a/apple-backports/Foundation/NSMapTable+Objects6.m"; then
    echo "the control's edit found nothing to change in the port"; exit 2
fi
export MAPTABLE6_PORT="$build/port.m" MAPTABLE6_BUILD="$build/run" MAPTABLE6_RELEASES=${MAPTABLE6_RELEASES:-"6.0 5.1.1"}
if sh "$here/emulate.sh" > "$build/control.log" 2>&1; then
    echo "control PASSED: the suite does not tell the paths apart"; exit 1
fi
# It failed for a reason the suite gave (a check, a crash), not because a build or a boot did.
if ! cat "$build"/run/[0-9]*.log | sed 's/\x1b\[[0-9;]*m//g' | grep -qE '^FAIL|crash\('; then
    echo "control failed without a check failing or a crash: see $build/control.log"; exit 3
fi
echo "control failed, as it must:"
for log in "$build"/run/[0-9]*.log; do
    echo "$(basename "$log" .log): $(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^FAIL|crash' | cut -c1-120 | tr '\n' ' ')"
done
exit 0
