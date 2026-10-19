#!/bin/sh
# The five request properties, the port's answers beside the system's, in two binaries.
#
#     sh tests/backports/host/netext-requests/run.sh [--mutation]
#
# A is the system alone. B is the same probe with the port's object linked in: NSMutableURLRequest is
# the system's class and the port adds a category to it, so in B the port's methods answer those ten
# selectors - and run.sh proves it before it compares anything, because a B that still answers from the
# system would be comparing the system with itself and passing. That proof is the sentinel.
#
# --mutation plants one changed default in a scratch copy of the port's source and the comparison must
# report it; a build that fails is RUN FAILED and never counted as noticed. --no-plant runs the same
# comparison without the plant, which is how the mutation verdict is shown to fail on its own.
#
# The verdict is branched on the mode, and that is the point of it: a mutation run ends CONTROL FIRED,
# never PASS. The two say opposite things - clean says the port matches the system, mutation says the
# comparison can tell the port from the system - and one run printing both was reading as if the plant
# had been the thing that passed.
set -eu

mode=clean
plant=apply
for arg in "$@"; do
    case "$arg" in
        --mutation) mode=mutation ;;
        --no-plant) plant=skip ;;
        *) echo "usage: $0 [--mutation] [--no-plant]" >&2; exit 2 ;;
    esac
done
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
S="$root/packages/a/apple-backports"
W=${WORK:-$root/.agent-work/runs/netext-requests}
W=${W%./*}/$(basename "$W")
rm -rf "$W"; mkdir -p "$W"
sdk=$(xcrun --show-sdk-path --sdk macosx)
flags="-fobjc-arc -O0 -Wall -Wno-unguarded-availability-new -I$S/Foundation"
src="$S/Foundation/NSMutableURLRequest+RequestProperties.m"
object_name=NSMutableURLRequest+RequestProperties.o

build() { # build <output> <source> <extra flags...>
    out=$1; source=$2; shift 2
    # shellcheck disable=SC2086
    clang $flags "$@" "$here/probe.m" "$source" -framework Foundation -o "$out" 2> "$out.build"
}

echo "=== A: the system alone"
build "$W/A" /dev/null 2>/dev/null || true
# /dev/null carries no code, so A is the probe on its own
# shellcheck disable=SC2086
clang $flags "$here/probe.m" -framework Foundation -o "$W/A" 2> "$W/A.build"
"$W/A" > "$W/A.txt"
grep -E "^side|fresh\." "$W/A.txt" | head -6

echo "=== B: the same probe with the port's object linked in"
build "$W/B" "$src" -DPORT_SIDE=1
"$W/B" > "$W/B.txt"
grep -E "^side|fresh\." "$W/B.txt" | head -6

echo "=== the sentinel: B's ten selectors must be answered by the port's object, A's by the system"
port_image=$(basename "$(clang $flags -DPORT_SIDE=1 -### "$here/probe.m" "$src" 2>/dev/null | tr ' ' '\n' | grep -m1 'RequestProperties' | xargs dirname 2>/dev/null || echo '')" 2>/dev/null || true)
bad=0
for name in attribution requiresDNSSECValidation allowsPersistentDNS allowsUltraConstrainedNetworkAccess cookiePartitionIdentifier; do
    for half in get set; do
        b=$(grep "^image.$name.$half	" "$W/B.txt" | cut -f2)
        a=$(grep "^image.$name.$half	" "$W/A.txt" | cut -f2)
        case "$b" in
            "$root"/*) ;;
            *) echo "  FAIL $name.$half: B answered from '$b', which is not this worktree's object"; bad=$((bad + 1)) ;;
        esac
        case "$a" in
            "$root"/*) echo "  FAIL $name.$half: A answered from the port's own build ('$a')"; bad=$((bad + 1)) ;;
            /System/Library/*) ;;
            *) echo "  FAIL $name.$half: A answered from '$a', which is not the system's Foundation"; bad=$((bad + 1)) ;;
        esac
    done
done
[ "$bad" -eq 0 ] || { echo "FAIL: the sentinel did not hold, so the answers below would compare the system with itself" >&2; exit 1; }
echo "  all ten selectors: B from the port's object, A from the system"

echo "=== the comparison, name by name"
differ=0
for key in fresh roundtrip copy mutablecopy; do
    for name in attribution requiresDNSSECValidation allowsPersistentDNS allowsUltraConstrainedNetworkAccess cookiePartitionIdentifier; do
        a=$(grep "^$key.$name	" "$W/A.txt" | cut -f2)
        b=$(grep "^$key.$name	" "$W/B.txt" | cut -f2)
        if [ "$a" = "$b" ]; then
            printf '  ok   %-14s %-34s %s\n' "$key.$name" "$a" "$b"
        else
            printf '  DIFFER %-12s system=%-20s port=%s\n' "$key.$name" "$a" "$b"
            differ=$((differ + 1))
        fi
    done
done
echo "  differing: $differ"

plant_noticed=0
if [ "$mode" = mutation ]; then
    echo "=== the plant: a scratch copy whose default is the other value"
    scratch="$W/scratch"
    mkdir -p "$scratch"
    if [ "$plant" = apply ]; then
        if ! python3 - "$src" "$scratch/mutant.m" <<'PYEOF'
import sys
source, target = sys.argv[1], sys.argv[2]
text = open(source).read()
mark = "    NSNumber *value = [NSURLProtocol propertyForKey:key inRequest:request];\n    return value ? value.boolValue : NO;"
if text.count(mark) != 1:
    print("the default to break is not in the source once")
    raise SystemExit(1)
open(target, "w").write(text.replace(mark, "    NSNumber *value = [NSURLProtocol propertyForKey:key inRequest:request];\n    return value ? value.boolValue : YES;", 1))
PYEOF
        then
            echo "RUN FAILED: the plant did not apply" >&2
            exit 1
        fi
    else
        # The neutralised run: same comparison, plant never applied. It must fail, and it fails here.
        cp "$src" "$scratch/mutant.m"
        echo "  (--no-plant: the plant was not applied, so this run has to fail)"
    fi
    build "$W/M" "$scratch/mutant.m" -DPORT_SIDE=1
    "$W/M" > "$W/M.txt"
    m=$(grep "^fresh.requiresDNSSECValidation	" "$W/M.txt" | cut -f2)
    a=$(grep "^fresh.requiresDNSSECValidation	" "$W/A.txt" | cut -f2)
    if [ "$m" = "$a" ]; then
        echo "NOT NOTICED: the plant's default reads $m, the system's $a" >&2
        exit 1
    fi
    echo "  the plant differs: system fresh.requiresDNSSECValidation=$a, port-with-plant=$m"
        plant_noticed=1
fi

if [ "$differ" -ne 0 ]; then
    echo "FAIL: $differ answer(s) differ between the port and the system" >&2
    exit 1
fi

case "$mode" in
    mutation)
        [ "$plant_noticed" -eq 1 ] || { echo "FAIL: the mutation run ended without the plant being noticed" >&2; exit 1; }
        echo "CONTROL FIRED: the plant's changed default was noticed, so the comparison can tell the port from the system"
        ;;
    *)
        echo "PASS: the port answers as the system does, on a fresh request, on a copy and on a mutable copy"
        ;;
esac
