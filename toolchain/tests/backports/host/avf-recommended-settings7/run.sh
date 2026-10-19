#!/bin/sh
# run.sh - what Apple's own AVFoundation recommends to an asset writer input, measured against a live
# capture on this machine, and what the port recommends for the same live capture. Joined key by key.
#
#     sh tests/backports/host/avf-recommended-settings7/run.sh                     the differential
#     AVFRSMUTANT=<name> ... run.sh                                                a mutant, which must be noticed
#     AVFRSMUTANT=<name> CONTROL=1 ... run.sh                                      its control, which must be green
#
# ONE source, writer.m, compiled twice: plain, against this machine's own AVFoundation and its own
# microphone and camera on a session that is really started - that half is the ORACLE, and it is where
# every expectation comes from - and once more with the port's
# packages/a/apple-backports/AVFoundation/AVCaptureDataOutputRecommendedSettings7.m linked in.
#
# The join is per KEY, not per dictionary. So:
#
#   must match   both halves carry the key and the values agree. A difference is a failure, and there is
#                no ALLOWANCES list here: the port's answers are the host's answers for the same live
#                input, and a difference would mean one of the two is wrong.
#   port only    the port carries a key the host does not. Always a failure. This is the shape the
#                left-over band's fourth key took - AVEncoderBitRateKey of `channels * 64000` - and the
#                `bitrate` mutant puts it back to prove the check notices.
#   host only    the host carries a key the port does not. Always a failure: a value the caller needs
#                that the port does not answer.
#
# **Directionality.** The check is not "nothing differs" but "a mutation must turn a RIGHT answer wrong".
# A mutant run is judged against the port's own unmutated table and must show all three of: a key whose
# value CHANGED or appeared or went, a change on a key that was RIGHT (it matched the host before the
# mutation and does not after), and a red verdict overall. A control runs each mutant's UNMUTATED source
# through the identical build-and-run path and must stay green, so a red mutant is the mutation and not
# the path.
#
# The host half needs a capture device and starts a real session, so it is built ONCE and its table
# cached BESIDE the build directory: a baseline inside a directory every run removes is no baseline.
#
# Not run through heavy.sh: it compiles two small files, links two binaries and runs them against a live
# capture, and the fleet's heavy lane is for the gate.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
port=$root/packages/a/apple-backports/AVFoundation/AVCaptureDataOutputRecommendedSettings7.m
build=${AVFRS_BUILD:-$root/.agent-work/runs/avf-recommended-settings7}
oracle_dir=${AVFRS_ORACLE:-$root/.agent-work/runs/avf-recommended-settings7-oracle}
rm -rf "$build"
mkdir -p "$build/src"

FLAGS="-fobjc-arc -w"

mutate() {
    python3 - "$1" "$2" <<'PY'
import sys
path, which = sys.argv[1], sys.argv[2]
text = open(path).read()
MUTATIONS = {
    # THE LEFT-OVER'S FOURTH KEY. Its dictionary answered channels * 64000 with nothing behind it, and
    # Apple's own answer for the same live input carries no bit rate at all - so this key on the port side
    # and not on the host side is what the check must notice.
    "bitrate": ("""        AVSampleRateKey: @(asbd->mSampleRate),
    };""",
                """        AVSampleRateKey: @(asbd->mSampleRate),
        AVEncoderBitRateKey: @(asbd->mChannelsPerFrame * 64000),
    };"""),
    # the sample rate read off the live format, replaced by a number written in the source
    "hardcoded": ("AVSampleRateKey: @(asbd->mSampleRate),", "AVSampleRateKey: @(44100),"),
    # the codec taken from the release's own -availableVideoCodecTypes: last entry instead of the first
    # (the measured list here is avc1,jpeg, and the recommendation answers the FIRST)
    "lastcodec": ("NSString *codec = self.availableVideoCodecTypes.firstObject;",
                  "NSString *codec = self.availableVideoCodecTypes.lastObject;"),
    # the frame size read off the live format, transposed
    "swapdims": ("""        AVVideoWidthKey: @(size.width),
        AVVideoHeightKey: @(size.height),""",
                 """        AVVideoWidthKey: @(size.height),
        AVVideoHeightKey: @(size.width),"""),
    # the check that there is a live format at all, answered with invented numbers instead of nil: this is
    # the left-over's shape for the audio case (a made-up 44100 Hz mono for an output attached to
    # nothing), and the unattached rows are where it shows.
    "nilwhenempty": ("""    if (!asbd || asbd->mChannelsPerFrame == 0 || asbd->mSampleRate <= 0)
        return nil;""",
                     """    if (!asbd || asbd->mChannelsPerFrame == 0 || asbd->mSampleRate <= 0)
        return @{AVFormatIDKey: @(kAudioFormatMPEG4AAC), AVNumberOfChannelsKey: @(1), AVSampleRateKey: @(44100)};"""),
}
before, after = MUTATIONS[which]
if before not in text:
    raise SystemExit("the %s mutation did not apply, so this run proves nothing" % which)
open(path, "w").write(text.replace(before, after, 1))
print("# applied the %s mutation" % which)
PY
}

want=${AVFRSMUTANT:-}
control=${CONTROL:-0}

mkdir -p "$build/src"
cp "$port" "$build/src/port.m"
if [ "$control" = 0 ] && [ -n "$want" ]; then
    case "$want" in
        bitrate|hardcoded|lastcodec|swapdims|nilwhenempty) mutate "$build/src/port.m" "$want" ;;
        *) echo "FAIL: no such mutant: $want"; exit 1 ;;
    esac
fi

# ---- 1. the PORT half: the port's own object, and the SAME source compiled with -DCHARN_PORT_HALF=1 so
#         each call reaches the port's implementation. See writer.m for why that is an IMP and not a
#         message send: the concrete class of a capture output here is a framework subclass.
# shellcheck disable=SC2086
xcrun clang $FLAGS -c "$build/src/port.m" -o "$build/port.o" > "$build/port.log" 2>&1 || {
    echo "RUN FAILED: the port's own file did not build"; head -8 "$build/port.log"; exit 1; }
# shellcheck disable=SC2086
xcrun clang $FLAGS -DCHARN_PORT_HALF=1 "$here/writer.m" "$build/port.o" -framework Foundation \
    -framework AVFoundation -framework CoreMedia -o "$build/port" > "$build/link.log" 2>&1 || {
        echo "RUN FAILED: the port half did not link"; head -8 "$build/link.log"; exit 1; }
set +e; "$build/port" > "$build/port.table" 2> "$build/port.stderr"; port_status=$?; set -e
# The port half is only a measurement of the port if the two halves really are asking two different
# implementations, and a run that cannot show that says so instead of passing.
port_imp=$(grep '^CONTROL audio class IMP' "$build/port.table" | sed 's/.*| //')
sent_imp=$(grep '^CONTROL audio dispatched IMP' "$build/port.table" | sed 's/.*| //')
if [ "$port_imp" = "$sent_imp" ]; then
    echo "FAIL: the port half's class IMP and its dispatched IMP are the same pointer ($sent_imp), so the"
    echo "      category was never reached and nothing below measured the port."
    exit 1
fi

# ---- 2. the HOST half, once. Built and run only when the cache is empty.
if [ ! -x "$oracle_dir/host" ]; then
    mkdir -p "$oracle_dir"
    # shellcheck disable=SC2086
    xcrun clang $FLAGS -DCHARN_PORT_HALF=0 "$here/writer.m" -framework Foundation -framework AVFoundation -framework CoreMedia \
        -o "$oracle_dir/host" > "$oracle_dir/build.log" 2>&1 || {
            echo "RUN FAILED: the host half did not build"; head -8 "$oracle_dir/build.log"; exit 1; }
    set +e; "$oracle_dir/host" > "$oracle_dir/host.table" 2> "$oracle_dir/host.stderr"; host_status=$?; set -e
    if [ "$host_status" != 0 ]; then
        echo "RUN FAILED: the host half exited $host_status, which is a control failing and not a result"
        exit 1
    fi
    grep -q 'CONTROL audio device | ' "$oracle_dir/host.table" || {
        echo "RUN FAILED: the host half printed no control, so nothing below was measured"; exit 1; }
    grep -q '^audio: live format present | YES' "$oracle_dir/host.table" || {
        echo "RUN FAILED: no live audio format was read, so the audio rows would measure nothing"; exit 1; }
    grep -q '^video: live format present | YES' "$oracle_dir/host.table" || {
        echo "RUN FAILED: no live video format was read, so the video rows would measure nothing"; exit 1; }
fi
cp "$oracle_dir/host.table" "$build/host.table"

# ---- 3. the baseline: the PORT's own table, written on an unmutated run and read by a mutant run.
if [ -z "$want" ] || [ "$control" != 0 ]; then
    mkdir -p "$oracle_dir"
    cp "$build/port.table" "$oracle_dir/port.baseline"
else
    [ -f "$oracle_dir/port.baseline" ] || {
        echo "FAIL: the mutant was asked for with no baseline beside it. Run this script once with no"
        echo "      AVFRSMUTANT first: a mutant is judged against what the port answered unmutated."
        exit 1
    }
fi

# ---- 4. the join and the verdict
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
base = load(os.path.join(oracle_dir, "port.baseline"))

# The rows that describe the two RUNS rather than the two answers: the devices this machine has and the
# row count. Both halves print them and both must agree, but a difference in the device names would not be
# a difference in what either half recommends.
RUN_ROWS = ("CONTROL audio device", "CONTROL video device", "rows",
            "CONTROL concrete audio output class", "CONTROL concrete video output class",
            "CONTROL audio dispatched IMP", "CONTROL video dispatched IMP",
            "CONTROL audio class IMP", "CONTROL video class IMP")

port_only = host_only = unequal = 0
unexplained = []
for key in sorted(set(host) | set(port)):
    if key in RUN_ROWS:
        continue
    if key not in port:
        print("HOST ONLY        %-52s host=[%s]" % (key, host[key])); host_only += 1
    elif key not in host:
        print("PORT ONLY        %-52s port=[%s]" % (key, port[key])); port_only += 1
    elif host[key] != port[key]:
        unequal += 1
        print("UNEXPLAINED      %-52s host=[%s] port=[%s]" % (key, host[key], port[key]))
        unexplained.append(key)
print("SUMMARY keys: host=%d port=%d  must-match-unequal=%d port-only=%d host-only=%d"
      % (len(host), len(port), unequal, port_only, host_only))
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
    # the key was RIGHT: the host answered it and the port answered the same before the mutation
    if key in host and base.get(key) == host[key]:
        right_then_wrong.append(key)
for key in sorted(right_then_wrong):
    print("BROKE A RIGHT ONE  %-52s was=[%s] now=[%s]" % (key, base.get(key), port.get(key)))
for key in sorted(changed):
    print("CHANGED           %-52s before=[%s] after=[%s]" % (key, base.get(key), port.get(key)))
print("DIRECTIONALITY changed=%d right-then-wrong=%d" % (len(changed), len(right_then_wrong)))
sys.exit(0 if (changed and right_then_wrong) else 1)
PYEOF
)
    dir_status=$?
    set -e
    if [ "$dir_status" != 0 ]; then
        echo "FAIL: the $want mutation was NOT noticed in the required direction: it did not turn a right"
        echo "      answer wrong. A key the port did not carry at all counts only when the host carries it."
        echo "$changed"
        exit 1
    fi
    if [ "$join_status" = 0 ]; then
        echo "FAIL: the $want mutation changed a key that matched the host and the join stayed GREEN, so"
        echo "      nothing the check reads was wrong."
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
echo "ok  every key Apple's own recommendation carries for this live input is answered the same by the"
echo "    port, with no key on one side only"
echo "log=$build"