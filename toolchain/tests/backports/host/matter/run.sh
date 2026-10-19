#!/bin/sh
# The host's own Matter surface, member by member, from a live process that loaded the framework.
#
# Writes one TSV of the host's methods, properties, protocols, protocol methods and the surface's functions, in the
# registry's own spellings, for tools/matter-host-diff.lua to compare the port's library against. The host has no port
# here to run: this is the host's own framework, loaded into the host's own process, which is the half of a
# differential the port cannot supply - and it is a real reading of the host's surface, not a reading of its headers.
#
#   sh tests/backports/host/matter/run.sh [out.tsv] [surface.tsv]
#
# The build has to succeed and the program has to have run: a link that fails fails in seconds, so a script that ends
# with status 0 and a TSV carrying the framework's own thousands of members is the only thing this can mean.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${MATTER_HOST_BUILD:-$(runs_folder charon-matter-host)}
out=${1:-$build/host-members.tsv}
# The surface the function rows are asked about, named by the corpus it was read from. Eight levels up from here is the
# workspace that holds both this checkout and the corpus: matter, host, backports, tests, the checkout, worktrees,
# .agent-work, charon, ios.
surface=${2:-$here/../../../../../../../../coordination/corpus/sdk-26.2-surface.tsv}
rm -rf "$build"
mkdir -p "$build"
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -o "$build/members" "$here/members.m" -framework Foundation
"$build/members" "$surface" > "$build/log" 2>&1

count() { grep -c "$1" "$build/log" || true; }
methods=$(count "^method")
properties=$(count "^property")
adoptions=$(count "^protocol")
functions=$(count "^function	.*	yes$")

# A run that loaded nothing would have written Foundation's own classes instead: the host's Matter surface is tens of
# thousands of members, so an answer below that is a failure and not a finding.
if [ "$methods" -lt 1000 ] || [ "$functions" -lt 8 ]; then
    echo "FAIL the host's Matter.framework answered with $methods methods and $functions of the surface's functions" >&2
    head -3 "$build/log" >&2
    exit 1
fi

# The host half of pure.m: the parts of commissioning and the controller that need no device, run against the host's own
# framework. It prints one "name<TAB>answer" per line. The product has no port half (pure.m's header says why).
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -o "$build/pure" "$here/pure.m" -framework Matter -framework Foundation
"$build/pure" > "$build/pure.log" 2>&1
answers=$(grep -c "	" "$build/pure.log" || true)
if [ "$answers" -lt 20 ]; then
    echo "FAIL the host's framework answered $answers questions of pure.m" >&2
    head -3 "$build/pure.log" >&2
    exit 1
fi
cp "$build/pure.log" "${out%.tsv}-pure.txt"

cp "$build/log" "$out"
echo "ok the host's Matter.framework carries $methods methods, $properties properties, $adoptions protocol adoptions"
echo "ok and $functions of the $(
    count "^function	") function rows of the SDK 26.2 surface"
echo "ok and it answered $answers of pure.m's questions (host half only, pure.txt)"
echo "wrote $out"
