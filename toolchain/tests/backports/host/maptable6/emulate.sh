#!/bin/sh
# tests/backports/host/maptable6 as a device binary under xmake emulate: the port against the release's own factories on
# 6.0, and the port alone on 4.3, 5.0 and 5.1.1, whose answers to the weak scenarios must be 6.0's; then, on each, a class
# that refuses a weak reference as the weak side of each table, whose outcome on 5.0 and later must be 6.0's. One heavy job
# (a build and an emulated boot a release, and one a case of the refusal), so run it in a slot of the machine:
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/maptable6/emulate.sh
# MAPTABLE6_ROUNDS=n sets the rounds of the two-thread check (default 20000). It needs the addon v0.8.11 in the shared xmake store, as any port does, and the firmware of the releases named below.
# MAPTABLE6_PORT names the port's source, for control.sh, which builds a port with its native path taken out.
# Leaves the logs in $MAPTABLE6_BUILD/<release>.log and exits 1 on a failed check or an answer that is not 6.0's.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
export MAPTABLE6_ROOT=$(cd "$here/../../../.." && pwd)
build=${MAPTABLE6_BUILD:-$(runs_folder revenant-maptable6-device)}
device=${MAPTABLE6_DEVICE:-iPhone2,1}
releases=${MAPTABLE6_RELEASES:-"6.0 4.3 5.0 5.1.1"}
export MAPTABLE6_PORT=${MAPTABLE6_PORT:-}
rm -rf "$build"
mkdir -p "$build"
cp "$here/emulate/xmake.lua" "$here/emulate/control" "$build/"
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
failed=0
for release in $releases; do
    xmake emulate -d "$device" -r "$release" install > "install-$release.log" 2>&1
    xmake emulate -d "$device" -r "$release" run /usr/libexec/maptable6 > "$release.log" 2>&1 || true
    # The verdict line names the run - pass, fail, crash, timeout or boot-blocked - between colour codes.
    if ! grep -Eq 'pass.{0,12} on iPhone' "$release.log" || grep -q '^FAIL' "$release.log"; then
        echo "$release: not a pass"; grep -E '^FAIL|fail|crash|timeout|blocked' "$release.log" || true
        failed=1
    else
        echo "$release: $(grep -E ' checks, ' "$release.log")"
    fi
done
# The release's own answers on 6.0 are what the port must give where the release has none.
for release in $releases; do
    [ "$release" = 6.0 ] && continue
    grep '^release ' 6.0.log | sed 's/^release /port /' > expected.txt
    grep '^port ' "$release.log" > answered.txt
    if diff expected.txt answered.txt > "diff-$release.txt"; then
        echo "$release: the port's $(wc -l < answered.txt | tr -d ' ') answers are 6.0's"
    else
        echo "$release: answers that are not 6.0's:"; cat "diff-$release.txt"
        failed=1
    fi
done
# A class that refuses a weak reference, as the weak side: 6.0 aborts, and so must the port wherever it forms the runtime's
# weak reference (5.0 and later). 4.3 has only the watch and holds the entry: its outcome must be "held, count 1, lookup found"
# (6.0 holds it too where the refusing class is on the strong side). A
# run that ends is one that aborted or held, so the line each leaves is what is compared, without addresses.
outcome() {
    sed 's/\x1b\[[0-9;]*m//g' "$1" | grep '^outcome ' | head -1 | sed -E 's/objc\[[0-9]+\]: //; s/\(0x[0-9a-f]+\)//'
}
cases="weakToStrong:key strongToWeak:value weakToWeak:key weakToWeak:value strongToStrong:key strongToStrong:value"
for release in $releases; do
    for c in $cases; do
        variant=${c%%:*}; side=${c##*:}
        for who in theirs port; do
            [ "$who" = theirs ] && [ "$release" != 6.0 ] && continue
            xmake emulate -d "$device" -r "$release" run /usr/libexec/maptable6 $who $variant $side > "refuse-$release-$who-$variant-$side.log" 2>&1 || true
        done
    done
done
for release in $releases; do
    for c in $cases; do
        variant=${c%%:*}; side=${c##*:}
        expected=$(outcome "refuse-6.0-theirs-$variant-$side.log" | sed 's/^outcome theirs /outcome port /')
        answered=$(outcome "refuse-$release-port-$variant-$side.log")
        if [ "$release" = 4.3 ]; then
            # The watch alone holds the entry: the divergence the facts state where 6.0 aborts (the weak side), so it is held to
            # that line; a strong side is held by 6.0 as well, and the line says which of the two it is by 6.0's own answer.
            held="outcome port $variant $side: held, count 1, lookup found"
            if [ "$answered" = "$held" ]; then
                if [ "$expected" = "$held" ]; then note="as 6.0 does"
                elif [ -n "$expected" ]; then note="the watch alone: held, where 6.0 aborts"
                else note="6.0 not run, so not compared"; fi
                echo "$release: $answered ($note)"
            else
                echo "$release: not the watch's hold: wanted '$held', got '$answered'"
                failed=1
            fi
        elif [ -n "$expected" ] && [ "$expected" = "$answered" ]; then
            echo "$release: $answered"
        else
            echo "$release: not 6.0's: wanted '$expected', got '$answered'"
            failed=1
        fi
    done
done
echo "logs=$build"
exit $failed
