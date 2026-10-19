#!/bin/sh
# mutate-selftest.sh - can mutate() refuse? A guard that has never refused is a guard that cannot, and
# this one is the difference between a broken build and a red mutant, so it is shown refusing here.
#
# Three cases in a scratch directory: an anchor that occurs once and must change exactly one line, and
# an anchor that occurs twice and an anchor that occurs not at all, both of which must abort with the
# file byte-identical afterwards. The third case's abort is what proves the second is not a coincidence.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
scratch=${1:-$here/../../../.agent-work/runs/mutate-selftest}
rm -rf "$scratch"; mkdir -p "$scratch/mutants"; work=$scratch
MUTANTS_DIR=$scratch/mutants
cp "$here/mutants/metacharacter.anchor" "$here/mutants/metacharacter.repl" "$scratch/mutants/"
fail=0
export MUTANTS_DIR
. "$here/mutate.sh"

# one occurrence: exactly one line changes
printf 'alpha\nbeta\ngamma\n' > "$scratch/one.txt"
printf 'one.txt before: %s\n' "$(md5 -q "$scratch/one.txt")"
printf 'alpha\nbeta\nB1\nB2\n' > "$scratch/one.txt"
printf 'beta\n' > "$scratch/mutants/selftest-one.anchor"; printf 'BETA\n' > "$scratch/mutants/selftest-one.repl"
mutate "$scratch/one.txt" selftest-one
changed=$(diff "$work/one.txt.original" "$scratch/one.txt" | grep -c '^>')
printf 'case 1 anchor once     : diff lines %s, want 1 -> %s\n' "$changed" "$([ "$changed" -eq 1 ] && echo ok || { fail=1; echo FAILED; })"

# two occurrences: refuses, and leaves the file exactly as it was
printf 'alpha\nbeta\ngamma\nbeta\n' > "$scratch/two.txt"
before=$(md5 -q "$scratch/two.txt")
if mutate "$scratch/two.txt" selftest-one 2>"$scratch/two.err"; then
    printf 'case 2 anchor twice    : it did NOT abort -> FAILED\n'; fail=1
else
    after=$(md5 -q "$scratch/two.txt")
    if [ "$before" = "$after" ]; then
        printf 'case 2 anchor twice    : aborted, file byte-identical (%s) -> ok\n' "$after"
    else
        printf 'case 2 anchor twice    : aborted but the file changed -> FAILED\n'; fail=1
    fi
    printf '                         message: %s\n' "$(head -1 "$scratch/two.err")"
fi

# no occurrence: refuses too, so the refusal is the count and not the accident of one input
printf 'alpha\ngamma\n' > "$scratch/zero.txt"
before=$(md5 -q "$scratch/zero.txt")
if mutate "$scratch/zero.txt" selftest-one 2>"$scratch/zero.err"; then
    printf 'case 3 anchor absent   : it did NOT abort -> FAILED\n'; fail=1
elif [ "$before" = "$(md5 -q "$scratch/zero.txt")" ]; then
    printf 'case 3 anchor absent   : aborted, file byte-identical -> ok\n'
    printf '                         message: %s\n' "$(head -1 "$scratch/zero.err")"
else
    printf 'case 3 anchor absent   : aborted but the file changed -> FAILED\n'; fail=1
fi


# an anchor carrying the three characters that are metacharacters as a shell word: the transport is
# the environment, so they arrive as themselves
cat "$MUTANTS_DIR/metacharacter.anchor" > "$scratch/meta.txt"
before=$(md5 -q "$scratch/meta.txt")
mutate "$scratch/meta.txt" metacharacter 3 3
case4=$(md5 -q "$scratch/meta.txt")
if [ "$before" != "$case4" ] && grep -qF 'alpha (y) "q" $x' "$scratch/meta.txt"; then
    printf 'case 4 anchor with EOF, ) " $x: the metacharacters survived, 3 lines for 3 -> ok\n'
else
    printf 'case 4 anchor with ) " $x: FAILED\n'; fail=1
fi

# a mutation of two lines when one is expected: it refuses, and the file is byte-identical, because
# it refuses by writing first and putting back second
printf 'alpha\nbeta\ngamma\n' > "$scratch/two-lines.txt"
before=$(md5 -q "$scratch/two-lines.txt")
printf 'beta\n' > "$scratch/mutants/selftest-two.anchor"; printf 'B1\nB2\n' > "$scratch/mutants/selftest-two.repl"
if mutate "$scratch/two-lines.txt" selftest-two 2>"$scratch/two-lines.err"; then
    printf 'case 5 two lines, one wanted: it did NOT abort -> FAILED\n'; fail=1
elif [ "$before" = "$(md5 -q "$scratch/two-lines.txt")" ]; then
    printf 'case 5 two lines, one wanted: aborted, file byte-identical (%s) -> ok\n' "$before"
    printf '                         message: %s\n' "$(head -1 "$scratch/two-lines.err")"
else
    printf 'case 5 two lines, one wanted: aborted but the file changed -> FAILED\n'; fail=1
fi

# and the same two lines accepted when the caller says 2 1, which is what the gradient site is
if mutate "$scratch/two-lines.txt" selftest-two 2 1 >"$scratch/ok.out" 2>&1; then
    printf 'case 6 the same two lines declared: %s\n' "$(cat "$scratch/ok.out")"
else
    printf 'case 6 the same two lines declared: FAILED\n'; fail=1
fi

[ "$fail" -eq 0 ] || { echo "mutate() cannot be trusted to refuse"; exit 1; }
echo "mutate() reads each mutant from two files, so no shell parses it, changes what it is told to, and refuses a doubled, an absent, and a wrong-sized anchor leaving the file alone"
