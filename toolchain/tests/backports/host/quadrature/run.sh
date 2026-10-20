#!/bin/sh
# The port's Quadrature10.m held against the host's own Accelerate, case by case.
set -eu
echo "FAIL host/quadrature/run.sh: its Python steps are gone and not yet ported to Lua: tables.py" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/frameworks/apple-backports/Accelerate}
build=${QUADRATURE_BUILD:-$(runs_folder quadrature-host)}
rm -rf "$build"
mkdir -p "$build"

# The node tables against the DATA statements of netlib's QUADPACK, before anything is built: a table that
# is not the one QUADPACK gives shows up here as one line, not as a hundred confusing integrals.
python3 "$here/tables.py" --check

# The port's own API name is renamed in its own translation unit, so this one can hold the port's answers
# and the host's side by side.
xcrun clang -fobjc-arc -w -Dquadrature_integrate=revenant_host_quadrature_integrate \
    -I"$ACCELERATE" -c "$ACCELERATE/Quadrature10.m" -o "$build/Quadrature10.o"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations "$here/differential.m" "$build/Quadrature10.o" \
    -framework Foundation -framework Accelerate -o "$build/differential"
"$build/differential" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
