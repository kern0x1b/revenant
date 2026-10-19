#!/bin/sh
# run.sh -- the text drag and drop order on an emulated 6.1.3: the tree, then the same tree with the
# drop's gate moved after the proposal, then the tree back. Both halves through heavy.sh's bulk lane.
# The verdict is the addon's verdict.json and the two files the program wrote in the image; the
# runner's log carries neither of those.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=${DDR_ROOT:-$here/../../../..}
build=${DDR_BUILD:-$root/.agent-work/runs/textdragdrop-build}
device=${DDR_DEVICE:-iPhone3,1}
releases=${DDR_RELEASES:-"6.1.3"}
export DDR_ROOT=$root

# The port's own sources are copied into a scratch tree and the build is pointed at that, so a mutant
# never overwrites a tracked source. The mutant is generated from the LIVE source on every run, not
# read from a file beside this script: a checked-in fixture drifts from the source it was made from and
# then asserts nothing, which is exactly what happened here.
port=$root/packages/a/apple-backports/UIKit
rm -rf "$build"
mkdir -p "$build"
cp "$here/xmake.lua" "$here/control" "$build/"
scratch=$build/port-sources
rm -rf "$scratch"
mkdir -p "$scratch"
cp "$port"/*.m "$port"/*.h "$scratch/" 2>/dev/null || true
rm -f "$scratch/UITextView+TextDragDrop11.m"
cp "$port/UITextView+TextDragDrop11.m" "$scratch/UITextView+TextDragDrop11.m"
original=$scratch/UITextView+TextDragDrop11.m
mutated=$build/UITextView+TextDragDrop11.m.mutant

# The mutation, made from the source in front of us: the all-items preview is asked before the drop,
# where UITextDropping.h puts the drop first. Two calls, the other way round.
python3 - "$original" "$mutated" <<'PYMUT'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
before = s
perform = """    if ([delegate respondsToSelector:perform])
        ((void (*)(id, SEL, id, id))objc_msgSend)(delegate, perform, self.control, request);
"""
preview = """    if ([delegate respondsToSelector:preview])
        ((UITargetedDragPreview * (*)(id, SEL, id, id))objc_msgSend)(delegate, preview, self.control, (id)[UITargetedDragPreview class]);
"""
assert s.count(perform) == 1 and s.count(preview) == 1, "the two calls to swap were not found"
# the source has the drop first, as UITextDropping.h has it, so the mutant is the preview first
s = s.replace(perform + preview, preview + perform)
assert s != before
open(dst, "w").write(s)
PYMUT

# The mutant has to differ from the source, or the mutated half is the clean half and asserts
# nothing. `cmp` says so, and the diff is printed, so the two can be read rather than trusted.
echo "== the mutant against the live source:"
if cmp -s "$mutated" "$original"; then
    echo "FAIL: the mutant is byte-identical to the source, so the mutated half asserts nothing"
    exit 1
fi
echo "   cmp: the mutant differs from the source, as it must"
# diff exits 1 when the files differ, which is what must have happened here, so its status is
# discarded rather than left to stop the script at the point where it proved the point.
diff -u "$original" "$mutated" | sed -n '3,12p' | sed 's/^/   /' || true

export DDR_UIKIT=$scratch
cd "$build"
xmake f -p iphoneos -a armv7 -y > configure.log 2>&1
xmake build -y > build.log 2>&1

run_one() {
    release=$1
    half=$2
    image=$3
    DDR_ROOT=$root DDR_UIKIT=$scratch xmake build -r -y > "build-$half-$release.log" 2>&1 || {
        echo "$half $release: BUILD-FAIL"; tail -3 "build-$half-$release.log"; return 1; }
    DDR_ROOT=$root xmake emulate -d "$device" -r "$release" install > "install-$half-$release.log" 2>&1 || {
        echo "$half $release: INSTALL-FAIL"; tail -3 "install-$half-$release.log"; return 1; }
    set +e
    DDR_ROOT=$root xmake emulate -d "$device" -r "$release" -k run /usr/libexec/textdragdrop > "$release-$half.log" 2>&1
    status=$?
    set -e
    if [ "$status" -eq 137 ]; then
        echo "$half $release: killed (status 137) before the guest ran -- the machine was out of memory, not a verdict"
        return 1
    fi
    verdict=$(ls -d "$HOME/.charon/emulator/images.noindex/$image/iPhone3,1_"*"/run/verdict.json" 2>/dev/null | head -1)
    [ -n "$verdict" ] && echo "$half $release: $(python3 -c "
import json
d=json.load(open('$verdict'))
print(d.get('state','?'), d.get('reason',''))")"
    if [ "$status" -eq 0 ] && grep -Eq 'pass.{0,12} on iPhone' "$release-$half.log"; then
        echo "$half $release: pass"
        return 0
    fi
    echo "$half $release: not a pass (status $status)"
    grep -aE '^FAIL|fail|crash|timeout|blocked' "$release-$half.log" | head -2 || true
    return 1
}

guest_lines() {
    release=$1
    half=$2
    image=$3
    rootfs=$(ls -d "$HOME/.charon/emulator/images.noindex/$image/iPhone3,1_"*"/run/rootfs" 2>/dev/null | head -1)
    [ -n "$rootfs" ] || { echo "$half: no image rootfs"; return 0; }
    done_file="$rootfs/private/var/backports/textdragdrop.done"
    asked_file="$rootfs/private/var/backports/textdragdrop.asked"
    if [ -f "$done_file" ]; then
        printf '%s .done: ' "$half"; tr -d '\n' < "$done_file"; echo
    else
        echo "$half: no .done file -- the program did not reach the check"
    fi
    [ -f "$asked_file" ] && { echo "$half asked:"; sed 's/^/    /' "$asked_file"; }
    return 0
}

failed=0
image=$(ls -td "$HOME/.charon/emulator/images.noindex/"textdragdrop-* 2>/dev/null | head -1 | xargs basename 2>/dev/null)
for release in $releases; do
    [ -n "$image" ] || image=$(ls -td "$HOME/.charon/emulator/images.noindex/"textdragdrop-* 2>/dev/null | head -1 | xargs basename)
    run_one "$release" clean "$image" && guest_lines "$release" clean "$image" || failed=1
done
# the mutant, in the scratch tree only; the live source is never touched
cp "$mutated" "$scratch/UITextView+TextDragDrop11.m"
for release in $releases; do
    run_one "$release" mutated "$image" && guest_lines "$release" mutated "$image" || true
done
exit $failed
