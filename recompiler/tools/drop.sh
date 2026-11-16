#!/bin/sh
set -eu

if [ "$#" -lt 1 ]; then
    echo "usage: recompiler/tools/drop.sh NAME [--out DIR] [--no-verify]" >&2
    exit 2
fi

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"

if [ -z "${REVENANT_CACHE:-}" ]; then
    echo "drop.sh: set REVENANT_CACHE to this checkout's private cache" >&2
    exit 2
fi

started=$(date +%s)
step() {
    echo "drop.sh: $1 ($(( $(date +%s) - started )) s)"
}

step "build xlate and xlgen"
nice -n 15 ./xmakew build -P . -r xlate xlgen
step "translate, assemble and verify"
nice -n 15 ./xmakew l -P . recompiler/tools/drop.lua "$@"
step "ready"
