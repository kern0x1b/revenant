#!/bin/sh
# run-all.sh — is every host test still alive? A test that no longer links dies under `set -eu` before it
# checks anything, exits non-zero and looks, from the outside, exactly like a test nobody has run lately.
# This runs each run.sh for a few seconds and asks one question: did it get past building itself? A script
# that FAILS without reaching a single check is dead, whatever it says. One that is still running when the
# clock runs out is alive, because a link that fails fails in seconds, and one that ends with status 0 is
# alive because it got to its own end. It is a liveness sweep and no more: it says nothing about whether
# the checks pass, only whether they happen.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../common/runs.sh" "$here"
seconds=${CHARON_ALIVE_SECONDS:-90}
if [ "${1:-}" = --seconds ]; then
    seconds=$2
    shift 2
fi

# What this sweep cannot start, with the reason for each: a test passed over without one is the same blind
# spot the sweep exists to close, so nothing is skipped silently and no reason here is a guess.
needs_arguments="registry cachereader fuzz"
# The arguments the sweep gives a script that takes one: inventory is the generic differential, run here for the one
# spec the tree carries (tools/corpus/spec/FileProvider.json). Without it the script prints its usage and exits 1.
arguments_for="inventory=FileProvider"
records_only="naturallanguage-record smallapis2"
# Directories that hold a helper the differentials use rather than a test of their own: nothing here builds or
# checks anything, and passing them over silently is the blind spot this sweep exists to close, so each is named.
# common holds compare.py and mutate.py, which other harnesses import; it builds and checks nothing of
# its own, so it is a helper and not a test that failed to grow a run.sh.
helpers="nsdataasset scenekit-defaults common"

alive='^(ok|FAIL|note|skip|stage|record|records:|checks=|[0-9]+ (of|checks))'

# A sweep that leaves compilers running behind it makes the rest of itself slower, so the clock takes
# down the whole tree the script started, not only the script.
end_tree() {
    for child in $(pgrep -P "$1" 2>/dev/null); do
        end_tree "$child"
    done
    kill "$1" 2>/dev/null
}

wanted=$*
[ -n "$wanted" ] || wanted=$(cd "$here" && for each in */run.sh; do echo "${each%/run.sh}"; done)

dead=0
for name in $wanted; do
    case " $helpers " in *" $name "*)
        printf '%-24s %s\n' "$name" "skipped: it holds a helper for other tests, not a test of its own"
        continue
    esac
    script=$here/$name/run.sh
    if [ ! -f "$script" ]; then
        printf '%-24s %s\n' "$name" "no run.sh"
        dead=1
        continue
    fi
    case " $needs_arguments " in *" $name "*)
        printf '%-24s %s\n' "$name" "skipped: it takes arguments of its own"
        continue
    esac
    case " $records_only " in *" $name "*)
        printf '%-24s %s\n' "$name" "skipped: it records expectations rather than checking anything"
        continue
    esac
    case " $name " in " air2es ")
        printf '%-24s %s\n' "$name" "skipped: it needs the llvm package and glslangValidator"
        continue
    esac
    case " $name " in " session ")
        printf '%-24s %s\n' "$name" "skipped: it starts a server of its own"
        continue
    esac
    output=$(mktemp "$(runs_folder charon-run-all)/output.XXXXXX")
    set +e
    argument=
    for pair in $arguments_for; do
        case $pair in "$name"=*) argument=${pair#*=} ;; esac
    done
    ( cd "$here/.." && exec sh "$script" $argument ) > "$output" 2>&1 &
    runner=$!
    waited=0
    while kill -0 "$runner" 2>/dev/null && [ "$waited" -lt "$seconds" ]; do
        sleep 1
        waited=$((waited + 1))
        grep -qE "$alive" "$output" 2>/dev/null && break
    done
    if kill -0 "$runner" 2>/dev/null; then
        end_tree "$runner"
        wait "$runner" 2>/dev/null
        status=timeout
    else
        wait "$runner"
        status=$?
    fi
    set -e
    if [ "$status" = timeout ]; then
        # The seconds it actually waited, not the clock it was given: the loop above stops as soon as a
        # check has been reached, so a test that ran for two seconds and printed its verdict was not
        # "still running after 90s" and saying so made every such test look like a hang.
        printf '%-24s %s\n' "$name" "alive (stopped after ${waited}s, past its first check)"
    elif [ "$status" = 0 ]; then
        printf '%-24s %s\n' "$name" "alive, and it passed"
    elif grep -qE "$alive" "$output" 2>/dev/null; then
        printf '%-24s %s\n' "$name" "alive, and it reports failures (exit $status)"
    else
        dead=1
        printf '%-24s %s\n' "$name" "DEAD: it ended without reaching a single check (exit $status)"
        grep -iE 'error|Undefined symbols|ld:|No such file|command not found' "$output" | tail -3 | sed 's/^/    /'
    fi
    rm -f "$output"
done

[ "$dead" = 0 ] || { echo "a test above never reached a check: it is not guarding anything"; exit 1; }
echo "every test reached a check"
