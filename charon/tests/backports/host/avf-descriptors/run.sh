#!/bin/sh
# run.sh — the avf-3a descriptor classes, the port against the host.
#
# One program (probe.m) linked twice: plain, where every name is Apple's own, and with the rename list
# and the port's five objects, where the same names are the port's own classes in the same binary.
# The two tables are joined row by row.
#
# Run DIRECTLY, not through heavy.sh: this is a handful of small compiles, and the gate is heavy.sh's
# job for the package builds, not for a probe.
#
# What makes it a check rather than a comparison:
#
#   * a name the port does not define is a LINK ERROR, so a missing class cannot read as "both sides
#     absent and therefore equal" - the failure AVMetadataItemFilter had as a bare category;
#   * the row count is asserted on both sides and against the count this probe emits, so an empty
#     table is a red and not a clean diff of two empty files;
#   * the harness is PLANTED, twice, and this is the part that says the harness works: the probe can
#     corrupt its own answers, and the run must notice. plant-all must go red on every row, plant-one
#     on exactly one. A run that passes while the probe is corrupting every answer is not a check;
#   * a mutation that does not build is RUN FAILED with the compiler's line and exit 1, so a build
#     failure is never counted as a noticed mutation;
#   * the CONTROL runs the unmutated source through the identical build-and-run path and must stay
#     green, so a red mutant is the mutation and not the path.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/a/apple-backports/AVFoundation
# THE ROW COUNT IS NOT TYPED HERE. It used to be, twice, and the two literals did not agree with the
# comment above them: the comment said both sides emit the SAME 49 rows, the assertions said 63, and
# the worktree had by then moved to 71. One export carried all three numbers, and the reviewer's first
# finding was this file contradicting itself. Typing 71 would have made it contradict itself again the
# next time a row was added, so the number is now DERIVED from the run: the probe ends every run with
# "rows: N", and the expectation is what that probe says it emitted on that side.
#
# The two sides stay SEPARATE numbers because they are the two SIDES of one claim - a table that
# silently lost rows on one side would not otherwise be noticed - and the probe asks both builds the
# same questions, so they are expected to match without that being assumed. Some rows have no host
# oracle - the 12.0 initializer, which this host's criteria factory cannot build - and the join holds
# those against the port's own unmutated baseline rather than against the host.
#
# If the probe does not report its own count there is nothing to check against, and this says so and
# stops. It does not fall back to a number, because a fallback is how 49, 63 and 71 got here.
sources="AVPlayerMediaSelectionCriteria7 AVPlayerMediaSelectionCriteria7Members AVCaptureBracket8 AVAssetResourceRenewalRequest8 AVMediaSelection9 "
control=${CONTROL:-0}
break=${BREAK:-0}
mutant=${AVFMUTANT:-0}
build=${AVF_DESC_BUILD:-$root/.agent-work/avf-descriptors-build}
baseline_dir=${AVF_DESC_BASELINE:-$root/.agent-work/avf-descriptors-baseline}
rm -rf "$build"
mkdir -p "$build/src" "$build/o" "$baseline_dir"

renames=""
for name in AVPlayerMediaSelectionCriteria AVCaptureBracketedStillImageSettings \
            AVCaptureAutoExposureBracketedStillImageSettings AVCaptureManualExposureBracketedStillImageSettings \
            AVAssetResourceRenewalRequest AVMediaSelection AVMutableMediaSelection; do
    renames="$renames -D$name=charon_host_$name"
done

for source in $sources; do cp "$avf/$source.m" "$build/src/$source.m"; done

if [ "$mutant" != 0 ] && [ "$control" = 0 ]; then
    if [ "$break" != 0 ]; then
        python3 - "$build/src/AVMediaSelection9.m" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
before = '- (AVAsset *)asset'
if before not in text:
    raise SystemExit("the control did not apply, so this run proves nothing")
open(path, 'w').write(text.replace(before, '- (AVAsset *)this is not C at all'))
PERTURB
    elif [ "$mutant" = criteria ]; then
        # Aimed at a MARKER row, because the hole this fixes was there: the criteria factory is the one
        # scenario the host cannot run here, so its rows carry the marker, and a join that skipped them
        # before comparing hid the port. The plant is in the port's own getter for what it STORES, so the
        # row's value moves and nothing else does.
        #
        # IT READS THE STORED OBJECT, NOT ITSELF. The replacement used to be
        # `[self.charon_preferredLanguages count] ? @[@"PLANTED"] : @[]`, which is a call into the very
        # getter it was substituting for: the probe builds a criteria object through the factory, reads
        # -preferredLanguages, and the process died of unbounded recursion (SIGSEGV) before a single row was
        # written, so this mutant could never have fired and the run said "the port probe did not run" rather
        # than that. A plant has to change the value without changing the shape.
        python3 - "$build/src/AVPlayerMediaSelectionCriteria7.m" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
before = 'return objc_getAssociatedObject(self, "charon.avf.criteria.preferredLanguages") ?: @[];'
after = ('return [objc_getAssociatedObject(self, "charon.avf.criteria.preferredLanguages") count] '
         '? @[@"PLANTED"] : @[];')
if text.count(before) != 1:
    raise SystemExit("the mutant target is not unique (%d matches), so this run proves nothing" % text.count(before))
open(path, "w").write(text.replace(before, after))
print("# the mutation applied: the port's own stored languages, and the row the marker sits on")
PERTURB
    else
        # The mutation is on the ISO the port STORES, not on the number the probe passes: 400 lives in
        # the probe's call site and the source never sees it, so a mutation aimed there would change
        # nothing - which the first aim did, and the "the mutant did not apply" guard said so by name.
        # Doubling what the source stores makes the ISO row differ and no other, which says the
        # mutation reached the member and nothing else.
        python3 - "$build/src/AVCaptureBracket8.m" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
# A unique anchor: the manual factory's own call, not the bare "ISO:iso];" which the apply-guard
# correctly found twice.
before = "exposureDuration:exposureDuration\n                                                        ISO:iso];"
after = "exposureDuration:exposureDuration\n                                                        ISO:iso * 2.0f];"
if before not in text:
    raise SystemExit("the mutant did not apply, so this run proves nothing")
# the apply-guard, both ways: the target was there, and after the change it is GONE. A replacement
# that leaves the original behind would compile, run, and change nothing - which is what the first
# two aims of this mutation did.
if text.count(before) != 1:
    raise SystemExit("the mutant target is not unique (%d matches), so this run proves nothing" % text.count(before))
out = text.replace(before, after)
if out.count(before) != 0 or out.count(after) != 1:
    raise SystemExit("the mutant did not take, so this run proves nothing")
open(path, "w").write(out)
print("# the mutation applied: one target, gone afterwards, one replacement")
PERTURB
    fi
fi

objects=""
for source in $sources; do
    # shellcheck disable=SC2086
    if ! xcrun clang -fobjc-arc -w $renames -I"$avf" -c "$build/src/$source.m" -o "$build/o/$source.o" \
            > "$build/o/$source.log" 2>&1; then
        echo "RUN FAILED: the port's $source.m did not build - a build failure is never a noticed mutation"
        head -8 "$build/o/$source.log"
        exit 1
    fi
    objects="$objects $build/o/$source.o"
done

# 1. the host table
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -I"$avf" "$here/probe.m" -framework Foundation -framework AVFoundation \
    -framework CoreMedia -o "$build/host" > "$build/host.log" 2>&1 || {
        echo "FAIL: the host probe did not build"; head -10 "$build/host.log"; exit 1; }
env -u AVFDESCPROBE "$build/host" > "$build/host.table" 2> "$build/host.stderr" || { echo "FAIL: the host probe did not run"; head -10 "$build/host.stderr"; exit 1; }

# 2. the same probe against the port's own classes
# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w -DCHARON_PORT_BUILD=1 -I"$avf" $renames "$here/probe.m" $objects \
    -framework Foundation -framework AVFoundation -framework CoreMedia \
    -o "$build/port" > "$build/port.log" 2>&1 || {
        echo "FAIL: the port probe did not link - a name the port does not define is a link error"
        head -12 "$build/port.log"
        exit 1
    }
# The plant is given to the PORT build only. Given to both, the two tables are corrupted identically
# and a host-against-port diff sees no difference at all - which is what plant-all did before this
# line: "rows that differ: 0" and a pass, from a probe corrupting every answer on both sides.
if [ -n "${AVFDESCPROBE:-}" ]; then
    AVFDESCPROBE="$AVFDESCPROBE" "$build/port" > "$build/port.table" 2> "$build/port.stderr" || {
        echo "FAIL: the port probe did not run"; head -10 "$build/port.stderr"; exit 1; }
else
    "$build/port" > "$build/port.table" 2> "$build/port.stderr" || { echo "FAIL: the port probe did not run"; head -10 "$build/port.stderr"; exit 1; }
fi

# WHICH CLASSES THE PORT DOES NOT CARRY is READ from the registry below rather than listed here, so the
# eleven names the probe asks about cannot drift away from the rows that record them, and a name the
# registry says nothing about is compared and goes red.
reg=$root/packages/a/apple-backports/registry/AVFoundation
[ -d "$reg" ] || { echo "FAIL: no AVFoundation registry at $reg, so a row about a class the port does not carry cannot be told from a defect"; exit 1; }

# The baseline is the port's own UNMUTATED table, written beside the build directory (which is wiped
# on every run) and read by the join for the port-only rows. A mutant with no baseline beside it is a
# failure: it would be judging a mutation against nothing.
# (4) The baseline is written ONLY on an explicit flag. A plain run used to rewrite the very table it
# then compares against, so every port-only row matched ITSELF and no mutation of one could ever be
# seen - which is why the reviewer's plant on an AVAudioFile value row stayed green. The baseline is
# what a mutant is judged against, so writing it during an ordinary run makes the directionality
# assertion vacuous.
if [ "${AVF_WRITE_BASELINE:-0}" != 0 ]; then
    mkdir -p "$baseline_dir"
    cp "$build/port.table" "$baseline_dir/port.baseline"
    echo "baseline written under AVF_WRITE_BASELINE=1"
elif [ "$mutant" = 0 ] || [ "$control" != 0 ]; then
    # A plain run compares against the baseline and leaves it alone. When there is none it WRITES one
    # and says so, rather than stopping: a fresh worktree has none, and the sweep - which runs every
    # run.sh with no environment of its own - read that as "alive, and it reports failures" on every
    # pass, which is a test that can never be green where it is actually run. Writing it here is not the
    # vacuous thing AVF_WRITE_BASELINE=1 is on the mutant path, because this run IS the unmutated tree:
    # the baseline it writes is what the next run, and every mutant, is judged against, and the run
    # below still compares this very table with it and says so.
    if [ ! -f "$baseline_dir/port.baseline" ]; then
        mkdir -p "$baseline_dir"
        cp "$build/port.table" "$baseline_dir/port.baseline"
        echo "no baseline at $baseline_dir: wrote one from this run's own unmutated port table"
    fi
else
    [ -f "$baseline_dir/port.baseline" ] || {
        echo "FAIL: the mutant was asked for with no baseline beside it. Run this script once with no"
        echo "      AVFMUTANT first: a port-only row is judged against the port's own unmutated table."
        exit 1
    }
fi

# 3. neither table may be smaller than the claim
rows_host=$(sed -n 's/^rows: \([0-9][0-9]*\) .*/\1/p' "$build/host.table" | tail -1)
rows_port=$(sed -n 's/^rows: \([0-9][0-9]*\) .*/\1/p' "$build/port.table" | tail -1)
if [ -z "$rows_host" ] || [ -z "$rows_port" ]; then
    echo "FAIL: the probe did not report how many rows it emitted, so the row count cannot be checked"
    echo "      against the run's own output. Refusing to guess it from a literal."
    exit 1
fi
for side in host port; do
    # ONE ROW PER LINE, and the same rule the join below reads the table with: a line that does not begin with
    # a space. probe.m indents the lines of a value that spans lines, so a line at column 0 is a row, and
    # counting " = " anywhere in a line would also count a continuation line of a value that happens to
    # contain that pair.
    rows=$(grep -c '^[^ ].* = ' "$build/$side.table" || true)
    if [ "$side" = host ]; then want=$rows_host; else want=$rows_port; fi
    if [ "$rows" -ne "$want" ]; then
        echo "FAIL: the $side table has $rows rows but the probe reported emitting $want on that side,"
        echo "      so the diff below would compare something smaller than the claim"
        exit 1
    fi
    # the ~ rows are the port's own values, with no host oracle - they are held against the
    # baseline, not against the host, and the two kinds must not be confused
    portonly=$(grep -c '^~' "$build/$side.table" || true)
    echo "$side: $rows rows, of which $portonly are port-only (~), compared against the baseline"
done

diff -u "$build/host.table" "$build/port.table" > "$build/diff.log" 2>&1 && verdict=differs0 || verdict=differs
# the row count that actually differ, so the plants can be checked against a number and not a feeling
# The two rows where the PORT answers a header-declared member and this host does not. Measured on
# the host: its AVMediaSelection own-method list, read with class_copyMethodList, carries
# -selectedMediaOptionInMediaSelectionGroup: and NOT these two, and asking an INSTANCE for them
# answers no. The 26.2 header declares all three. So the port answers MORE than the host here - the
# direction the policy asks for, and the same situation as the body-object members in the earlier
# slices - and it is an ALLOWANCE with a measured reason, not a failure. Written to a file because the
# python below cannot see a shell variable.
cat > "$build/allowed.tsv" <<'ALLOWED'
AVMediaSelection RESPONDS selectedMediaOptions	the header declares it; this host's own method list for AVMediaSelection carries -selectedMediaOptionInMediaSelectionGroup: and not this, and an instance answers no
AVMediaSelection RESPONDS mediaSelectionGroups	the header declares it; same measurement - the host's own list has the one selector, and an instance answers no to this
ALLOWED

counts=$(python3 - "$build/host.table" "$build/port.table" "$baseline_dir/port.baseline" "$build/rows.log" "$build/allowed.tsv" "$reg" <<'PYEOF'
import json
import os
import sys

NO_ORACLE = "no-oracle-forwarding-object"
# The second marker from the probe: the scenario a row names did not happen on this host, so the row has
# no answer to compare in EITHER direction. It is counted, so it stays visible, and it is NOT counted as a
# difference: the baseline beside this run was written on a host where the scenario did happen, and holding
# this run against it measures the two hosts, not the port. That is the difference between this marker and
# NO_ORACLE, which describes the port.
NOT_ON_THIS_HOST = "scenario-not-applicable-on-this-host"

# WHICH CLASSES THE PORT DOES NOT CARRY, and this is READ, never listed. A row the probe writes under a
# class name is compared against the host unless the registry says the port carries no class of that name,
# and the row that says so travels with the row's own reason: `absent` is a class the release does not have
# and the port does not make one, `ignored` is a class the release carries itself. Eleven class names typed
# into this script is how the list and the tree drift apart without either noticing, and a class the probe
# asks about that the registry says nothing about is excused by nothing at all: it is compared, and it goes
# red.
def not_carried(registry_dir):
    classes = {}
    for name in sorted(os.listdir(registry_dir)):
        if not name.endswith(".json"):
            continue
        for entry in json.load(open(os.path.join(registry_dir, name))).get("entries", []):
            if entry.get("kind") == "class" and entry.get("status") in ("absent", "ignored"):
                classes[entry["api"]] = (entry["status"], entry.get("reason") or "")
    return classes

# WHAT "THE PORT DOES NOT CARRY IT" LOOKS LIKE, per row shape. Every shape is asked for explicitly, and a
# shape this list does not know is NOT excused: the row is compared like any other, so a row of a kind
# nobody wrote a case for fails rather than passing.
def carried_nothing(key, value):
    what = key.split(None, 1)[1] if " " in key else ""
    head = what.split(None, 1)[0] if what else ""
    if head == "PRESENT":
        return value == "NO"
    if head == "SUPERCLASS":
        return value == "(no class)"
    if head in ("ALLOC-INIT", "RESPONDS", "METHOD"):
        return value in ("no", "does not respond")
    return False

def load(path):
    """{row key: value} for a table, and a value MAY SPAN LINES.

    A row is a line that does not begin with a space, because probe.m indents every line of a value that
    describes itself across lines - an NSArray is "(\\n    en\\n)" and that closing bracket sits at column 0,
    which is where a row's key starts. Reading line by line instead, as this did, truncated such a value to
    its first line, so two tables whose arrays held DIFFERENT strings compared equal: the mutant aimed at the
    criteria marker row - the one this harness exists to be able to prove fires - reported "the mutation left
    the tables equal, so this check cannot fail and proves nothing", and the run was green with the port
    storing "PLANTED" beside a baseline that said "en". The same rule is what the row count above uses.
    """
    rows, key, value = {}, None, []
    for line in open(path):
        # The probe's own last line, "rows: N plants: M", is not a row and is not part of the last row's
        # value either. run.sh reads the count off it above; appended to the final row it made two tables
        # whose ROWS agree compare unequal the moment the plant count differs, which is how plant-one
        # reported two differing rows for the one it plants.
        if line.startswith("rows: "):
            break
        if line[:1] not in (" ", "") and " = " in line:
            if key is not None:
                rows[key] = "\n".join(value).strip()
            key, _, first = line.rstrip("\n").partition(" = ")
            key, value = key.strip(), [first.strip()]
        elif key is not None:
            value.append(line.rstrip("\n"))
    if key is not None:
        rows[key] = "\n".join(value).strip()
    return rows

host = load(sys.argv[1])
port = load(sys.argv[2])
base = load(sys.argv[3]) if len(sys.argv) > 3 else {}
unc = not_carried(sys.argv[6]) if len(sys.argv) > 6 and os.path.isdir(sys.argv[6]) else {}
# The differing rows go to a FILE and only the two counts come back on stdout: mixed output here made
# `set --` bind a diagnostic line as the count, and `set -u` then failed on $2.
allowed_more = {}
if len(sys.argv) > 5 and os.path.exists(sys.argv[5]):
    for line in open(sys.argv[5]):
        key, _, reason = line.rstrip("\n").partition("\t")
        if key:
            allowed_more[key] = reason
report = open(sys.argv[4], "w") if len(sys.argv) > 4 else sys.stdout
say = report.write

differs = 0
portonly = 0
inapplicable = 0
allowed = 0        # rows where the port answers a header-declared member and this host does not
notcarried = 0     # rows about a class the registry says the port carries no class of its own for
for k in set(host) | set(port):
    hv, pv, bv = host.get(k), port.get(k), base.get(k)
    # A ~ row is PORT-ONLY: it is about a value the port stores, for which there is no host oracle,
    # so it is held against the port's own unmutated baseline. So is any row either side answers
    # NO_ORACLE for - the class exists and the framework is the oracle, but this instance is a
    # forwarding object, so there is nothing here to read. A ~ row must NEVER read the host side.
    # Tested on the HOST side ALONE, and the branch still compares the port. The marker is the host's:
    # it says the scenario could not happen here, which makes the host-vs-port claim unavailable and
    # nothing else. A `continue` before the pv == bv test is what made a mutation of the port's own value
    # on such a row invisible, and the comment on the allowed branch below already says why that is
    # wrong -- an exemption is about WHAT may differ, not about whether the port's answer is watched.
    if NOT_ON_THIS_HOST in (hv or ""):
        inapplicable += 1
        say("INAPPLICABLE %-64s the scenario did not happen on this host; the port's value is still"
            " compared with its baseline\n" % k)
        if bv is not None and pv == bv:
            continue
        say("PORT-ONLY  %-70s port=[%s] baseline=[%s] host=[%s]\n" % (k, pv, bv, hv))
        differs += 1
        continue
    if k.startswith("~") or NO_ORACLE in ((hv or "") + (pv or "")):
        portonly += 1
        if bv is not None and pv == bv:
            continue            # port-only, and unchanged against the port's own baseline
        say("PORT-ONLY  %-70s port=[%s] baseline=[%s] host=[%s]\n" % (k, pv, bv, hv))
        differs += 1
        continue
    if k in allowed_more:
        # An allowed row is still a row. The exemption is about WHAT may differ between the host and
        # the port, not about whether the port's answer is watched, so this row gets the same baseline
        # test the port-only rows get: unchanged against the port's own unmutated table means nothing
        # is counted, and a change is reported and the run goes red. Without it the exemption
        # `continue`d before any comparison at all, so a mutation of the port's OWN added members -
        # the two this exemption exists for, and the ones the next slice is most likely to touch - was
        # invisible while the run reported itself green.
        if bv is not None and pv == bv:
            allowed += 1
            say("ALLOWED    %-70s host=[%s] port=[%s] unchanged against the baseline - %s\n"
                % (k, hv, pv, allowed_more[k]))
            continue
        say("ALLOWED-BUT-CHANGED %-58s host=[%s] port=[%s] baseline=[%s] - %s\n"
            % (k, hv, pv, bv, allowed_more[k]))
        differs += 1
        continue
    # A CLASS THE PORT DOES NOT CARRY. Both sides were asked the same question and the host has the class while
    # the port answers "not there": that is the port's answer rather than a defect - but only for a class the
    # registry says the port carries no class of its own for, and the row that says so is named. A row the two
    # sides agree on is never routed here, so the exemption's surface is exactly the set of rows that differ.
    # The port's own answer is still held against its baseline, so a change here is reported and the run goes
    # red; and a port that DOES carry the class has to answer the host, which is what carried_nothing()
    # failing on this row means.
    if hv != pv:
        row = unc.get(k.split(None, 1)[0])
        if row is None:
            say("DIFFERS    %-70s host=[%s] port=[%s] baseline=[%s]\n" % (k, hv, pv, bv))
            differs += 1
        elif pv is None or not carried_nothing(k, pv):
            say("CARRIES-IT %-70s host=[%s] port=[%s] - the registry says %s, so the port does not carry this\n"
                "                  class and its answer has to be NO / (no class) / no / does not respond\n"
                % (k, hv, pv, row[0]))
            differs += 1
        elif bv is not None and pv != bv:
            say("CARRIED-ANYWAY %-66s host=[%s] port=[%s] baseline=[%s] - the registry says %s, so the port\n"
                "                  carries no such class and its answer must be the one below\n"
                % (k, hv, pv, bv, row[0]))
            differs += 1
        else:
            notcarried += 1
            say("NOT-CARRIED %-69s host=[%s] port=[%s] - registry says %s: %s\n" % (k, hv, pv, row[0], row[1]))
if report is not sys.stdout:
    report.close()
print("%d %d %d %d %d" % (differs, portonly, allowed, inapplicable, notcarried))
PYEOF
)
set -- $counts
differs_n=$1
portonly_n=$2
allowed_n=$3
inapplicable_n=$4
notcarried_n=$5
[ -s "$build/rows.log" ] && cat "$build/rows.log"
echo "rows that differ: $differs_n   port-only rows (no host oracle, held against the baseline): $portonly_n   allowed (the port answers more): $allowed_n   inapplicable here (the scenario did not happen on this host): $inapplicable_n   not carried (the registry says the port has no such class): $notcarried_n"

if [ "$mutant" != 0 ] && [ "$control" = 0 ]; then
    if [ "$differs_n" = 0 ]; then
        echo "FAIL: the mutation left the tables equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed, on $differs_n row(s):"
    sed -n '1,24p' "$build/diff.log"
    exit 0
fi
if [ "$mutant" != 0 ] && [ "$control" != 0 ]; then
    if [ "$differs_n" != 0 ]; then
        echo "FAIL: the control is not clean: the unmutated source through the identical path"
        echo "      still differs on $differs_n row(s), so the red is the path and not the mutation"
        exit 1
    fi
    echo "ok  the control is clean: the unmutated source through the identical build-and-run path"
    exit 0
fi

if [ "$differs_n" != 0 ]; then
    echo "FAIL: the port's table differs from the host's on $differs_n row(s)"
    cat "$build/diff.log"
    exit 1
fi
echo "ok  every row the host answers, the port answers the same"
log=$build
exit 0
