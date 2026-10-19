#!/bin/sh
# run.sh - AVAssetExportSession.metadataItemFilter: what Apple's own session does with a filter, measured
# against a real export of a real file, and what the port does on a release-shaped session. Joined row by
# row, with the mutations that must be noticed.
#
#     sh tests/backports/host/avf-export-metadata-filter7/run.sh                     the differential
#     AVFEFMUTANT=<name> ... run.sh                                                a mutant, which must be noticed
#     AVFEFMUTANT=<name> CONTROL=1 ... run.sh                                      its control, which must be green
#
# Two programs, two builds, one table each:
#
#   the HOST half   writer.m, linked with this machine's own AVFoundation, exporting a real file it wrote.
#                   Apple's own answers, and the oracle.
#   the PORT half   portcheck.m, compiled with -I standin so <AVFoundation/AVFoundation.h> is a
#                   release-shaped export session with no 7.0 member - the port's guard reads a release
#                   that has not arrived, which is what happens on 6.1.3 and cannot happen here - and
#                   linked with the port's own AVAssetExportSessionMetadataItemFilter7.m UNMODIFIED.
#
# The join:
#
#   must match   both halves answer it and they agree. A difference is a failure unless ALLOWANCES names
#                it. There is one allowance, and it is the price of doing the filter at the only hook this
#                release has.
#   port only    the port answers something the host does not. Always a failure.
#   host only    the host answers something the port does not. Always a failure.
#
# Plus one assertion inside the PORT's own table, which is the row that matters: with a filter set and no
# metadata of the caller's, what the port leaves on the session must be EXACTLY what the release's own
# filtering entry point answers for the source's own array.
#
# **Directionality.** A mutant run is judged against the port's own unmutated table and must show all three
# of: a row that CHANGED, a change on a row that was RIGHT (the two halves agreed on it before the
# mutation), and a red verdict overall. A control runs each mutant's UNMUTATED source through the
# identical build-and-run path and must stay green.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/AVFoundation/AVAssetExportSessionMetadataItemFilter7.m
build=${AVFEF_BUILD:-$root/.agent-work/runs/avf-export-metadata-filter7}
oracle_dir=${AVFEF_ORACLE:-$root/.agent-work/runs/avf-export-metadata-filter7-oracle}
rm -rf "$build"
mkdir -p "$build/src"

FLAGS="-fobjc-arc -w"

mutate() {
    python3 - "$1" "$2" <<'PY'
import sys
path, which = sys.argv[1], sys.argv[2]
text = open(path).read()
MUTATIONS = {
    # the step itself, gone: with a filter set and no metadata of the caller's, nothing is left behind and
    # the row the check exists for goes back to nil.
    "nostep": ("""    if (!filter || session.metadata)
        return;""", "    return;"),
    # the header's second condition, dropped: "The filter will not be applied to metadata set with via the
    # metadata property" stops being true, and the caller's own array is replaced by the source's.
    "alwaysover": ("""    if (!filter || session.metadata)
        return;""", """    if (!filter)
        return;"""),
    # the header's first condition, dropped: with NO filter set the step runs anyway, and the session ends
    # up carrying the source's metadata where the caller set none.
    "nofiltercheck": ("""    if (!filter || session.metadata)
        return;""", """    if (session.metadata)
        return;"""),
}
before, after = MUTATIONS[which]
if before not in text:
    raise SystemExit("the %s mutation did not apply, so this run proves nothing" % which)
open(path, "w").write(text.replace(before, after, 1))
print("# applied the %s mutation" % which)
PY
}

want=${AVFEFMUTANT:-}
control=${CONTROL:-0}
cp "$port" "$build/src/port.m"
if [ "$control" = 0 ] && [ -n "$want" ]; then
    case "$want" in
        nostep|alwaysover|nofiltercheck) mutate "$build/src/port.m" "$want" ;;
        *) echo "FAIL: no such mutant: $want"; exit 1 ;;
    esac
fi

# ---- 1. the HOST half, once, and cached beside the build directory.
if [ ! -x "$oracle_dir/host" ]; then
    mkdir -p "$oracle_dir"
    # shellcheck disable=SC2086
    xcrun clang $FLAGS -DCHARN_PORT_HALF=0 "$here/writer.m" -framework Foundation -framework AVFoundation \
        -framework CoreMedia -o "$oracle_dir/host" > "$oracle_dir/build.log" 2>&1 || {
            echo "RUN FAILED: the host half did not build"; head -8 "$oracle_dir/build.log"; exit 1; }
    set +e; "$oracle_dir/host" > "$oracle_dir/host.table" 2> "$oracle_dir/host.stderr"; host_status=$?; set -e
    [ "$host_status" = 0 ] || { echo "RUN FAILED: the host half exited $host_status, which is a control failing"; exit 1; }
    grep -q 'CONTROL source file written | YES' "$oracle_dir/host.table" || {
        echo "RUN FAILED: the host half wrote no source file, so nothing below was measured"; exit 1; }
fi
cp "$oracle_dir/host.table" "$build/host.table"

# ---- 2. the PORT half, every run.
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$here/standin/standin.m" -o "$build/standin.o" \
    > "$build/standin.log" 2>&1 || { echo "RUN FAILED: the stand-in did not build"; head -8 "$build/standin.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$build/src/port.m" -o "$build/port.o" \
    > "$build/port.log" 2>&1 || { echo "RUN FAILED: the port's own file did not build against the stand-in"; head -8 "$build/port.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" "$here/portcheck.m" "$build/standin.o" "$build/port.o" \
    -framework Foundation -o "$build/port" > "$build/link.log" 2>&1 || {
        echo "RUN FAILED: the port half did not link - the port reached a member the release does not have"
        head -8 "$build/link.log"; exit 1; }
set +e; "$build/port" > "$build/port.table" 2> "$build/port.stderr"; port_status=$?; set -e

# The port half is a measurement of the port only if the guard let it install: the guard's member is the
# release's own 7.0 property, which a stand-in that carried it would make the port decline.
grep -q "CONTROL the guard's member audioTimePitchAlgorithm | ABSENT" "$build/port.table" || {
    echo "FAIL: the port half's guard read the release as carrying 7.0, so nothing below measured the port."
    exit 1; }

# ---- 3. the baseline: the PORT's own table, written on an unmutated run.
if [ -z "$want" ] || [ "$control" != 0 ]; then
    mkdir -p "$oracle_dir"
    cp "$build/port.table" "$oracle_dir/port.baseline"
else
    [ -f "$oracle_dir/port.baseline" ] || {
        echo "FAIL: the mutant was asked for with no baseline beside it. Run this script once with no"
        echo "      AVFEFMUTANT first: a mutant is judged against what the port answered unmutated."
        exit 1
    }
fi

# ---- 4. the join, the port's own assertion, and the verdict
set +e
python3 - "$build" "$oracle_dir" <<'PYEOF'
import sys, os
build, oracle_dir = sys.argv[1], sys.argv[2]

def load(name):
    rows = {}
    for line in open(name):
        if not line.strip():
            continue
        key, sep, value = line.rstrip("\n").partition(" | ")
        if not sep:
            print("MALFORMED       a line with no ' | ' in it: %s" % line.strip())
            continue
        rows[key.strip()] = value.strip()
    return rows

host = load(os.path.join(build, "host.table"))
port = load(os.path.join(build, "port.table"))

ALLOWANCES = {
 "sharing filter: metadata after the export":
   "Apple's own session writes the kept items into the OUTPUT FILE and leaves `metadata` nil - measured "
   "here, on a real export of a real file. This release has no member that hands the file a list, so the "
   "port leaves the filtered items on the session and lets the release's own export write them. The value "
   "is not free: the row below asserts it is exactly the release's own filtered answer",
}

# The rows that describe the two BUILDS: the host half exports a real file this machine wrote and the port
# half a stand-in's two-item array, so these are about what each half was given, not about what either
# answered. A difference in a must-match row below is a difference in the port.
BUILD_PREFIXES = ("CONTROL ", "release filter:", "rows")
port_only = host_only = unequal = 0
unexplained = []
for key in sorted(set(host) | set(port)):
    if key.startswith(BUILD_PREFIXES):
        continue
    if key not in port:
        print("HOST ONLY        %s" % key); host_only += 1
    elif key not in host:
        print("PORT ONLY        %s" % key); port_only += 1
    elif host[key] != port[key]:
        unequal += 1
        if key in ALLOWANCES:
            print("ALLOWED          %-46s host=[%s] port=[%s]" % (key, host[key], port[key]))
        else:
            print("UNEXPLAINED      %-46s host=[%s] port=[%s]" % (key, host[key], port[key]))
            unexplained.append(key)

# The assertion inside the port's own table: the row the object exists for.
kept = port.get("sharing filter: metadata after the export")
release = port.get("release filter: sharing filter over the source")
if kept != release:
    print("UNEXPLAINED      the port left [%s] on the session and the release's own filter answers [%s] "
          "for the source's array" % (kept, release))
    unexplained.append("sharing filter: metadata after the export")
print("SUMMARY rows: host=%d port=%d  must-match-unequal=%d port-only=%d host-only=%d unexplained=%d"
      % (len(host), len(port), unequal, port_only, host_only, len(unexplained)))
sys.exit(1 if (port_only or host_only or unexplained) else 0)
PYEOF
join_status=$?
set -e

# ---- 5. the directionality assertion, and the control
if [ -n "$want" ] && [ "$control" = 0 ]; then
    set +e
    changed=$(python3 - "$build" "$oracle_dir" <<'PYEOF'
import sys, os
build, oracle_dir = sys.argv[1], sys.argv[2]
def load(name):
    rows = {}
    for line in open(name):
        if not line.strip():
            continue
        key, _, value = line.rstrip("\n").partition(" | ")
        rows[key.strip()] = value.strip()
    return rows
base = load(os.path.join(oracle_dir, "port.baseline"))
port = load(os.path.join(build, "port.table"))
host = load(os.path.join(build, "host.table"))
changed, right_then_wrong = [], []
for key in set(base) | set(port):
    if base.get(key) == port.get(key):
        continue
    changed.append(key)
    if key in host and base.get(key) == host[key]:
        right_then_wrong.append(key)
    elif key == "sharing filter: metadata after the export" and base.get(key) == base.get("release filter: sharing filter over the source"):
        # the port's own oracle: the value was RIGHT against the release's filtering entry point
        right_then_wrong.append(key)
for key in sorted(right_then_wrong):
    print("BROKE A RIGHT ONE  %-46s was=[%s] now=[%s]" % (key, base.get(key), port.get(key)))
for key in sorted(changed):
    print("CHANGED           %-46s before=[%s] after=[%s]" % (key, base.get(key), port.get(key)))
print("DIRECTIONALITY changed=%d right-then-wrong=%d" % (len(changed), len(right_then_wrong)))
sys.exit(0 if (changed and right_then_wrong) else 1)
PYEOF
)
    dir_status=$?
    set -e
    if [ "$dir_status" != 0 ]; then
        echo "FAIL: the $want mutation was NOT noticed in the required direction: it did not turn a right"
        echo "      answer wrong."
        echo "$changed"
        exit 1
    fi
    if [ "$join_status" = 0 ]; then
        echo "FAIL: the $want mutation changed a right answer and the join stayed GREEN."
        exit 1
    fi
    echo "ok  the $want mutation was noticed, turned a right answer wrong, and the join went red:"
    echo "$changed" | grep -E '^(CHANGED|BROKE)' | head -10
    echo "DIRECTIONALITY $(echo "$changed" | tail -1)"
    echo "log=$build"
    exit 0
fi

if [ -n "$want" ] && [ "$control" != 0 ]; then
    if [ "$join_status" != 0 ]; then
        echo "FAIL: the $want control is not green. The control runs the UNMUTATED source through the"
        echo "      identical build-and-run path, so a red here is the path, not the mutation."
        exit 1
    fi
    echo "ok  the $want control is green: the unmutated source through the same path"
    echo "log=$build"
    exit 0
fi

if [ "$port_status" != 0 ]; then
    echo "FAIL: the port half exited $port_status. Its rows are the port's, and a run that died half way"
    echo "      through prints a table that reads like a measurement and is not one."
    head -5 "$build/port.stderr" | sed 's/^/    /'
    exit 1
fi
if [ "$join_status" != 0 ]; then
    echo "FAIL: the differential is not green"
    exit 1
fi
echo "ok  every row the two halves answer agrees except the one the release cannot answer on this side, and"
echo "    what the port leaves on the session is the release's own filtered answer for the source"
echo "log=$build"
