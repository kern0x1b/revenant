#!/bin/sh
# The port's complex sparse family, as a dylib, held against the host's own Accelerate from a table of
# cases. Cases are data; the loop and the switch are the only code that reads them.
set -eu
# The root and every path under it come from where this script is, the way every other run.sh in
# tests/backports/host/ does, so the 41 answers belong to the checkout the script is in and not to
# whichever worktree last ran it.
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
# the repository: sparsecomplex -> host -> backports -> tests -> the root, four levels up
root=$(cd "$here/../../../../" && pwd)
ACCELERATE=${ACCELERATE:-$root/packages/a/apple-backports/Accelerate}
COMPLEX=${COMPLEX:-$here}
build=${SPARSECOMPLEX_BUILD:-$(runs_folder charon-sparsecomplex-host)}
rm -rf "$build"
mkdir -p "$build"

# The port's two halves in one dylib: the complex family, which lives beside this script because it is
# not yet carried in the library - it has no registry rows, and the gate requires an entry for anything
# a band builds - and the real half, which IS carried, in the Accelerate folder. The dylib is dlopen'd
# RTLD_LOCAL | RTLD_FIRST and reached by dlsym, so nothing of the port's can interpose the host's and the
# host's Accelerate is the one the process already has.
xcrun clang -fobjc-arc -w -dynamiclib -I"$COMPLEX" -I"$ACCELERATE" -framework Accelerate -framework Foundation \
    -install_name @rpath/libComplexPort.dylib \
    -o "$build/libComplexPort.dylib" "$COMPLEX/SparseComplex18.m" "$ACCELERATE/SparseBLAS9.m"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable \
    -o "$build/differential-complex" "$here/differential.m" \
    -framework Foundation -framework Accelerate
"$build/differential-complex" "$build/libComplexPort.dylib" > "$build/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$build/log" || true
echo "log=$build/log"
exit $result
