#!/bin/sh
# accessibilitymap/mutants.sh - every mutant of AXBrailleMap has to be told apart by the case of
# run.sh, and by the failure report run.sh prints.
#
# A differential that examines nothing says it passed, and a mutant that stops the build says nothing
# either, so a mutant here has to be held by the comparison - a line of the two answers that do not
# match and the whole diff the run prints when they do not, both required - and the suite fails if no
# mutant dies that way.
#
# The rules each mutant breaks:
#   M1  a pin is not stored, so nothing reads back
#   M2  a height is clamped to the unit range, where the host clamps nothing
#   M3  a negative point is refused, where the host takes one
#   M4  the copy shares the original's store, where the host's copy is its own map
#   M5  the copy drops the pins, where the host's copy carries them
#   M6  the archive drops the pins, where the host's own round trip carries them
#   M7  the size is not carried through the copy
#   M8  the factory answers the size it was asked for
#   M9  a copy's store is mutable again, where the system's is frozen and a write to a copy raises
#  M10  a registry protocol row names a protocol that does not exist, so the name does not resolve
#  M11  the control for M10: the registry copied through the same path with nothing changed, which must
#       stay green - without it, a check that was red for any reason at all would pass M10
#  M12  a sized map's archive drops its pins, which nothing checked before 2026-09-29
#  M13  a sized map's archive drops its size
#  M14  an unarchived map's store is frozen, which is what the port's was and the host's is not
#
# Each mutation runs against a copy of the tree's own file with one line changed, so the unmutated
# counterpart of every one of them is the tree, which the run before them holds green; M11 is the
# explicit control for the path itself.
#
# Usage: sh tests/backports/host/accessibilitymap/mutants.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
package=$root/packages/a/apple-backports
sources=${ACCESSIBILITY_SRC:-$package/Accessibility}
work=${BUILD:-$(runs_folder charon-accessibilitymap-mutants)}
rm -rf "$work"
mkdir -p "$work"
survived=0
ran=0
killed=0
died_wrong=0
control_green=0

mutant() {
    # name, which occurrence of the line, the line, what it becomes
    name=$1
    nth=$2
    old=$3
    new=$4
    is_control=0
    if [ "$old" = "$new" ]; then is_control=1; fi
    if [ -z "$nth" ]; then
        echo "mutant $name does not say which occurrence of its line it changes" >&2
        return 1
    fi
    dir="$work/$name"
    # The copy keeps the package's own shape, because the source reaches its headers by a relative path.
    # A copy that did not would stop the build, and a mutant that dies of a build error has told nobody
    # anything - which is what the kill below insists on.
    mkdir -p "$dir/pkg/Accessibility"
    cp "$sources/CharonBrailleMap.m" "$dir/pkg/Accessibility/"
    cp "$sources/CharonBrailleMap.h" "$dir/pkg/Accessibility/"
    cp "$package/.gen/Accessibility/CharonAccessibilityProtocols.h" "$dir/pkg/Accessibility/"
    cp "$package/CharonSayOnce.h" "$dir/pkg/"
    MUTATE="$dir/pkg/Accessibility/CharonBrailleMap.m" MUTATE_OLD="$old" MUTATE_NEW="$new" \
        MUTATE_NTH="$nth" python3 "$here/../common/mutate.py"
    ran=$((ran + 1))
    if ACCESSIBILITY_SRC="$dir/pkg/Accessibility" BUILD="$dir/build" sh "$here/run.sh" > "$dir/out.txt" 2>&1; then
        echo "MUTANT SURVIVED: $name"
        survived=$((survived + 1))
        return 0
    fi
    if grep -q 'the two answers do not match what this case declares' "$dir/out.txt" &&
       grep -qE '^(@@|--- |\+\+\+ )' "$dir/out.txt"; then
        killed=$((killed + 1))
        echo "killed by the diff: $name: $(grep -m1 -E 'UNDECLARED DIFFERENCE|DECLARED DIFFERENCE' "$dir/out.txt")"
        return 0
    fi
    if grep -q 'says so once' "$dir/out.txt"; then
        killed=$((killed + 1))
        echo "killed by the once-only count: $name: $(grep -m1 'says so once' "$dir/out.txt")"
        return 0
    fi
    # A factory that answers the wrong size fails its own probe, and that probe is part of the run.
    if grep -q 'the factory probe did not pass' "$dir/out.txt"; then
        killed=$((killed + 1))
        # The branch is a condition and not `|| true`: the empty answer is the signal that the probe
        # failed for a reason this script does not name, and it is reported two lines below.
        if line=$(grep -m1 'FAILED' "$dir/out.txt"); then
            echo "killed by the factory probe: $name: $line"
        else
            echo "killed by the factory probe: $name: (the probe failed before it named a check)"
        fi
        return 0
    fi
    echo "MUTANT DIED FOR THE WRONG REASON: $name"
    tail -5 "$dir/out.txt"
    died_wrong=$((died_wrong + 1))
}

mutant M1-pin-not-stored 1 \
    '    [_pins setObject:@(height) forKey:CharonBrailleMapKey(point)];' \
    '    (void)point;'

mutant M2-height-clamped 1 \
    '    [_pins setObject:@(height) forKey:CharonBrailleMapKey(point)];' \
    '    [_pins setObject:@(height < 0.0f ? 0.0f : (height > 1.0f ? 1.0f : height)) forKey:CharonBrailleMapKey(point)];'

mutant M3-negative-point-refused 1 \
    '    if (!_pins) {' \
    '    if (point.x < 0 || point.y < 0) {
        return;
    }
    if (!_pins) {'

mutant M4-copy-shares-store 1 \
    '    copy->_pins = _pins ? (id<CharonBrailleMapPinStore>)[NSDictionary dictionaryWithDictionary:(NSDictionary *)_pins] : nil;' \
    '    copy->_pins = _pins;'

mutant M5-copy-drops-pins 1 \
    '    copy->_pins = _pins ? (id<CharonBrailleMapPinStore>)[NSDictionary dictionaryWithDictionary:(NSDictionary *)_pins] : nil;' \
    '    copy->_pins = nil;'

mutant M6-archive-drops-pins 1 \
    '    [coder encodeObject:_pins forKey:@"pins"];' \
    '    (void)coder;'

mutant M7-copy-drops-size 1 \
    '    copy->_size = _size;' \
    '    copy->_size = CGSizeZero;'

mutant M8-factory-wrong-size 1 \
    '    map->_size = dimensions;' \
    '    map->_size = CGSizeMake(1, 1);'

# The frozen copy, which the parity decision of 2026-09-29 added: a copy that took the write would
# answer the system differently on two cases, and this is the mutant that says so.
mutant M9-copy-not-frozen 1 \
    '    copy->_pins = _pins ? (id<CharonBrailleMapPinStore>)[NSDictionary dictionaryWithDictionary:(NSDictionary *)_pins] : nil;' \
    '    copy->_pins = _pins ? (id<CharonBrailleMapPinStore>)[(NSDictionary *)_pins mutableCopy] : nil;'

# The protocol name, changed in the registry and nowhere else. The generated source for a name that does
# not exist is a forward reference, which clang makes a label and the linker accepts, so nothing in the
# build complains: this is the only thing in the group that notices, which is why the check reads its
# names from the registry instead of carrying them.
registry_mutant() {
    # name, the row to change, what its name becomes
    name=$1
    row=$2
    replaced=$3
    dir="$work/$name"
    # The package's own shape, because the source reaches ../CharonSayOnce.h and the generated source
    # reaches CharonAccessibilityProtocols.h by relative and include paths respectively.
    mkdir -p "$dir/pkg/registry/Accessibility" "$dir/pkg/Accessibility"
    cp "$sources/CharonBrailleMap.m" "$sources/CharonBrailleMap.h" \
       "$package/.gen/Accessibility/CharonAccessibilityProtocols.h" "$dir/pkg/Accessibility/"
    cp "$package/CharonSayOnce.h" "$dir/pkg/"
    cp "$package/registry/Accessibility/ios26.json" "$dir/pkg/registry/Accessibility/"
    REGISTRY="$dir/pkg/registry/Accessibility/ios26.json" ROW="$row" REPLACED="$replaced" \
        python3 - <<'REGISTRY'
import json, os
path = os.environ["REGISTRY"]
rows = json.load(open(path))
changed = 0
for entry in rows["entries"]:
    if entry["api"] == os.environ["ROW"] and entry["kind"] == "protocol":
        entry["api"] = os.environ["REPLACED"]
        changed += 1
assert changed == 1, "the mutant's row is in the registry %d times" % changed
open(path, "w").write(json.dumps(rows, indent=2, ensure_ascii=False) + "\n")
REGISTRY
    ran=$((ran + 1))
    if ACCESSIBILITY_SRC="$dir/pkg/Accessibility" REGISTRY_ROOT="$dir/pkg" PROTOCOL_BUILD="$dir/build" \
       sh "$here/protocol-check.sh" > "$dir/out.txt" 2>&1; then
        if [ "$replaced" = "$row" ]; then
            control_green=$((control_green + 1))
            echo "control stayed green through the same path: $name"
        else
            echo "MUTANT SURVIVED: $name"
            survived=$((survived + 1))
        fi
    elif grep -q 'FAILED' "$dir/out.txt"; then
        killed=$((killed + 1))
        echo "killed by the protocol check: $name: $(grep -m1 'FAILED' "$dir/out.txt")"
    elif grep -q 'did not build' "$dir/out.txt"; then
        # A row naming a protocol that is declared nowhere is refused by the compiler before the check
        # runs, and that is where it is caught: the generated source names it and clang will not make a
        # forward reference to a protocol that does not exist. So a renamed row never reaches the lookup
        # loop - the two ways of being wrong cannot both be exercised by one row.
        killed=$((killed + 1))
        echo "killed by the compiler, before the check could look it up: $name: $(grep -m1 -o 'cannot find protocol declaration for .*' "$dir/out.txt" || grep -m1 'error:' "$dir/out.txt")"
    else
        echo "MUTANT DIED FOR THE WRONG REASON: $name"
        tail -5 "$dir/out.txt"
        died_wrong=$((died_wrong + 1))
    fi
}

registry_mutant M10-protocol-row-renamed AXBrailleMapRenderer AXBrailleMapCharonDoesNotExist
registry_mutant M11-protocol-row-control AXBrailleMapRenderer AXBrailleMapRenderer

# M12, M13, M14: the two holes the reviewer found in the check - no archive of a sized map, and a comment
# asserting a frozen unarchived store that the host's does not honour. Each is one assertion.
mutant M12-sized-archive-drops-pins 1 \
    '    [coder encodeObject:_pins forKey:@"pins"];' \
    '    (void)coder;'

mutant M13-sized-archive-drops-size 1 \
    '    [coder encodeDouble:_size.width forKey:@"sizeWidth"];' \
    '    (void)coder;'

# M14: a store that really is frozen where the archive's is not. The first version of this mutation
# removed a mutableCopy from the decoder's dictionary - which changes nothing, because what an unarchiver
# hands back is already mutable - so it survived, and the comment that said an unarchived store is frozen
# had been an intent rather than a measurement for the whole time.
mutant M14-unarchived-store-frozen 1 \
    '        _pins = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"pins"];' \
    '        _pins = [NSDictionary dictionaryWithDictionary:[coder decodeObjectOfClass:[NSDictionary class] forKey:@"pins"]];'
echo "mutants run: $ran, killed: $killed, controls stayed green: $control_green, died for another reason: $died_wrong, survived: $survived"
# Every mutant is either killed or is the control that must stay green, and the control is counted as a
# separate thing so that a check which was red for any reason at all cannot pass the control.
[ "$survived" -eq 0 ] && [ "$died_wrong" -eq 0 ] && [ $((killed + control_green)) -eq "$ran" ]
