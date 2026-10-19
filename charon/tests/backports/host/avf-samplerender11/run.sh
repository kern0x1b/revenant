#!/bin/sh
# run.sh - the 11.0 sample-buffer render pair, Apple's own answers against the port's, joined row by row,
# with the mutations that must be noticed.
#
#     sh tests/backports/host/avf-samplerender11/run.sh                       the differential
#     AVFSRMUTANT=<name> ... run.sh                                          a mutant, which must be noticed
#     AVFSRMUTANT=<name> CONTROL=1 ... run.sh                                its control, which must be green
#
# ONE source, samplerender.m, compiled twice: once with the real <AVFoundation/AVFoundation.h> and this
# machine's own AVFoundation - the ORACLE, from which every expectation in the join is read - and once with
# -I standin and the port's own AVFoundation/AVSampleBufferRenderSynchronizer11.m,
# AVSampleBufferAudioRenderer11.m, AVSampleBufferRenderSynchronizer12.m, AVSampleBufferRenderSynchronizer14.m,
# AVFoundationConstants70.m and AVFoundationConstants110.m linked in UNMODIFIED, against a stand-in release
# shaped like the one the port runs on.
#
# The join is not "nothing differs". Every row falls into one of three classes:
#
#   must match   both halves answer it and they must agree. A difference is a failure unless ALLOWANCES
#                names it, and ALLOWANCES is a short list of differences in the PORT's build, each with the
#                measurement that explains it.
#   answers less the host answers it and the port does not. Always a failure.
#   row missing  one half printed a row the other did not. Always a failure: the sequence is one source, so
#                a row that is there on one side only is a difference in the run and not in the code.
#
# **Directionality.** The check is not "nothing differs" but "a mutation must turn a RIGHT answer wrong".
# A mutant run is judged against the port's own unmutated table and must show all three of: a row that
# CHANGED, a change on a row that was RIGHT (it matched the host before the mutation and does not after),
# and a red verdict overall. "RIGHT" is measured against the host table, so a mutation whose only effect is
# on a row that was already allowed to differ cannot be accepted by it. A control runs each mutant's
# UNMUTATED source through the identical build-and-run path and must stay green, so a red mutant is the
# mutation and not the path.
#
# The host table is built once and cached beside the build directory, which is removed on every run; a
# baseline that a run deletes is a baseline no mutant can be judged against.
#
# Twelve mutations, and one thing in the port's own code that deliberately has none. -addRenderer: sets the
# master relationship between the two clocks, and every rate or time change after that propagates the rate
# and the time to every attached renderer (which is what makes a renderer's clock read the synchronizer's),
# so removing the two lines in -addRenderer: changes nothing this check can see: the first rate change after
# the attach does the same work. The one row that reads the master relationship is the row the two halves
# deliberately differ on - this Mac's own renderer answers nil from CMTimebaseGetMasterTimebase for both
# clocks and keeps them in step by propagating instead - so no mutation of those two lines can turn a RIGHT
# answer wrong, and the `raterenderers` mutation covers what they do.
#
# **What this machine cannot answer, and what the run does about it.** CoreAudio reports the hardware not
# running here ('who?' for kAudioHardwarePropertyDevices) and AudioQueueNewOutput fails, so no audio
# reaches an output on this machine - and this machine's own renderer stalls on the first buffer it is
# given and then ABORTS on a flush, a rate change or a release. The run therefore asks the flush rows and
# the rate-change rows of renderers that hold no media at all, which is askable, and the rows that a
# stalled renderer would answer are the ALLOWANCES below. Every measurement behind that is in
# packages/a/apple-backports/facts/AVFoundation/SampleBufferRender11.md.
#
# Not run through heavy.sh: it compiles six small files, links two binaries and runs them, and the fleet's
# heavy lane is for the gate.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/AVFoundation
build=${AVFSR_BUILD:-$root/.agent-work/runs/avf-samplerender11}
# BESIDE the build directory, not inside it.
oracle_dir=${AVFSR_ORACLE:-$root/.agent-work/runs/avf-samplerender11-oracle}
rm -rf "$build"
mkdir -p "$build"

FLAGS="-fobjc-arc -w"

# ---- the mutations. Each changes a line the join READS, and each names the rows it must break, so "the
#      mutant went red" and "the mutant broke the thing it aimed at" are one claim.
mutate() {
    python3 - "$1" "$2" <<'PY'
import sys
path, which = sys.argv[1], sys.argv[2]
text = open(path).read()
MUTATIONS = {
    # the rate the synchronizer answers: the port stores the clock's own rate, and this answers a constant.
    # Read by every "rate after setRate:" row, which the port answers 0.000/1.000/2.000 and so does the host.
    "rate": ("    return _rate;", "    return 1.0f;"),
    # a removal leaves the renderer's clock where it was instead of stopping it and taking it back to zero.
    # Read by "the renderer's clock is at zero after it is removed" and "the renderer's clock is stopped
    # after it is removed", which both answer YES - measured on the host as 0.0000 at a rate of 0.000.
    "detachclock": ("        CMTimebaseSetRate(rendererTimebase, 0.0);\n        CMTimebaseSetTime(rendererTimebase, kCMTimeZero);",
                    "        CMTimebaseSetRate(rendererTimebase, CMTimebaseGetRate(_timebase));"),
    # the periodic observer's re-arm: the port re-arms one interval on, and this re-arms where it already is.
    # Read by "consecutive periodic times are 100 ms apart within 20 ms" and by the three-fires row.
    "periodicinterval": ("        [self charon_armAt:CMTimeAdd(now, self->interval)];",
                         "        [self charon_armAt:now];"),
    # -removeTimeObserver: does nothing, so the first periodic observer keeps firing. Read by "no further
    # periodic calls after removeTimeObserver:", which the host answers YES and so does the port.
    "removeobserver": ("    if (![_observers containsObject:observer])\n        return;      // measured: removing the same token twice is accepted and does nothing\n    [_observers removeObject:observer];",
                       "    return;"),
    # -addRenderer: accepts the same renderer twice. Read by "adding the same renderer twice is refused",
    # which both answer YES.
    "addtwice": ("    if ([_renderers containsObject:renderer])\n        // Measured: the host raises, with the reason \"The SampleBufferRenderer cannot be added to a\n        // Synchronizer more than once\".\n        [NSException raise:NSInvalidArgumentException\n                    format:@\"-[AVSampleBufferRenderSynchronizer addRenderer:] cannot add the same renderer twice\"];",
                 "    (void)0;"),
    # a boundary time already reached fires anyway. Read by "boundary observer for a time already past
    # fired", which both answer NO.
    "boundarypast": ("        if (!CMTIME_IS_NUMERIC(time) || CMTimeCompare(time, now) <= 0)\n            continue;",
                     "        (void)now;"),
    # -addBoundaryTimeObserverForTimes: takes an empty list. Read by "boundary observer for no times is
    # refused", which both answer YES.
    "emptytimes": ("    if (!times.count)\n        // Measured: the host raises NSInvalidArgumentException with the reason\n        // \"-[AVOccasionalTimebaseObserver initWithTimebase:times:queue:block:] invalid parameter not\n        // satisfying: [times count] > 0\".\n        [NSException raise:NSInvalidArgumentException\n                    format:@\"-[AVSampleBufferRenderSynchronizer addBoundaryTimeObserverForTimes:queue:usingBlock:] needs at least one time\"];",
                 "    (void)0;"),
    # -flush claims the renderer has rendered. Read by "status after -flush, with no media", which both
    # answer 0.
    "flushstatus": ("    [self charon_reportReadiness];\n}\n\n- (void)flushFromSourceTime:",
                    "    _status = AVQueuedSampleBufferRenderingStatusRendering;\n    [self charon_reportReadiness];\n}\n\n- (void)flushFromSourceTime:"),
    # -isReadyForMoreMediaData answers YES whatever the renderer holds. Read by "isReadyForMoreMediaData
    # after the first enqueue", which both answer NO.
    "readiness": ("        return _pending.count == 0;", "        return YES;"),
    # -setVolume: holds a fixed volume whatever it is given. Read by "volume after setVolume: 0.25", which
    # both answer 0.250.
    "volume": ("    _volume = volume;\n    [self charon_applyVolume];", "    _volume = 1.0f;\n    [self charon_applyVolume];"),
    # One @dynamic removed, which is what a class answers when clang is left to synthesise a property the
    # rows say is absent: the accessors come back and respondsToSelector: answers YES. Read by "absent: the
    # renderer answers respondsToSelector: for allowedAudioSpatializationFormats", which the join requires
    # the port to answer NO.
    "nodynamic": ("@dynamic allowedAudioSpatializationFormats;", "// (the @dynamic for allowedAudioSpatializationFormats is gone)"),
    # the rate a synchronizer change reaches its renderers with: this never sets it. Read by "rate 0 stops
    # the renderer's timebase" and "the renderer reads the synchronizer's rate through its timebase", which
    # both answer YES.
    "raterenderers": ("        CMTimebaseSetRate(renderer.timebase, rate);\n        if ([renderer respondsToSelector:@selector(charon_renderSynchronizerDidChangeRate)])",
                      "        if ([renderer respondsToSelector:@selector(charon_renderSynchronizerDidChangeRate)])"),
}
before, after = MUTATIONS[which]
if before not in text:
    raise SystemExit("the %s mutation did not apply, so this run proves nothing" % which)
open(path, "w").write(text.replace(before, after, 1))
print("# applied the %s mutation" % which)
PY
}

want=${AVFSRMUTANT:-}
control=${CONTROL:-0}

# ---- 1. the sources, copied and mutated. The PORT's files are never edited in place.
mkdir -p "$build/src"
cp "$port/AVSampleBufferRenderSynchronizer11.m" "$build/src/synchronizer.m"
cp "$port/AVSampleBufferAudioRenderer11.m" "$build/src/renderer.m"
cp "$port/AVSampleBufferRenderSynchronizer12.m" "$build/src/currenttime.m"
cp "$port/AVSampleBufferRenderSynchronizer14.m" "$build/src/anchor.m"
if [ "$control" = 0 ] && [ -n "$want" ]; then
    case "$want" in
        rate|detachclock|raterenderers) mutate "$build/src/synchronizer.m" "$want" ;;
        boundarypast|emptytimes|removeobserver) mutate "$build/src/synchronizer.m" "$want" ;;
        flushstatus|readiness|volume|nodynamic) mutate "$build/src/renderer.m" "$want" ;;
        periodicinterval) mutate "$build/src/synchronizer.m" "$want" ;;
        addtwice) mutate "$build/src/synchronizer.m" "$want" ;;
        *)          echo "FAIL: no such mutant: $want"; exit 1 ;;
    esac
fi

# ---- 2. the PORT half: the stand-in release and the port's own objects, both compiled against the
#         stand-in's header, then linked. A port object that referenced a member the release does not have
#         fails at THIS link and not before, which is the point of linking rather than copying.
for object in standin synchronizer renderer currenttime anchor; do
    case "$object" in
        standin) source="$here/standin/standin.m" ;;
        *) source="$build/src/$object.m" ;;
    esac
    # The port's own private header travels with them: -I the port's own AVFoundation folder is what a
    # client of the port compiles against.
    # shellcheck disable=SC2086
    xcrun clang $FLAGS -I "$here/standin" -I "$port" -c "$source" -o "$build/$object.o" \
        > "$build/$object.log" 2>&1 || { echo "RUN FAILED: $object did not build against the stand-in"; head -8 "$build/$object.log"; exit 1; }
done
# The port's own constant objects, for the two values the harness reads back through the class under test
# and the notification the rate change posts. They are the port's, at 7.0 and 11.0, and they are linked
# unmodified against the same stand-in.
for source in AVFoundationConstants70 AVFoundationConstants110; do
    # shellcheck disable=SC2086
    xcrun clang $FLAGS -I "$here/standin" -I "$port" -c "$port/$source.m" -o "$build/$source.o" \
        > "$build/$source.log" 2>&1 || { echo "RUN FAILED: $source did not build against the stand-in"; head -8 "$build/$source.log"; exit 1; }
done
# shellcheck disable=SC2086
xcrun clang $FLAGS -I "$here/standin" -c "$here/samplerender.m" -o "$build/samplerender.o" \
    > "$build/samplerender.log" 2>&1 || { echo "RUN FAILED: samplerender.m did not build against the stand-in"; head -8 "$build/samplerender.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS "$build/samplerender.o" "$build/standin.o" "$build/synchronizer.o" "$build/renderer.o" \
    "$build/currenttime.o" "$build/anchor.o" "$build/AVFoundationConstants70.o" "$build/AVFoundationConstants110.o" \
    -framework Foundation -framework CoreMedia -framework AudioToolbox -o "$build/port" > "$build/link.log" 2>&1 || {
        echo "RUN FAILED: the port half did not link - the port reached a member the release does not have"
        head -8 "$build/link.log"; exit 1; }
set +e; "$build/port" > "$build/port.table" 2> "$build/port.stderr"; port_status=$?; set -e

# ---- 3. the HOST half, once. Built without -I standin, so <AVFoundation/AVFoundation.h> is the real one,
#         and linked against this machine's own AVFoundation.
if [ ! -x "$oracle_dir/host" ]; then
    mkdir -p "$oracle_dir"
    # shellcheck disable=SC2086
    xcrun clang $FLAGS "$here/samplerender.m" -framework Foundation -framework AVFoundation -framework CoreMedia -framework AudioToolbox \
        -o "$oracle_dir/host" > "$oracle_dir/build.log" 2>&1 || {
            echo "RUN FAILED: the host half did not build"; head -8 "$oracle_dir/build.log"; exit 1; }
    set +e; "$oracle_dir/host" > "$oracle_dir/host.table" 2> "$oracle_dir/host.stderr"; host_status=$?; set -e
    if [ "$host_status" != 0 ]; then
        echo "RUN FAILED: the host half exited $host_status, which is a control failing and not a result"
        exit 1
    fi
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
        echo "      AVFSRMUTANT first: a mutant is judged against what the port answered unmutated."
        exit 1
    }
fi

# ---- 5. the join, and the value every row must answer
set +e
python3 - "$build" "$oracle_dir" > "$build/join.log" 2>&1 <<'PYEOF'
import json, os, sys
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

# The differences that are in the PORT's build and not in the host's. Each is (the value the PORT is
# required to answer, the measurement behind it) - every one of them states a value, so the directionality
# step can hold a mutation to it even where the two halves deliberately answer differently.
#
# The five media rows are all the same cause, measured on this machine on 2026-10-03: CoreAudio reports the
# hardware not running, so the audio queue is made but has no device clock behind it, and
# -AudioQueueGetCurrentTime - the one call a timestamp needs - answers -66678 with no valid time in it.
# Apple's own renderer has its own decode layer above the output device, so it keeps answering
# AVQueuedSampleBufferRenderingStatusRendering and a nil error for media it has accepted and can never
# play, and this port answers Failed with an error, which is what the header asks for ("If the status is
# AVQueuedSampleBufferRenderingStatusFailed, check the value of the renderer's error property") and the
# only answer that is not a claim about audio that does not exist. Every other row of the media path - the
# one this machine CAN answer - agrees, which is what the summary below counts.
ALLOWANCES = {
 "renderer: status after the first enqueue": ("2",
   "there is no audio device on this machine (CoreAudio answers 'who?' for kAudioHardwarePropertyDevices), so "
   "the queue the port made has no device clock and -AudioQueueGetCurrentTime answers -66678 with no valid "
   "time in it; a renderer that cannot place a buffer at its timestamp answers Failed with an "
   "AVFoundationErrorDomain error, where Apple's own renderer keeps answering Rendering for media it has "
   "accepted and can never play. Measured in packages/a/apple-backports/facts/AVFoundation/SampleBufferRender11.md"),
 "renderer: error after the first enqueue is nil": ("NO", "follows the row above, and the port names the queue's own OSStatus in the description"),
 "renderer: status after nine enqueues": ("2", "follows the first-enqueue row"),
 "renderer: error after nine enqueues is nil": ("NO", "follows the first-enqueue row"),
 "renderer: status after a buffer with no frames": ("2", "follows the first-enqueue row"),
 # The four members the rows answer absent. The port must answer NO to each and Apple's own classes answer
 # YES to each, because their surface is a later one - and the port answering YES is not a difference to be
 # explained but a defect: a synthesised accessor is a name the port claims and does not carry. So these
 # four carry the value the port is REQUIRED to answer, not only a reason.
 "absent: the renderer answers respondsToSelector: for allowedAudioSpatializationFormats": ("NO",
   "the property is 15.0 and the row answers absent; clang synthesises an ivar and both accessors from the "
   "SDK's @interface unless @dynamic says not to, and @dynamic is what makes respondsToSelector: answer NO, "
   "which is the truth. Measured on the object at -target armv7-apple-ios6.0 and armv7-apple-ios4.3."),
 "absent: the renderer answers respondsToSelector: for audioOutputDeviceUniqueID": ("NO",
   "the header declares it API_UNAVAILABLE(ios), so there is no iOS row and the port carries nothing; "
   "@dynamic stops clang synthesising the accessors the @interface would otherwise get it. Apple's own "
   "class answers YES."),
 "absent: the renderer answers respondsToSelector: for hasSufficientMediaDataForReliablePlaybackStart": ("NO",
   "the protocol property at 14.5 needs no @dynamic: a property a protocol declares is not auto-synthesised "
   "(measured: no accessor of that name in any of the four objects, and "
   "-Wobjc-protocol-property-synthesis says so at compile time). Apple's own class answers YES."),
 "absent: the synchronizer answers respondsToSelector: for delaysRateChangeUntilHasSufficientMediaData": ("NO",
   "the property is 14.5 and the row answers absent, because the preroll level it asks about is not "
   "measurable on this machine; @dynamic is what makes respondsToSelector: answer NO. Apple's own class "
   "answers YES."),
 "attached: the renderer's clock reads the synchronizer's clock as its master": ("YES",
   "the port slaves the renderer's own CMTimebase to the synchronizer's, which is what the header's \"Adds a "
   "renderer to begin operating with the synchronizer's timebase\" asks for; this Mac's own renderer "
   "answers nil from CMTimebaseGetMasterTimebase for both clocks and keeps them in step by propagating the "
   "rate instead, which is what its private -_updateRateFromTimebase is for (measured over both classes' "
   "method lists). The two clocks read the same time either way, which is the row beside it"),
}
# Rows that describe the two BUILDS and not the two answers.
BUILD_ROWS = {
 "CONTROL: AVSampleBufferRenderSynchronizer exists": "each half answers for its own build",
 "CONTROL: AVSampleBufferAudioRenderer exists": "each half answers for its own build",
 "CONTROL: the AVQueuedSampleBufferRendering protocol exists":
   "the host carries Apple's own protocol object; the port's comes from the source "
   "modules/apple/backports.lua writes for an implemented protocol row",
 "CONTROL: the renderer answers the protocol's own -timebase": "each half answers for its own build",
}

# What every row must answer: the host's own value, unless an allowance names a value of its own. The
# directionality step reads this file, so a mutation that breaks either kind of required answer is noticed
# even where the two halves deliberately differ.
required = {}
for key, (value, _reason) in ALLOWANCES.items():
    required[key] = value if value is not None else host.get(key)
for key in host:
    required.setdefault(key, host[key])
json.dump(required, open(os.path.join(build, "required.json"), "w"), indent=1)

less = more = unexplained = 0
differing = []
for key in sorted(set(host) | set(port)):
    if key in BUILD_ROWS:
        print("BUILD             %-74s %s" % (key, BUILD_ROWS[key]))
        continue
    if key not in port:
        print("ANSWERS LESS      %s" % key); less += 1
    elif key not in host:
        print("HOST LACKS IT     %s" % key); more += 1
    else:
        # Every row is checked against the value the join REQUIRES, not against the host's: for a must-match
        # row those are the same, and for a row the two halves deliberately answer differently on it is the
        # value the allowance names. A mutation that made the port agree with the host by answering the one
        # thing it must not answer would otherwise read as "no difference", which is the trap this ordering
        # closes.
        want = required.get(key)
        if want is not None and port[key] != want:
            if key in ALLOWANCES:
                print("WRONG ALLOWED     %-74s the port was required to answer [%s] and answers [%s] (the host answers [%s])"
                      % (key, want, port[key], host[key]))
            else:
                print("UNEXPLAINED       %-74s host=[%s] port=[%s]" % (key, host[key], port[key]))
            unexplained += 1
        elif host[key] != port[key]:
            print("ALLOWED           %-74s host=[%s] port=[%s]" % (key, host[key], port[key]))
            differing.append(key)
print("SUMMARY rows: host=%d port=%d  allowed-differences=%d answers-less=%d host-lacks=%d unexplained=%d"
      % (len(host), len(port), len(differing), less, more, unexplained))
sys.exit(1 if (less or more or unexplained) else 0)
PYEOF
join_status=$?
cat "$build/join.log"
set -e

# ---- 6. the directionality assertion, and the control
if [ -n "$want" ] && [ "$control" = 0 ]; then
    set +e
    changed=$(python3 - "$build" "$oracle_dir" <<'PYEOF'
import json, os, sys
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
# every row's required value, written by the join above: the host's own, or the one an allowance names
required = json.load(open(os.path.join(build, "required.json")))
changed, broke_required, closer = [], [], []
for key in set(base) | set(port):
    if base.get(key) == port.get(key):
        continue
    changed.append(key)
    if key in required and base.get(key) == required[key] and port.get(key) != required[key]:
        # The join NAMES the value this row must answer, so breaking it is turning a required answer wrong -
        # whether that value is the host's (a must-match row) or the one an allowance says (a row the two
        # halves deliberately answer differently on).
        broke_required.append(key)
    elif key in host and base.get(key) != host[key] and port.get(key) == host[key]:
        closer.append(key)
for key in sorted(broke_required):
    print("BROKE A REQUIRED ONE  %s" % key)
for key in sorted(closer):
    print("MOVED TOWARD HOST     %s" % key)
for key in sorted(changed):
    print("CHANGED           %-74s before=[%s] after=[%s]" % (key, base.get(key), port.get(key)))
print("DIRECTIONALITY changed=%d broke-a-required-answer=%d moved-toward-host=%d"
      % (len(changed), len(broke_required), len(closer)))
sys.exit(0 if (changed and broke_required) else 1)
PYEOF
)
    dir_status=$?
    set -e
    if [ "$dir_status" != 0 ]; then
        echo "FAIL: the $want mutation was NOT noticed in the required direction: it did not turn a"
        echo "      required answer wrong. A mutation that only moves the port AWAY from a row that already"
        echo "      differed is not a check; it needs a row the join says the port must answer."
        echo "$changed"
        exit 1
    fi
    if [ "$join_status" = 0 ]; then
        echo "FAIL: the $want mutation changed a row the join requires and the join stayed GREEN, so"
        echo "      nothing the check reads was wrong. A mutation must be noticed by the join too."
        exit 1
    fi
    echo "ok  the $want mutation was noticed, turned a required answer wrong, and the join went red:"
    echo "$changed" | grep -E '^(CHANGED|BROKE|MOVED)' | head -14
    echo "$(echo "$changed" | tail -1)"
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
allowed=$(grep -c '^ALLOWED' "$build"/join.log 2>/dev/null || echo "")
echo "ok  every row both halves answer is answered the same, apart from the $(grep -oE 'allowed-differences=[0-9]+' "$build/join.log" | head -1 | cut -d= -f2) this check names, and each of them carries"
echo "    the value the port is required to answer and the measurement behind it"
echo "log=$build"
