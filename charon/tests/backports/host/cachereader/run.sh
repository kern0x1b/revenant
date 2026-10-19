#!/bin/sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tools=$here/../../tools
[ $# -eq 4 ] || { echo "usage: run.sh <dyld_shared_cache> <image> <class> <selector>" >&2; exit 2; }
cache=$1 image=$2 class=$3 selector=$4
listing=$(python3 "$tools/cache-methods.py" "$cache" "$image" "$class")
tab=$(printf '\t')
line=$(printf '%s\n' "$listing" | grep -F -e "-[$class $selector]$tab" | head -1)
[ -n "$line" ] || { echo "FAIL -[$class $selector] is not in the method list of $class ($(printf '%s\n' "$listing" | wc -l | tr -d ' ') methods)"; exit 1; }
address=${line##*$tab}
code=$(python3 "$tools/cache-disasm.py" "$cache" "$address" 8)
[ -n "$code" ] || { echo "FAIL nothing disassembles at $address"; exit 1; }
echo "ok -[$class $selector] is at $address and disassembles"
