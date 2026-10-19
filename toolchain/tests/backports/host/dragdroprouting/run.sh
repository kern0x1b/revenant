#!/bin/sh
# run.sh — the drop-routing order test on an emulated device: the test as a command-line program
# (an app started by xmake emulate never reaches its launch callback), built for armv7 against the
# port's own objects, run on 6.1.3 through the fast lane of heavy.sh. It prints the guest's own
# MATCH lines for the two views, and leaves the boot log beside it.
#
#     $HOME/Git/projects/ios/coordination/heavy.sh sh tests/backports/host/dragdroprouting/run.sh
#
# DDR_ROOT names the port's checkout; the sources are taken from it by path, so the port is never
# installed as the addon (charon/AGENTS.md, Traps).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=${DDR_ROOT:-$here/../../../..}
# The build tree is under the worktree: a harness may not default into /tmp, and the run
# output is kept with the other runs rather than in a directory the system wipes.
build=${DDR_BUILD:-$root/.agent-work/runs/dragdroprouting-build}
device=${DDR_DEVICE:-iPhone3,1}   # 6.1.3: the shade cache holds this profile; iPhone4,1 6.1.3 has no
                                  # firmware and the boot is blocked before the guest ever runs
releases=${DDR_RELEASES:-"6.1.3"}
export DDR_ROOT=$root
rm -rf "$build"
mkdir -p "$build"
cp "$here/xmake.lua" "$here/control" "$build/"
# DDR_UIKIT is NOT set here. xmake.lua already falls back to the port's own UIKit when it is unset
# (path.join(root, "packages/a/apple-backports/UIKit")), and this line used to point it at a scratch
# copy through a variable nothing defines, so under `set -u` the whole test died on
# "dragdroprouting/run.sh: line 24: scratch: unbound variable" before xmake was ever configured.
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1
failed=0
# Clean first, then the same tree with the collection view's dropSessionDidEnter: moved past its
# first dropSessionDidUpdate:, so the two verdicts come off one machine back to back rather than off
# two that may not have been starved the same way.
# The mutation, kept beside this script so the pair is reproducible: the collection view's half of the
# drop sequence with dropSessionDidEnter: moved past its first dropSessionDidUpdate:withDestination-
# IndexPath:. The same seven calls, two of them the other way round.
# The mutant is generated from the LIVE source into the build tree on every run, not read from a file
# beside this script: a checked-in fixture drifts from the source it was made from and then asserts
# nothing, and the text family had exactly that failure.
# The port's own sources are copied into a scratch tree and the build is pointed at that, so the
# mutant is a file in the scratch tree and no tracked source is ever written. There is therefore
# nothing to restore and no trap: a kill leaves the worktree exactly as it was.
port=$root/packages/a/apple-backports/UIKit
scratch=$build/port-sources
rm -rf "$scratch"
mkdir -p "$scratch"
cp "$port"/*.m "$port"/*.h "$scratch/" 2>/dev/null || true
rm -f "$scratch/CharonDropSequence11.m"
cp "$port/CharonDropSequence11.m" "$scratch/CharonDropSequence11.m"
original=$scratch/CharonDropSequence11.m
mutated=$build/CharonDropSequence11.m.mutated
python3 - "$original" "$mutated" <<'PYMUT'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
before = s
# The sequence now asks the interaction through objc_msgSend, so the mutation is the order of the
# two sends themselves: the update is asked before the enter, where the header has it after.
s = s.replace("""    ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidEnter:), interaction, session);
    NSIndexPath *destination = [self indexPathForItemAtPoint:[self convertPoint:point fromView:nil]];
    if (destination) {
        ((UIDropProposal * (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidUpdate:), interaction, session);""",
"""    NSIndexPath *destination = [self indexPathForItemAtPoint:[self convertPoint:point fromView:nil]];
    if (destination) {
        ((UIDropProposal * (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidUpdate:), interaction, session);
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, @selector(dropInteraction:sessionDidEnter:), interaction, session);""")
assert s != before, "the mutation did not apply"
open(dst, "w").write(s)
PYMUT

# The mutant has to differ from the source, or the mutated half is the clean half and asserts
# nothing. cmp says so, and the diff is printed so the two can be read rather than trusted. diff
# exits 1 for finding the difference it should find, so its status is discarded.
if cmp -s "$mutated" "$original"; then
    echo "FAIL: the mutant is byte-identical to the source, so the mutated half asserts nothing"
    exit 1
fi
echo "== the mutant against the live source:"
echo "   cmp: the mutant differs from the source, as it must"
diff -u "$original" "$mutated" | sed -n '3,12p' | sed 's/^/   /' || true

# The two halves: the tree as it is, then the mutated tree, then the tree back. Both run in the bulk
# lane, back to back, so the two verdicts come off one machine.
run_one() {
    release=$1
    # The image carries the binary, so the half being run has to be installed first: without this a
    # run would test whatever was installed before, and the mutation would report the tree's verdict.
    DDR_ROOT=$root xmake build -r -y > "build-$2-$release.log" 2>&1 || {
        echo "$2 $release: BUILD-FAIL"; tail -3 "build-$2-$release.log"; return 1; }
    DDR_ROOT=$root xmake emulate -d "$device" -r "$release" install > "install-$2-$release.log" 2>&1 || {
        echo "$2 $release: INSTALL-FAIL"; tail -3 "install-$2-$release.log"; return 1; }
    set +e
    DDR_ROOT=$root xmake emulate -d "$device" -r "$release" -k run /usr/libexec/dragdroprouting > "$release.log" 2>&1
    status=$?
    set -e
    if [ "$status" -eq 137 ]; then
        echo "$2 $release: killed (status 137) before the guest ran -- the machine was out of memory, not a verdict"
        return 1
    fi
    # The addon's own verdict for the run, which says pass, fail, crash or timeout where the run's
    # exit status only says the process stopped.
    image=$3
    verdict=$(ls -d "$HOME/.charon/emulator/images.noindex/$image/iPhone3,1_"*"/run/verdict.json" 2>/dev/null | head -1)
    if [ -n "$verdict" ]; then
        echo "$2 $release: $(python3 -c "
import json,sys
d=json.load(open('$verdict'))
print(d.get('state','?'), d.get('reason',''), d.get('signal','') and 'signal '+str(d['signal']) or '')
" 2>/dev/null)"
    fi
    if [ "$status" -eq 0 ] && grep -Eq 'pass.{0,12} on iPhone' "$release.log"; then
        echo "$2 $release: pass"
        return 0
    fi
    echo "$2 $release: not a pass (status $status)"
    grep -aE '^FAIL|fail|crash|timeout|blocked|RED' "$release.log" || true
    return 1
}

# The pair, in this order: the tree, then the mutated tree, then the tree back.
# The test's own verdict, read out of the image the run used: the program wrote two files in the
# guest, what it was asked and what it concluded, and the runner's log carries neither.
guest_lines() {
    image=$2
    guest=$3
    rootfs=$(ls -d "$HOME/.charon/emulator/images.noindex/$image/iPhone3,1_"*"/run/rootfs" 2>/dev/null | head -1)
    [ -n "$rootfs" ] || { echo "$guest: no image rootfs at $HOME/.charon/emulator/images.noindex/$image"; return 0; }
    done_file="$rootfs/private/var/backports/dragdroprouting.done"
    asked_file="$rootfs/private/var/backports/dragdroprouting.asked"
    if [ -f "$done_file" ]; then
        printf '%s .done: ' "$guest"; tr -d '\n' < "$done_file"; echo
    else
        echo "$guest: no .done file -- the program did not reach the check"
    fi
    if [ -f "$asked_file" ]; then
        echo "$guest asked:"; sed 's/^/    /' "$asked_file"
    fi
}

# Clean, then the mutated tree, then the tree back, all on this machine in this order.
for release in $releases; do
    image=$(ls -td "$HOME/.charon/emulator/images.noindex/"dragdroprouting-* 2>/dev/null | head -1)
    :
    run_one "$release" clean "$(basename "$image")" && guest_lines "$release" "$(basename "$image")" clean || failed=1
done
# the mutant, in the scratch tree only
cp "$mutated" "$scratch/CharonDropSequence11.m"
for release in $releases; do
    run_one "$release" mutated "$(basename "$image")" && guest_lines "$release" "$(basename "$image")" mutated || true
done
exit $failed
