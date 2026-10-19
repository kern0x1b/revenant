#!/bin/sh
# run.sh - the 8.0 multi-pass writer input, Apple's own answers against the port's, joined row by row,
# with the mutations that must be noticed.
#
#     sh tests/backports/host/avf-writerinput8/run.sh                       the differential
#     AVFWMUTANT=<name> ... run.sh                                          a mutant, which must be noticed
#     AVFWMUTANT=<name> CONTROL=1 ... run.sh                                its control, which must be green
#
# ONE source, writer.m, compiled twice: once with the real <AVFoundation/AVFoundation.h> and this
# machine's own AVFoundation - the ORACLE, from which every expectation is read - and once with -I standin
# and the port's own packages/a/apple-backports/AVFoundation/AVAssetWriterInputMultiPass8.m linked in
# UNMODIFIED, against a stand-in release shaped like the one the port runs on.
#
# The join is not "nothing differs". Every row falls into one of three classes:
#
#   must match   both halves answer it and they must agree. A difference is a failure unless ALLOWANCES
#                names it, and ALLOWANCES is a short list of differences in the PORT's build, each with
#                the measurement that explains it.
#   answers less the host answers it and the port does not. Always a failure.
#   row missing  one half printed a row the other did not. Always a failure: the sequence is one source,
#                so a row that is there on one side only is a difference in the run and not in the code.
#
# **Directionality.** The check is not "nothing differs" but "a mutation must turn a RIGHT answer wrong".
# A mutant run is judged against the port's own unmutated table and must show all three of: a row that
# CHANGED, a change on a row that was RIGHT (it matched the host before the mutation and does not after),
# and a red verdict overall. "RIGHT" is measured against the host table, so a mutation whose only effect is
# on a row that was already allowed to differ cannot be accepted by it - which is what the MOVED TOWARD HOST
# lines report when they appear, and they do appear: the `finalcall` mutation drops the port's invocation
# count from 2 to 1 on a switch-on row where the host's own answer is 1, so it agrees MORE closely with the
# host there while breaking five rows that matched. A control runs each mutant's UNMUTATED source through
# the identical build-and-run path and must stay green, so a red mutant is the mutation and not the path.
#
# The host table is built once and cached beside the build directory, which is removed on every run; a
# baseline that a run deletes is a baseline no mutant can be judged against.
#
# Not run through heavy.sh: it compiles four small files, links two binaries and runs them, and the
# fleet's heavy lane is for the gate.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/AVFoundation/AVAssetWriterInputMultiPass8.m
build=${AVFW_BUILD:-$root/.agent-work/runs/avf-writerinput8}
# BESIDE the build directory, not inside it.
oracle_dir=${AVFW_ORACLE:-$root/.agent-work/runs/avf-writerinput8-oracle}
rm -rf "$build"
mkdir -p "$build"

FLAGS="-fobjc-arc -w"

# ---- the six mutations. Each changes a line the join READS, and each names the rows it must break, so
#      "the mutant went red" and "the mutant broke the thing it aimed at" are one claim.
mutate() {
    python3 - "$1" "$2" <<'PY'
import sys
path, which = sys.argv[1], sys.argv[2]
text = open(path).read()
MUTATIONS = {
    # the pass the writer's -startWriting begins. Read by every "currentPassDescription after startWriting"
    # row, which the port answers {0/1,0/0} and the host answers too.
    "beginpass": ("            for (AVAssetWriterInput *each in self_.inputs)\n                charon_begin_pass(each);",
                  "            for (AVAssetWriterInput *each in self_.inputs)\n                (void)each;"),
    # the time range of that pass: zero to POSITIVE INFINITY, which is what both halves print.
    "ranges": ("CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)",
               "CMTimeRangeMake(kCMTimeZero, kCMTimeZero)"),
    # the final invocation of the block after the pass ends. Read by "block calls after
    # markCurrentPassAsFinished", which is 2 on both sides.
    "finalcall": ("""    dispatch_queue_t queue = objc_getAssociatedObject(self, &charon_multipass_queue);
    if (queue) {
        dispatch_async(queue, ^{
            charon_invoke_pass_callback(self);
        });
    }""", "    (void)0;"),
    # THE LEFTOVER'S DEFECT. -markCurrentPassAsFinished forwarding to the release's -markAsFinished
    # finishes the input a second time; read by "markCurrentPassAsFinished called markAsFinished itself",
    # which is NO on both sides.
    "forward": ("""    charon_end_pass(self);
    dispatch_queue_t queue""", """    charon_end_pass(self);
    [self markAsFinished];
    dispatch_queue_t queue"""),
    # the setter's own precondition: "This property cannot be set after writing on the receiver's
    # AVAssetWriter has started". Read by "performsMultiPassEncodingIfSupported set YES after
    # startWriting", which RAISES on both sides.
    "setafter": ("""    if (objc_getAssociatedObject(self, &charon_multipass_writing))
        charon_raise(@"-[AVAssetWriterInput setPerformsMultiPassEncodingIfSupported:] cannot be called after the input's asset writer has started writing");""",
                 "    (void)0;"),
    # the export's own precondition, same sentence for the export session. Read by
    # "canPerformMultiplePassesOverSourceMediaData set YES after the export started", which RAISES.
    "exportafter": ("""    if (objc_getAssociatedObject(self, &charon_export_started))
        charon_raise(@"-[AVAssetExportSession setCanPerformMultiplePassesOverSourceMediaData:] cannot be called after the export has started");""",
                    "    (void)0;"),
}
before, after = MUTATIONS[which]
if before not in text:
    raise SystemExit("the %s mutation did not apply, so this run proves nothing" % which)
open(path, "w").write(text.replace(before, after, 1))
print("# applied the %s mutation" % which)
PY
}

want=${AVFWMUTANT:-}
control=${CONTROL:-0}
case "$want" in
    beginpass|beginpass2) : ;;
esac

# ---- 1. the source, copied and mutated. The PORT's file is never edited in place.
mkdir -p "$build/src"
cp "$port" "$build/src/port.m"
if [ "$control" = 0 ] && [ -n "$want" ]; then
    case "$want" in
        beginpass)  mutate "$build/src/port.m" beginpass ;;
        ranges)     mutate "$build/src/port.m" ranges ;;
        finalcall)  mutate "$build/src/port.m" finalcall ;;
        forward)    mutate "$build/src/port.m" forward ;;
        setafter)   mutate "$build/src/port.m" setafter ;;
        exportafter) mutate "$build/src/port.m" exportafter ;;
        *)          echo "FAIL: no such mutant: $want"; exit 1 ;;
    esac
fi

# ---- 2. the PORT half: the stand-in release and the port's own object, both compiled against the
#         stand-in's header, then linked. A port object that referenced a member the release does not have
#         fails at THIS link and not before, which is the point of linking rather than copying.
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$here/standin/standin.m" -o "$build/standin.o" \
    > "$build/standin.log" 2>&1 || { echo "RUN FAILED: the stand-in did not build"; head -8 "$build/standin.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$build/src/port.m" -o "$build/port.o" \
    > "$build/port.log" 2>&1 || { echo "RUN FAILED: the port's own file did not build against the stand-in"; head -8 "$build/port.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$here/writer.m" -o "$build/writer.o" \
    > "$build/writer.log" 2>&1 || { echo "RUN FAILED: writer.m did not build against the stand-in"; head -8 "$build/writer.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS "$build/writer.o" "$build/standin.o" "$build/port.o" \
    -framework Foundation -framework CoreMedia -o "$build/port" > "$build/link.log" 2>&1 || {
        echo "RUN FAILED: the port half did not link - the port reached a member the release does not have"
        head -8 "$build/link.log"; exit 1; }
set +e; "$build/port" > "$build/port.table" 2> "$build/port.stderr"; port_status=$?; set -e

# ---- 3. the HOST half, once. Built without -I standin, so <AVFoundation/AVFoundation.h> is the real one,
#         and linked against this machine's own AVFoundation. The BINARY and the TABLE are cached
#         separately and each is built when it is missing: a cached binary with no table (an interrupted
#         run, or an oracle directory handed to a fresh tree) used to be copied as a table that was not
#         there, and the join then read whatever was left.
if [ ! -x "$oracle_dir/host" ]; then
    mkdir -p "$oracle_dir"
    # shellcheck disable=SC2086
    xcrun clang $FLAGS "$here/writer.m" -framework Foundation -framework AVFoundation -framework CoreMedia \
        -o "$oracle_dir/host" > "$oracle_dir/build.log" 2>&1 || {
            echo "RUN FAILED: the host half did not build"; head -8 "$oracle_dir/build.log"; exit 1; }
fi
if [ ! -f "$oracle_dir/host.table" ]; then
    set +e; "$oracle_dir/host" > "$oracle_dir/host.table" 2> "$oracle_dir/host.stderr"; host_status=$?; set -e
    if [ "$host_status" != 0 ]; then
        echo "RUN FAILED: the host half exited $host_status, which is a control failing and not a result"
        exit 1
    fi
fi
# A TABLE THAT WAITED AND GOT NOTHING IS NOT CACHED, AND IS NOT USED. writer.m prints TIMED-OUT-<bound>
# instead of a count when the invocation AVAssetWriterInput.h:492 promises in response to
# -markCurrentPassAsFinished did not arrive inside the bound, and that marker says the run did not answer
# the question - it says the oracle could not. Caching such a table would repeat exactly the failure this
# rule exists for: the coordinator's gate read "currentPassDescription after markAsFinished host=[{0/1,0/0}]"
# and "markAsFinished after the final pass invocation host=[RAISED NSInternalInconsistencyException]" out of
# a table built once under load beside fifteen other tests, and every later run in that tree reported
# unexplained=2 while a fresh tree of the same commit answered unexplained=0 every time. So the table is
# named, deleted, and the run fails - and because the check sits HERE rather than inside the build, it
# also rejects a table that was already cached, which is the case that bit.
if grep -q 'TIMED-OUT' "$oracle_dir/host.table"; then
    echo "RUN FAILED: the host half did not settle, and its table is neither used nor cached. These rows"
    echo "      waited for an invocation the header promises and did not get it inside the bound:"
    grep 'TIMED-OUT' "$oracle_dir/host.table" | sed 's/^/      /'
    rm -f "$oracle_dir/host.table"
    echo "      Deleted, so the next run builds the oracle again from scratch rather than inherit it."
    exit 1
fi
cp "$oracle_dir/host.table" "$build/host.table"
host_status=0
[ -f "$oracle_dir/host.stderr" ] && cp "$oracle_dir/host.stderr" "$build/host.stderr"

# ---- 4. the baseline: the PORT's own table, written on an unmutated run and read by a mutant run.
if [ -z "$want" ] || [ "$control" != 0 ]; then
    mkdir -p "$oracle_dir"
    cp "$build/port.table" "$oracle_dir/port.baseline"
else
    [ -f "$oracle_dir/port.baseline" ] || {
        echo "FAIL: the mutant was asked for with no baseline beside it. Run this script once with no"
        echo "      AVFWMUTANT first: a mutant is judged against what the port answered unmutated."
        exit 1
    }
fi

# ---- 5. the join and the verdict
set +e
python3 - "$build" "$oracle_dir" <<'PYEOF'
import sys, os
build, oracle_dir = sys.argv[1], sys.argv[2]

def load(path):
    rows = {}
    if not os.path.exists(path):
        return rows
    for line in open(path):
        if not line.strip():
            continue
        key, sep, value = line.rstrip("\n").partition(" | ")
        if not sep:
            print("MALFORMED         the host or the port printed a line with no ' | ' in it: %s" % line.strip())
            continue
        rows[key.strip()] = value.strip()
    return rows

host = load(os.path.join(build, "host.table"))
port = load(os.path.join(build, "port.table"))
base = load(os.path.join(oracle_dir, "port.baseline"))

# The differences that are in the PORT's build and not in the host's. Each one is a row Apple's own
# single-pass class does not produce here either, and each says why.
ALLOWANCES = {
 # --- the switch. 6.1.3's writer has no analysis pass to hand out, so the port answers NO whatever the
 #     client sets; a YES would ask it to append the same media again to a writer it has been told it is
 #     finished with, which is the call that raises. Apple's own class answers YES from the switch alone
 #     and runs a genuine second pass. Every row below follows from that one fact.
 "switch-on unattached: canPerformMultiplePasses unattached after setting the switch":
   "the switch is stored and reads back; the writer cannot re-read its source on the release this port "
   "runs on, so canPerformMultiplePasses is NO. Measured: Apple's own class answers YES from the switch "
   "alone, before anything is attached",
 "switch-on before startWriting: canPerformMultiplePasses attached before startWriting":
   "follows the switch: NO here, for the reason on the row above",
 "switch-on: canPerformMultiplePasses after startWriting": "follows the switch",
 "switch-on: canPerformMultiplePasses after setting the switch post-start": "follows the switch",
 "switch-on: canPerformMultiplePasses after markCurrentPassAsFinished": "follows the switch",
 "switch-on: currentPassDescription after markCurrentPassAsFinished":
   "Apple nominates a SECOND pass here - the description is still live and the block ran once, not twice. "
   "This port has no analysis pass to hand out, and AVAssetWriterInput.h:512 says that with "
   "canPerformMultiplePasses NO the description becomes nil at once",
 "switch-on: block calls after markCurrentPassAsFinished":
   "follows the row above: two invocations here, one where Apple starts a second pass",
 "switch-on: block on the given queue after markCurrentPassAsFinished":
   "follows the row above; both halves deliver every invocation on the queue the client gave",
 "switch-on: block calls after a second markCurrentPassAsFinished":
   "Apple is between passes there and refuses a second -markCurrentPassAsFinished because a pass is "
   "pending, so its one invocation stands; this port has no pending pass",
 "switch-on: block saw":
   "follows the second-pass rows: the port's block sees the first pass and then nil, which is the whole "
   "of what a single-pass writer has to offer",
 "switch-on: markCurrentPassAsFinished a second time":
   "the HOST's own answer here is not reproducible: six runs of the oracle gave RAISED five times and "
   "ACCEPTED once, because with the switch on Apple's analysis pass may already have finished by the time "
   "the second call arrives. The port refuses in both configurations, which is what the host did in five "
   "of six runs and in every switch-off run",
 # --- WHEN the first invocation arrives. Measured on the host: nothing has been invoked at the instant
 #     the call returns, and one invocation arrives on the given queue once the writer's own setup has
 #     run. Which instant that is between is Apple's internal timing and not an answer the header gives,
 #     so the count AT registration may differ; both halves deliver it on the given queue, which the
 #     "on the given queue" rows show.
 "switch-off: block calls on registration":
   "the host delivers the first invocation from its own setup, after the call has returned; this port "
   "queues it, so it is delivered before the queue drains",
 "switch-off: block on the given queue on registration": "follows the row above",
 "switch-on: block calls on registration": "follows the registration rows above",
 "switch-on: block on the given queue on registration": "follows the registration rows above",
 # --- the STAND-IN's own two answers, which are the stand-in's and not the port's. Each says what the
 #     release's own class does, measured on the host.
 "switch-off before startWriting: markAsFinished before startWriting":
   "the release's -markAsFinished refuses before -startWriting (measured: NSInternalInconsistencyException, "
   "'Cannot call method when status is 0'); the stand-in records it instead. Nothing in this family calls "
   "it in that state - the port raises from -markCurrentPassAsFinished first",
 "switch-on before startWriting: markAsFinished before startWriting": "follows the row above",
 "switch-off: finishWriting":
   "the real writer refuses to finish a file nothing was appended to (measured NO); the stand-in has no "
   "encoder and answers YES. The harness appends nothing in either half",
 "switch-on: finishWriting": "follows the row above",
}
# Rows that describe the two BUILDS and not the two answers: a name the real framework has and the
# stand-in header does not, and the settings row, which names what each half asked its own writer.
BUILD_ROWS = {
 "CONTROL: CLASS AVAssetWriterInputPassDescription": "the stand-in declares the class and does not implement it; the port brings it",
 "CONFIGURATION: h264 16x16, no bitrate": "each half asks its own writer what it can encode",
}

less = more = differs = malformed = 0
unexplained = []
for key in sorted(set(host) | set(port)):
    if key in BUILD_ROWS:
        print("BUILD             %-74s %s" % (key, BUILD_ROWS[key]))
        continue
    if key not in port:
        print("ANSWERS LESS      %s" % key); less += 1
    elif key not in host:
        print("HOST LACKS IT     %s" % key); more += 1
    elif host[key] != port[key]:
        differs += 1
        if key in ALLOWANCES:
            print("ALLOWED           %-74s host=[%s] port=[%s]" % (key, host[key], port[key]))
        else:
            print("UNEXPLAINED       %-74s host=[%s] port=[%s]" % (key, host[key], port[key]))
            unexplained.append(key)
print("SUMMARY rows: host=%d port=%d  must-match-unequal=%d answers-less=%d host-lacks=%d unexplained=%d"
      % (len(host), len(port), differs, less, more, len(unexplained)))
sys.exit(1 if (less or more or unexplained) else 0)
PYEOF
join_status=$?
set -e

# ---- 6. the directionality assertion, and the control
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
port, host = load(os.path.join(build, "port.table")), load(os.path.join(build, "host.table"))
changed, right_then_wrong, closer = [], [], []
for key in set(base) | set(port):
    if base.get(key) == port.get(key):
        continue
    changed.append(key)
    if key in host and base.get(key) == host[key] and port.get(key) != host[key]:
        right_then_wrong.append(key)
    elif key in host and base.get(key) != host[key] and port.get(key) == host[key]:
        closer.append(key)
for key in sorted(right_then_wrong):
    print("BROKE A RIGHT ONE  %s" % key)
for key in sorted(closer):
    print("MOVED TOWARD HOST  %s" % key)
for key in sorted(changed):
    print("CHANGED           %-74s before=[%s] after=[%s]" % (key, base.get(key), port.get(key)))
print("DIRECTIONALITY changed=%d right-then-wrong=%d moved-toward-host=%d"
      % (len(changed), len(right_then_wrong), len(closer)))
sys.exit(0 if (changed and right_then_wrong) else 1)
PYEOF
)
    dir_status=$?
    set -e
    if [ "$dir_status" != 0 ]; then
        echo "FAIL: the $want mutation was NOT noticed in the required direction: it did not turn a"
        echo "      right answer wrong. A mutation that only moves the port AWAY from a row that already"
        echo "      differed is not a check; it needs a row that was RIGHT."
        echo "$changed"
        exit 1
    fi
    if [ "$join_status" = 0 ]; then
        echo "FAIL: the $want mutation changed a row that matched the host and the join stayed GREEN, so"
        echo "      nothing the check reads was wrong. A mutation must be noticed by the join too."
        exit 1
    fi
    echo "ok  the $want mutation was noticed, turned a right answer wrong, and the join went red:"
    echo "$changed" | grep -E '^(CHANGED|BROKE|MOVED)' | head -14
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
echo "ok  every row Apple's own single-pass input answers is answered by the port, and what differs is"
echo "    one switch-on difference the port's own file writes down with the measurement behind it"
echo "log=$build"