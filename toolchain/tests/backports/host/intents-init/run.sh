#!/bin/sh
# run.sh - the host's own answer for -[<class> init] on all 110 classes the registry carries a row
# for, measured fresh every time and compared against a golden file.
#
# This is the harness the 110 registry rows name as owed. Each of those rows says the header marks
# the class's -init unavailable, the system still answers one, and `[[Cls alloc] init]` returns an
# object with every property nil. Eight classes had been measured by hand; the other hundred and
# two were "the same rule applied to the same header, which is a claim and not a measurement until
# that harness runs". This runs that harness.
#
# THREE RUNS, in this order, and each one is worthless if the one before it did not pass:
#
#   1. provenance - the controls. It looks up NSObject, NSString, INCar and INListCarsIntent and
#      fails if any is missing, and prints the forwarding trampoline beside three real IMPs. Every
#      zero init.m reports is only the host's answer once this has shown the same reader finding
#      the classes that are there. INCar is in the control because its header says
#      API_UNAVAILABLE(macos, tvos) and a reader that trusted that macro would skip it.
#   2. the differential - all 110 against expected.txt, one line per class.
#   3. the plant - the same binary with PLANT=one-wrong, which must FAIL. A comparison that cannot
#      fail is not guarding anything, so the plant is run and the script stops if it passes.
#
# Build from scratch every time, so nothing stale is ever measured. The build lives under the
# worktree and not in /tmp: nothing this project builds goes to /tmp.
#
#   sh tests/backports/host/intents-init/run.sh
#
# To rewrite expected.txt after a host change, on purpose:
#
#   sh tests/backports/host/intents-init/run.sh --write
set -eu
echo "FAIL host/intents-init/run.sh: its Python steps are gone and not yet ported to Lua: the inline block PY at line 53" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
BUILD=${BUILD:-$(runs_folder build/intents-init)}
rm -rf "$BUILD"
mkdir -p "$BUILD"
flags="-fobjc-arc -Wall -Wexcess-initializers -Werror"
# The host this run measured on, printed beside the verdict: expected.txt records a host, and a
# reader has to be able to tell a stale golden from a host that changed without guessing which.
host=$(sw_vers -productVersion)
build=$(sw_vers -buildVersion)
arch=$(uname -m)
echo "host   macOS $host build $build, $arch"
# Three counts and not two, because the file and the golden file are written from the same place and
# comparing them with each other only shows that they agree. The population the claim is about is
# the REGISTRY's: every `implemented` row naming -[<class> init]. A row added there and not here is
# a claim no run of this harness can reach, and INListCarsIntent was exactly that - its body moved
# into gen-intents.py's EXTRA_METHODS, the row was added, and neither file was regenerated, so 110
# of the 111 rows were being measured and the guard below was 110 against 110.
registry=$root/packages/a/apple-backports/registry/Intents
claimed=$(python3 - "$registry" <<'PY'
import glob, json, os, re, sys
names = set()
for path in sorted(glob.glob(os.path.join(sys.argv[1], "ios*.json"))):
    document = json.load(open(path, encoding="utf-8"))
    for entry in document["entries"] if isinstance(document, dict) else document:
        if entry.get("status") == "implemented":
            match = re.match(r"^-\[(\w+) init\]$", entry["api"])
            if match:
                names.add(match.group(1))
print(len(names))
PY
)
listed=$(grep -c '^    { "IN' "$here/init-classes.inc")
golden=$(grep -c '^[A-Za-z]' "$here/expected.txt")
echo "guard  $claimed implemented -init rows in registry/Intents, $listed in init-classes.inc, $golden in expected.txt"
# --write is how a short golden file is filled, so the golden count is only a failure when the run
# is not the one that fills it. The .inc count is checked either way: --write reads that file, and a
# population that does not match the registry would write a golden file for the wrong classes.
[ "$listed" -eq "$claimed" ] || {
    echo "  FAIL  the registry carries $claimed -init rows and init-classes.inc lists $listed" >&2
    echo "        regenerate it: xmake l tools/intents/gen-init-classes.lua -o tests/backports/host/intents-init/init-classes.inc" >&2
    exit 1
}
if [ "${1:-}" != "--write" ] && [ "$golden" -ne "$claimed" ]; then
    echo "  FAIL  the registry carries $claimed -init rows and expected.txt holds $golden" >&2
    echo "        the host may have changed, or a row may be new: sh tests/backports/host/intents-init/run.sh --write" >&2
    exit 1
fi

# 1. the controls
xcrun clang $flags "$here/provenance.m" -framework Foundation -framework Intents -o "$BUILD/provenance"
"$BUILD/provenance" | sed 's/^/  /'

# 2. the differential. One run, kept whole: the verdict is its exit code and the report is its
#    output, so a line cannot be printed here and compared there against a different run.
xcrun clang $flags "$here/init.m" -framework Foundation -framework Intents -o "$BUILD/init"
if [ "${1:-}" = "--write" ]; then
    echo "write  expected.txt from this run"
    "$BUILD/init" > "$BUILD/body.txt" 2> "$BUILD/write.err" || {
        echo "  intents-init: FAIL the measuring run failed" >&2
        sed 's/^/  /' "$BUILD/write.err" >&2
        exit 1
    }
    {
        # The comment header above the host line is carried verbatim and everything from the host
        # line down is written out, rather than the header being cut at the host line: a write on
        # an unchanged host then changes nothing at all, and a write on a NEW host says which host
        # these numbers are from. Measured 2026-10-03: cutting at the host line dropped two
        # comment lines a reader had put below it, so the file and its writer could not both be
        # right - and carrying them verbatim duplicates them, so the prose belongs here.
        awk '/^\/\/ macOS/{exit} {print}' "$here/expected.txt"
        echo "// macOS $host build $build, $arch, Foundation + Intents, measured with sw_vers on the run that"
        echo "// wrote these lines. run.sh prints the host it measured on beside the verdict, so a reader can tell a"
        echo "// stale golden from a host that changed without being told which one it is. A different host answers"
        echo "// with its own numbers and the guard above fails until this file is rewritten."
        cat "$BUILD/body.txt"
    } > "$BUILD/expected.txt"
    mv "$BUILD/expected.txt" "$here/expected.txt"
    echo "write  $(grep -c '^[A-Za-z]' "$here/expected.txt") data lines"
    exit 0
fi
"$BUILD/init" "$here/expected.txt" > "$BUILD/run.txt" 2> "$BUILD/summary.txt" && status=0 || status=$?
grep -E 'RED|golden lines' "$BUILD/run.txt" | sed 's/^/  /'
grep -E '^#' "$BUILD/summary.txt" | sed 's/^/  /'
if [ "$status" -ne 0 ]; then
    echo "  intents-init: FAIL the differential exited $status on macOS $host $arch"
    exit 1
fi

# 3. the plant: the same binary, one corrupted line, which must turn the verdict red
PLANT=one-wrong "$BUILD/init" "$here/expected.txt" > "$BUILD/plant.txt" 2>&1 && {
    echo "  intents-init: FAIL the plant passed, so the comparison is not guarding anything"
    exit 1
}
grep -E 'PLANT|differ' "$BUILD/plant.txt" | sed 's/^/  /'
echo "  intents-init: the plant is red, as it must be"
echo "  intents-init: ->  PASS on macOS $host $arch"
