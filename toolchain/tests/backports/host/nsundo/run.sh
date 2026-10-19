#!/bin/sh
# The five NSUndoManager additions, the port's answers beside the system's, in two binaries.
#
#     sh tests/backports/host/nsundo/run.sh [--mutation] [--no-plant]
#
# A is the system alone. B is the same probe with the port's object linked in.
#
# B is built from a scratch copy in which the port's own capability guard is stood down. The guard
# asks the running release whether it has these five and returns early when it does - right on a
# device that has them, so the port never double-counts there. This host has all five, so with the
# guard left alone B would link the port's five against shadow stacks nothing ever fills, which is not
# the code that runs on 6.1.3 and would measure nothing. Only the scratch copy is edited; the
# committed source is built unchanged and its guard is checked to still be there afterwards.
#
# The comparison is only worth anything if B's answers come from the port and A's from the release, so
# run.sh proves that first - the sentinel - before it compares anything.
#
# --mutation breaks one of the three rules the shadow uses to place a registration, and the
# comparison has to report it. --no-plant runs the same comparison without the break, which is how the
# mutation verdict is shown failing on its own.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
S="$root/packages/a/apple-backports"
W=${WORK:-$root/.agent-work/runs/nsundo}
rm -rf "$W"; mkdir -p "$W"
src="$S/Foundation/NSUndoManager+ActionUserInfo.m"
scratch="$W/scratch"; mkdir -p "$scratch"
mode=clean
plant=apply
for arg in "$@"; do
    case "$arg" in
        --mutation) mode=mutation ;;
        --no-plant) plant=skip ;;
        *) echo "usage: $0 [--mutation] [--no-plant]" >&2; exit 2 ;;
    esac
done

# shellcheck disable=SC2086
flags="-fobjc-arc -O0 -Wall -Wno-unguarded-availability-new -I$S/Foundation"

guard='    if ([NSUndoManager instancesRespondToSelector:@selector(setActionUserInfoValue:forKey:)])
        return;'
if ! python3 - "$src" "$scratch/port.m" "$guard" <<'PYEOF'
import sys
source, target, guard = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(source).read()
if text.count(guard) != 1:
    print("the capability guard is not in the source once")
    raise SystemExit(1)
open(target, "w").write(text.replace(guard, "    /* the guard is stood down for this build only: see the head of run.sh */", 1))
PYEOF
then
    echo "RUN FAILED: the capability guard was not found" >&2
    exit 1
fi

echo "=== A: the system alone"
# shellcheck disable=SC2086
clang $flags "$here/probe.m" -framework Foundation -o "$W/A" 2> "$W/A.build"
"$W/A" > "$W/A.txt"
grep -vE "^image\." "$W/A.txt" | head -6

echo "=== B: the same probe with the port's object linked in"
# shellcheck disable=SC2086
clang $flags "$here/probe.m" "$scratch/port.m" -framework Foundation -o "$W/B" 2> "$W/B.build"
"$W/B" > "$W/B.txt"
grep -vE "^image\." "$W/B.txt" | head -6

echo "=== the sentinel: the port's answers must come from this worktree, A's from the release"
bad=0
for name in undoCount redoCount setActionUserInfoValue:forKey: undoActionUserInfoValueForKey: redoActionUserInfoValueForKey:; do
    b=$(grep "^image.$name	" "$W/B.txt" | cut -f2)
    a=$(grep "^image.$name	" "$W/A.txt" | cut -f2)
    case "$b" in
        "$root"/*) ;;
        *) echo "  FAIL $name: B answered from '$b', which is not this worktree's object"; bad=$((bad + 1)) ;;
    esac
    case "$a" in
        "$root"/*) echo "  FAIL $name: A answered from the port's own build ('$a')"; bad=$((bad + 1)) ;;
        /System/Library/*) ;;
        *) echo "  FAIL $name: A answered from '$a', which is not the release's Foundation"; bad=$((bad + 1)) ;;
    esac
done
[ "$bad" -eq 0 ] || { echo "FAIL: the sentinel did not hold, so the answers below would compare the release with itself" >&2; exit 1; }
echo "  all five: B from the port's object, A from the release"

echo "=== the comparison, name by name"
differ=0
keys=$(grep -vE "^side|^image\." "$W/A.txt" | cut -f1)
for key in $keys; do
    a=$(grep "^$key	" "$W/A.txt" | cut -f2)
    b=$(grep "^$key	" "$W/B.txt" | cut -f2)
    if [ "$a" = "$b" ]; then
        printf '  ok      %-30s %s\n' "$key" "$a"
    else
        printf '  DIFFER  %-30s release=%-22s port=%s\n' "$key" "$a" "$b"
        differ=$((differ + 1))
    fi
done
echo "  differing: $differ"

plant_noticed=0
if [ "$mode" = mutation ]; then
    echo "=== the plant: one of the three rules that place a registration"
    if [ "$plant" = apply ]; then
        # Rule three is "a registration outside an undo or a redo empties the redo stack". Broken:
        # the redo stack is left alone, so a fresh registration after an undo still reports a redo.
        if ! python3 - "$scratch/port.m" <<'PYEOF'
import sys
target = sys.argv[1]
text = open(target).read()
mark = "        [redo removeAllObjects];\n"
if text.count(mark) != 1:
    print("the rule to break is not in the source once")
    raise SystemExit(1)
open(target, "w").write(text.replace(mark, "", 1))
PYEOF
        then
            echo "RUN FAILED: the plant did not apply" >&2
            exit 1
        fi
    else
        cp "$src" "$scratch/port.m"
        guard='    if ([NSUndoManager instancesRespondToSelector:@selector(setActionUserInfoValue:forKey:)])
        return;'
        if ! python3 - "$src" "$scratch/port.m" "$guard" <<'PYEOF'
import sys
source, target, guard = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(source).read()
if text.count(guard) != 1:
    print("the capability guard is not in the source once")
    raise SystemExit(1)
open(target, "w").write(text.replace(guard, "    /* the guard is stood down for this build only: see the head of run.sh */", 1))
PYEOF
        then
            echo "RUN FAILED: the capability guard was not found" >&2
            exit 1
        fi
        echo "  (--no-plant: the rule was not broken, so this run has to fail)"
    fi
    # shellcheck disable=SC2086
    clang $flags "$here/probe.m" "$scratch/port.m" -framework Foundation -o "$W/M" 2> "$W/M.build"
    "$W/M" > "$W/M.txt"
    mkeys=$(grep -vE "^side|^image\." "$W/A.txt" | cut -f1)
    m_differ=0
    for key in $mkeys; do
        a=$(grep "^$key	" "$W/A.txt" | cut -f2)
        m=$(grep "^$key	" "$W/M.txt" | cut -f2)
        if [ "$a" != "$m" ]; then
            printf '  the plant differs: %-30s release=%-22s port-with-plant=%s\n' "$key" "$a" "$m"
            m_differ=$((m_differ + 1))
        fi
    done
    if [ "$m_differ" -eq 0 ]; then
        echo "NOT NOTICED: breaking the rule changed nothing the comparison can see" >&2
        exit 1
    fi
    plant_noticed=1
fi

if [ "$differ" -ne 0 ]; then
    echo "FAIL: $differ answer(s) differ between the port and the release" >&2
    exit 1
fi

case "$mode" in
    mutation)
        [ "$plant_noticed" -eq 1 ] || { echo "FAIL: the mutation run ended without the plant being noticed" >&2; exit 1; }
        echo "CONTROL FIRED: the broken rule was noticed, so the comparison can tell the port from the release"
        ;;
    *)
        echo "PASS: the port answers as the release does, on a fresh manager, through two undos and a redo"
        ;;
esac
