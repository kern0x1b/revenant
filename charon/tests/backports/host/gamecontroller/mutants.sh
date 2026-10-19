#!/bin/sh
# Mutants for the snapshot differential and the touchpad: each one changes one rule of the port's
# copy, and each has to make tests/backports/host/gamecontroller fail. A mutant that does not build is RUN FAILED, never
# counted as noticed, so every mutant here is one the compiler still accepts - each is a change of a
# comparison or a value, not of the file's shape.
#
#   sh tests/backports/host/gamecontroller/mutants.sh
#
# The tree is left as it was found: each mutation is written over the file, run, and put back with
# `git show HEAD:<file> > <file>` - never `git checkout --`, which this repository's rules forbid -
# and the script ends by refusing to pass if the file is left changed.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tree=$(cd "$here/../../../.." && pwd)
rel=${MUTATE_FILE:-packages/a/apple-backports/GameController/CharonGCSnapshot.h}
source_file="$tree/$rel"
out=${BUILD:-$here/../../../../.agent-work/fin/mutants}
mkdir -p "$out"

restore() {
    git -C "$tree" show "HEAD:$rel" > "$source_file"
}

# Writes the mutation over the port's file, with python so that the text being replaced never has to
# survive a shell's quoting. Answers 0 when it changed something.
mutate() {
    python3 -c '
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if old not in text:
    sys.exit(3)
open(path, "w").write(text.replace(old, new, 1))
' "$source_file" "$1" "$2"
}

failures=0

# $1 the text to replace, $2 what replaces it, $3 what the mutant is called. The name is a
# single word on purpose: run.sh expands its object list unquoted, so a name with spaces would split
# the compiler's own arguments and look like a broken build rather than a mutant.
check() {
    old=$1
    new=$2
    name=$3
    if ! mutate "$old" "$new"; then
        printf 'MUTANT %-52s RUN FAILED (the text to mutate is not in the file: the mutation is wrong, not the code)\n' "$name"
        restore
        failures=$((failures + 1))
        return 0
    fi
    mkdir -p "$out/$name"
    if BUILD="$out/$name" sh "$here/run.sh" > "$out/$name.log" 2>&1; then
        printf 'MUTANT %-52s NOTICED=no (the differential passed with the mutant in place)\n' "$name"
        failures=$((failures + 1))
    else
        lines=$(grep -c DIFFERING "$out/$name.log" || true)
        lines=$((lines + $(grep -c DIFFERENT "$out/$name.log" || true)))
        if [ "$lines" -gt 0 ]; then
            printf 'MUTANT %-52s NOTICED=yes (%s differing lines, the run exited non-zero)\n' "$name" "$lines"
            grep -A2 DIFFERENT "$out/$name.log" | head -3 | sed 's/^/    /'
        else
            printf 'MUTANT %-52s RUN FAILED (non-zero exit and no differing line: the build broke, which is not notice)\n' "$name"
            tail -3 "$out/$name.log" | sed 's/^/    /'
            failures=$((failures + 1))
        fi
    fi
    restore
}

check 'return data.length >= length && header[0] != 0;' \
      'return data.length >= length - 1 && header[0] != 0;' \
      'gamepad-reader-takes-a-byte-less'

check 'return data.length >= length && header[0] != 0;' \
      'return data.length >= length;' \
      'gamepad-reader-ignores-the-version'

check 'return header[1] <= length;' \
      'return YES;' \
      'readers-ignore-the-declared-size'

check 'if (header[0] == 0)' \
      'if (header[0] == 0xFFFF)' \
      'encoders-leave-an-empty-version'

check 'if (header[1] == 0)' \
      'if (header[1] == 0xFFFF)' \
      'encoders-leave-an-empty-size'

# The touchpad's own rules, in the file that writes them. Each is one the host's touch state
# group compares against the host's own touchpad, so a mutation has to move a compared line.
touchpad_rel=packages/a/apple-backports/GameController/GCControllerTouchpad14.m
touchpad_file="$tree/$touchpad_rel"
restore_touchpad() {
    git -C "$tree" show "HEAD:$touchpad_rel" > "$touchpad_file"
}
mutate_touchpad() {
    python3 -c '
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if old not in text:
    sys.exit(3)
open(path, "w").write(text.replace(old, new, 1))
' "$touchpad_file" "$1" "$2"
}
check_touchpad() {
    old=$1
    new=$2
    name=$3
    if ! mutate_touchpad "$old" "$new"; then
        printf 'MUTANT %-52s RUN FAILED (the text to mutate is not in the file: the mutation is wrong, not the code)\n' "$name"
        restore_touchpad
        failures=$((failures + 1))
        return 0
    fi
    mkdir -p "$out/$name"
    if BUILD="$out/$name" sh "$here/run.sh" > "$out/$name.log" 2>&1; then
        printf 'MUTANT %-52s NOTICED=no (the differential passed with the mutant in place)\n' "$name"
        failures=$((failures + 1))
    else
        lines=$(grep -c DIFFERING "$out/$name.log" || true)
        lines=$((lines + $(grep -c DIFFERENT "$out/$name.log" || true)))
        if [ "$lines" -gt 0 ]; then
            printf 'MUTANT %-52s NOTICED=yes (%s differing lines, the run exited non-zero)\n' "$name" "$lines"
            grep -A2 DIFFERENT "$out/$name.log" | head -3 | sed 's/^/    /'
        else
            printf 'MUTANT %-52s RUN FAILED (non-zero exit and no differing line: the build broke, which is not notice)\n' "$name"
            tail -3 "$out/$name.log" | sed 's/^/    /'
            failures=$((failures + 1))
        fi
    fi
    restore_touchpad
}

# The touch state is the pair the header tells a caller to poll, so each of the four values it
# takes is a rule: Up before a touch, Down on the first one, Moving while a touch stays down,
# Up again when it lifts.
check_touchpad 'if (!touchDown)
        state = GCTouchStateUp;' \
           'if (!touchDown)
        state = GCTouchStateDown;' \
           'touchpad-stays-down-when-it-lifts'

check_touchpad 'else if (_touchState == GCTouchStateDown)
        state = GCTouchStateMoving;' \
           'else if (_touchState == GCTouchStateUp)
        state = GCTouchStateMoving;' \
           'touchpad-moves-only-from-a-fresh-down'

check_touchpad '    else
        state = GCTouchStateDown;' \
           '    else
        state = GCTouchStateMoving;' \
           'touchpad-never-reports-down'

check_touchpad '    GCTouchState state;
    if (!touchDown)' \
           '    GCTouchState state;
    if (touchDown)' \
           'touchpad-inverts-the-down-flag'

# The micro game's snapshot half, in the 10.0.1 object. Each mutant is the shape of a defect the
# objects group actually found, so both of them are silent in the source and loud in the bytes: one
# reads a field out of its neighbour's element, the other reads the direction pad as if it were an
# axis. A mutant that stops the build is RUN FAILED and never counted as noticed.
# The extended game's half is in GCSnapshots7.m, which holds no other rule this file mutates.
objects_rel=packages/a/apple-backports/GameController/GCSnapshots9.m
objects_file="$tree/$objects_rel"
restore_objects() {
    git -C "$tree" show "HEAD:$objects_rel" > "$objects_file"
}
mutate_objects() {
    python3 -c '
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if old not in text:
    sys.exit(3)
open(path, "w").write(text.replace(old, new, 1))
' "$objects_file" "$1" "$2"
}
check_objects() {
    old=$1
    new=$2
    name=$3
    if ! mutate_objects "$old" "$new"; then
        printf 'MUTANT %-52s RUN FAILED (the text to mutate is not in the file: the mutation is wrong, not the code)\n' "$name"
        restore_objects
        failures=$((failures + 1))
        return 0
    fi
    mkdir -p "$out/$name"
    if BUILD="$out/$name" sh "$here/run.sh" > "$out/$name.log" 2>&1; then
        printf 'MUTANT %-52s NOTICED=no (the differential passed with the mutant in place)\n' "$name"
        failures=$((failures + 1))
    else
        lines=$(grep -c MISMATCH "$out/$name.log" || true)
        lines=$((lines + $(grep -c DIFFERENT "$out/$name.log" || true)))
        if [ "$lines" -gt 0 ]; then
            printf 'MUTANT %-52s NOTICED=yes (%s differing lines, the run exited non-zero)\n' "$name" "$lines"
            grep -E 'MISMATCH|DIFFERENT' "$out/$name.log" | head -3 | sed 's/^/    /'
        else
            printf 'MUTANT %-52s RUN FAILED (non-zero exit and no differing line: the build broke, which is not notice)\n' "$name"
            tail -3 "$out/$name.log" | sed 's/^/    /'
            failures=$((failures + 1))
        fi
    fi
    restore_objects
}

check_objects '@"Button Y": @(fields->buttonY)' \
             '@"Button Y": @(fields->buttonX)' \
             'snapshot-field-read-from-the-wrong-element'

check_objects 'fields.dpadX = charon_gc_pad_axis(dpad, @selector(xAxis));' \
             'fields.dpadX = charon_gc_read_float(dpad, @selector(xAxis));' \
             'snapshot-direction-pad-read-as-an-axis'

# And the extended half, which is in the 7.0 object with GCGamepadSnapshot. The same field-mapping
# mistake, in the file the ladder places at 7.0 - held here because GCSnapshots7.m now carries a class
# the differential reads back element by element.
check_in_7 \
    '@"Button Y": @(fields->buttonY)' \
    '@"Button Y": @(fields->buttonX)' \
    'snapshot-extended-field-read-from-the-wrong-element'

# And the -[GCExtendedGamepad saveSnapshot] the split made writable. A field read out of its
# neighbour's element is the mistake that has actually been made twice in this library, so it is the
# one held here too: the read-back group compares the port's method against the host's own encoder for
# the same values, byte for byte, and a crossed field moves four bytes.
check_in_7 \
    'fields.buttonB = charon_gc_button_value([self charon_elementNamed:@"Button B"]);' \
    'fields.buttonB = charon_gc_button_value([self charon_elementNamed:@"Button A"]);' \
    'extended-save-snapshot-reads-the-wrong-button'

# The 7.0 object's extended half, held the same way as the 10.0.1 one.
snap7_rel=packages/a/apple-backports/GameController/GCSnapshots7.m
snap7_file="$tree/$snap7_rel"
restore_snap7() {
    git -C "$tree" show "HEAD:$snap7_rel" > "$snap7_file"
}
mutate_snap7() {
    python3 -c '
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if old not in text:
    sys.exit(3)
open(path, "w").write(text.replace(old, new, 1))
' "$snap7_file" "$1" "$2"
}
check_in_7() {
    old=$1
    new=$2
    name=$3
    if ! mutate_snap7 "$old" "$new"; then
        printf 'MUTANT %-52s RUN FAILED (the text to mutate is not in the file: the mutation is wrong, not the code)\n' "$name"
        restore_snap7
        failures=$((failures + 1))
        return 0
    fi
    mkdir -p "$out/$name"
    if BUILD="$out/$name" sh "$here/run.sh" > "$out/$name.log" 2>&1; then
        printf 'MUTANT %-52s NOTICED=no (the differential passed with the mutant in place)\n' "$name"
        failures=$((failures + 1))
    else
        lines=$(grep -c MISMATCH "$out/$name.log" || true)
        lines=$((lines + $(grep -c DIFFERENT "$out/$name.log" || true)))
        if [ "$lines" -gt 0 ]; then
            printf 'MUTANT %-52s NOTICED=yes (%s differing lines, the run exited non-zero)\n' "$name" "$lines"
            grep -E 'MISMATCH|DIFFERENT' "$out/$name.log" | head -3 | sed 's/^/    /'
        else
            printf 'MUTANT %-52s RUN FAILED (non-zero exit and no differing line: the build broke, which is not notice)\n' "$name"
            tail -3 "$out/$name.log" | sed 's/^/    /'
            failures=$((failures + 1))
        fi
    fi
    restore_snap7
}

# The 15.4 object, held the same way: one mutant that reads a mode out of a curve that carries none.
trigger154_rel=packages/a/apple-backports/GameController/GCDualSenseAdaptiveTrigger154.m
trigger154_file="$tree/$trigger154_rel"
restore_trigger154() {
    git -C "$tree" show "HEAD:$trigger154_rel" > "$trigger154_file"
}
mutate_trigger154() {
    python3 -c '
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if old not in text:
    sys.exit(3)
open(path, "w").write(text.replace(old, new, 1))
' "$trigger154_file" "$1" "$2"
}
check_trigger154() {
    old=$1
    new=$2
    name=$3
    if ! mutate_trigger154 "$old" "$new"; then
        printf 'MUTANT %-52s RUN FAILED (the text to mutate is not in the file: the mutation is wrong, not the code)\n' "$name"
        restore_trigger154
        failures=$((failures + 1))
        return 0
    fi
    mkdir -p "$out/$name"
    if BUILD="$out/$name" sh "$here/run.sh" > "$out/$name.log" 2>&1; then
        printf 'MUTANT %-52s NOTICED=no (the differential passed with the mutant in place)\n' "$name"
        failures=$((failures + 1))
    else
        lines=$(grep -c DIFFERENT "$out/$name.log" || true)
        if [ "$lines" -gt 0 ]; then
            printf 'MUTANT %-52s NOTICED=yes (%s differing lines, the run exited non-zero)\n' "$name" "$lines"
            grep -A2 DIFFERENT "$out/$name.log" | head -3 | sed 's/^/    /'
        else
            printf 'MUTANT %-52s RUN FAILED (non-zero exit and no differing line: the build broke, which is not notice)\n' "$name"
            tail -3 "$out/$name.log" | sed 's/^/    /'
            failures=$((failures + 1))
        fi
    fi
    restore_trigger154
}

# The mode a caller asked for is the one thing this object records, so a mutation that records nothing
# has to move the `adaptive trigger` line. It does not, on its own, because the public mode is the
# controller's answer and stays 0 either way - which is the rule being held, not a gap in the mutant.
# So the mutant moves the recording to the mode the host never answers with, which is the mistake a port
# makes when it treats the caller's request as the controller's state.
check_trigger154 '    [self charon_setRequestedMode:GCDualSenseAdaptiveTriggerModeSlopeFeedback];' \
                 '    [self charon_setMode:GCDualSenseAdaptiveTriggerModeSlopeFeedback];' \
                 'trigger-15-4-sets-the-public-mode'

# The header's own default is the other thing both copies are held to, and it contradicts the
# header's comment.
check_touchpad '_reportsAbsoluteTouchSurfaceValues = NO;' \
           '_reportsAbsoluteTouchSurfaceValues = YES;' \
           'touchpad-default-follows-the-header-comment'

if ! git -C "$tree" diff --quiet -- "$rel" "$touchpad_rel" "$objects_rel" "$trigger154_rel" "$snap7_rel"; then
    echo "MUTANTS: the source is left changed; a mutation was not put back"
    failures=$((failures + 1))
fi

echo "mutants: 15 run, $failures not noticed"
[ "$failures" -eq 0 ]
