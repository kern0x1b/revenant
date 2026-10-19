#!/bin/sh
# run.sh - is this port's MPSGraph the same arithmetic as the system's own?
#
# graph-cases.m is compiled twice: once against the system's own MPSGraph, and once against this port's
# classes with the MPSGraph names mapped to Charon names and their selectors prefixed, so the port's
# implementations are reached under names of their own and cannot replace the system's. Each of the two is
# run ONCE PER FAMILY, one process each, and every case prints the bytes of a buffer the case owns, so the
# two runs of a family are compared exactly.
#
# A family is a process because the release makes it necessary, and the measurement is written down in
# facts/MetalPerformanceShadersGraph/Core.md: in a process that holds three hundred graphs the release's own
# gather operations start asserting partway through the family - "Error: NDArray dimension length > INT_MAX"
# (MPSNDArray.mm:831) over a flatten of a 2x4 that answers in a program of its own - and every FED gather
# parameter takes the process down whatever else it holds. So each family is run, compared and judged on
# its own, and the check of the recorded cells is scoped to the cases that family actually ran: a cell
# another family recorded is not in these two runs, and reading it here would report a divergence that has
# gone away.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
graph=${GRAPH:-$here/../../../../packages/a/apple-backports/MetalPerformanceShadersGraph}
build=${BUILD:-$(runs_fresh charon-mpsgraph)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-macos13.0 -isysroot $sdk"
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-unguarded-availability -Wno-incomplete-implementation -Wno-nullability-completeness -Wno-objc-protocol-method-implementation"
mkdir -p "$build"

# The families this differential runs, and for each the number of case lines the PORT is expected to have
# beyond the release's. It is 1 for "misc" alone, which holds the one case the host of this machine cannot
# answer at all - -[MPSGraph constantWithShape:dataType:values:name:] aborts it - so the port's extra lines
# must be that case and nothing else. Every other family holds nothing the host cannot answer, so a family
# whose two counts differ is a failure and the message names the case either side last reached. A family
# named here and not in graph-cases.m, or the other way round, is a family that silently stops being run, so
# the list below is read back off the case file below and the two are compared.
families="
misc:1
arithmetic:0
reduction:0
reduction_rest:0
cumulative:0
gather_transpose:0
gather_slice:0
gather_slice_rest:0
gather_padtile:0
run_forms:0
gather_reshape:0
gather_flatten:0
gather_broadcast:0
gather_reverse:0
gather_squeeze:0
gather_expand:0
gather_concat:0
gather_split:0
gather_spacebatch:0
gather_nonzero:0
"

xcrun clang -fobjc-arc $target $quiet "$here/graph-cases.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -framework MetalPerformanceShadersGraph -o "$build/system"
# refusals.m is the host's own MPSGraph and nothing of this port's: it asks the questions a case cannot ask,
# because several of them take the release down, and it is asked against the SYSTEM framework on purpose - what
# is being recorded is what the release does, so that the rows of the methods whose parameter is fed and the
# rows of the ones the port refuses carry a measurement a later reader re-runs rather than a line of prose.
xcrun clang -fobjc-arc $target $quiet "$here/refusals.m" \
    -framework Foundation -framework Metal -framework MetalPerformanceShadersGraph -o "$build/refusals"

# The names this library carries, each under a name of its own.
python3 - "$graph" "$build/rename.h" <<'PY'
import os, re, sys
names = set()
for entry in sorted(os.listdir(sys.argv[1])):
    if not entry.endswith('.m'):
        continue
    for line in open(os.path.join(sys.argv[1], entry), errors='ignore'):
        m = re.match(r'@implementation\s+(\w+)', line)
        if m and m.group(1).startswith('MPSGraph'):
            names.add(m.group(1))
with open(sys.argv[2], 'w') as out:
    for name in sorted(names):
        out.write("#define %s Charon%s\n" % (name, name))
PY
echo "renamed: $(grep -c define "$build/rename.h") classes"

printf '#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>\n#import "CharonMPSGraph.h"\n' > "$build/declarations.h"
# The plant has to reach the objects, not only the case file. CharonMPSStore in ../MetalPerformanceShaders/
# CharonMPS.h is where CHARON_PLANT is compiled in, and it is on the way out of every element the graph's
# interpreter writes, so a planted build has to be compiled with the flag like any other source: passed on
# the case file's line alone it would arm nothing and both builds would print the same correct bytes.
# Each build gets its own object directory, so a planted object cannot be handed back to the plain run.
build_objects() {
    _plant=$1
    _objdir="$build/obj-p$_plant"
    rm -rf "$_objdir"
    mkdir -p "$_objdir"
    _objects=""
    for source in "$graph"/*.m; do
        _s=$(basename "$source" .m)
        xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -DCHARON_PLANT=$_plant \
            -c "$source" -o "$_objdir/$_s.plain.o"
        python3 "$here/../prefix_selectors.py" "$source" "$_objdir/$_s.m" ccharonHost_ \
            --declarations="$build/declarations.h" -fobjc-arc $target $quiet -DCHARON_PLANT=$_plant \
            -I"$graph" -include "$build/rename.h" -- "$_objdir/$_s.plain.o"
        xcrun clang -fobjc-arc -fvisibility=hidden $target $quiet -DCHARON_PLANT=$_plant \
            -I"$graph" -include "$build/rename.h" \
            -include "$build/declarations.h" -c "$_objdir/$_s.m" -o "$_objdir/$_s.o"
        _objects="$_objects $_objdir/$_s.o"
    done
    echo "$_objects"
}
objects=$(build_objects 0)
echo "compiled: $(echo "$objects" | wc -w) objects"

xcrun clang -fobjc-arc $target $quiet -include "$build/rename.h" "$here/graph-cases.m" $objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -framework MetalPerformanceShadersGraph -o "$build/port"
# The red control: the same sources with every stored element off by one. It exists because a comparison
# that cannot see a wrong kernel is not a comparison, and this file's own history is the reason - the
# verdict line it printed for a year could not be told apart from a test nobody ran.
plant_objects=$(build_objects 1)
xcrun clang -fobjc-arc $target $quiet -include "$build/rename.h" "$here/graph-cases.m" $plant_objects \
    -framework Foundation -framework Metal -framework MetalPerformanceShaders -framework MetalPerformanceShadersGraph -o "$build/port-plant1"
echo "compiled: $(echo "$plant_objects" | wc -w) objects, planted"

# The two lists are read against each other, so a family added to one of the two files and not the other is
# a failure here rather than a family that quietly stops being compared.
declared=$(for entry in $families; do printf '%s\n' "${entry%%:*}"; done | sort | tr '\n' ' ')
incase=$(sed -n '/^static const Family kFamilies\[\]/,/^};/p' "$here/graph-cases.m" \
    | sed -n 's/^ *{ "\([A-Za-z_]*\)",.*/\1/p' | sort | tr '\n' ' ')
if [ "$declared" != "$incase" ]; then
    echo "FAILED: run.sh runs [$declared] and graph-cases.m declares [$incase]"
    exit 1
fi
echo "families: $declared"

failed=0
for entry in $families; do
    family=${entry%:*}
    extra=${entry#*:}
    echo
    echo "== $family"
    for side in system port port-plant1; do
        set +e
        "$build/$side" "$family" > "$build/$side.$family.raw" 2> "$build/$side.$family.err"
        echo $? > "$build/$side.$family.status"
        set -e
        # Only the lines the case file marks are cases; the framework's own diagnostics share the stream.
        grep -a '^#case ' "$build/$side.$family.raw" > "$build/$side.$family.txt" || true
    done
    n=$(wc -l < "$build/system.$family.txt" | tr -d ' ')
    m=$(wc -l < "$build/port.$family.txt" | tr -d ' ')
    if [ "$n" -eq 0 ]; then
        echo "FAILED: the host answered no case of this family (exit $(cat "$build/system.$family.status"))"
        tail -3 "$build/system.$family.err" | sed 's/^/  host: /'
        failed=1
        continue
    fi
    if [ "$m" -ne "$((n + extra))" ]; then
        echo "FAILED: the two runs produced different numbers of cases: host $n, port $m, and only $extra is expected to be extra"
        echo "  the last case either side reached:"
        echo "    host: $(tail -1 "$build/system.$family.txt" | cut -d' ' -f2-4)"
        echo "    port: $(tail -1 "$build/port.$family.txt" | cut -d' ' -f2-4)"
        failed=1
        continue
    fi
    # Every family ends with the chain, so a family whose last case is not it is a family whose process
    # did not reach the end - the release's own assertions stop the process and print nothing, and a
    # shorter run of a family that lost cases to that is exactly what must not read as agreement.
    last=$(tail -1 "$build/system.$family.txt" | cut -d' ' -f2)
    if [ "$last" != chain ]; then
        echo "FAILED: the host's last case of this family is '$last' and not the chain every family ends with"
        tail -3 "$build/system.$family.err" | sed 's/^/  host: /'
        failed=1
        continue
    fi
    echo "compared: $n cases (port $m, the host cannot answer $extra of them)"
    echo "exit status: host $(cat "$build/system.$family.status"), port $(cat "$build/port.$family.status"), planted $(cat "$build/port-plant1.$family.status")"
    head -n "$n" "$build/system.$family.txt" > "$build/system.$family.prefix"
    head -n "$n" "$build/port.$family.txt" > "$build/port.$family.prefix"
    head -n "$n" "$build/port-plant1.$family.txt" > "$build/port-plant1.$family.prefix"
    # The red control, judged against the same oracle rather than trusted: a plant the comparison cannot
    # see is a comparison that would pass a wrong port, and this file's verdict line was unreadable to the
    # sweep for a year for a reason of the same family.
    if cmp -s "$build/port.$family.prefix" "$build/port-plant1.$family.prefix"; then
        echo "FAILED: the red control did not fire: the planted build printed exactly what the plain build printed"
        failed=1
        continue
    fi
    plant_wrong=$(diff "$build/system.$family.prefix" "$build/port-plant1.$family.prefix" | grep '^<' | wc -l | tr -d ' ')
    echo "red control: the planted build differs from the release in $plant_wrong of $n cases"
    # The verdict, cell by cell. Every cell of every case is compared, and a difference is a failure unless
    # the cell is in recorded-cells.txt WITH the two sets of bytes the release and the port answer there, or
    # the two answers of that cell are within the figure tolerances.txt gives for that operation in that data
    # type.
    #
    # Neither file is an allowance. recorded-cells.txt names no data type, no operation and no element count,
    # and a cell on it whose bytes are not the two written there fails as surely as one that is not on it at
    # all. tolerances.txt names an operation and a data type and a number of units in the last place, and a
    # cell outside that number fails; a case not on it is compared byte for byte, which is every case that is
    # not one of the transcendentals, so a predicate, a logical, a remainder or a rounding has no tolerance
    # at all. What each recorded group is, and the rule attempted and rejected for it, and where each
    # tolerance is written down, is in facts/MetalPerformanceShadersGraph/Core.md.
    #
    # The family is the fifth argument: a recorded cell of an operation this family did not run is not
    # compared here at all, because it is not in either of the two runs, and it is checked in the family
    # that does run it.
    set +e
    python3 - "$build/system.$family.prefix" "$build/port.$family.prefix" "$here/recorded-cells.txt" \
        "$here/tolerances.txt" "$family" <<'PY'
import sys
recorded = {}
for number, line in enumerate(open(sys.argv[3]), 1):
    if line.startswith("#") or not line.strip():
        continue
    fields = line.split()
    if len(fields) != 5:
        print("recorded-cells.txt line %d is not five fields:" % number, line.strip())
        raise SystemExit(1)
    recorded[(fields[0], fields[1], int(fields[2]))] = (fields[3], fields[4])
# How many units in the last place two answers of one data type may differ and still be the same answer,
# per case. Zero everywhere but the transcendental family, and there it is Metal's own documented figure
# for that function, which is the whole of what "the same arithmetic" can mean for a kernel that is not
# the C library's: tolerances.txt carries the number and where it is written down.
tolerances = {}
for number, line in enumerate(open(sys.argv[4]), 1):
    if line.startswith("#") or not line.strip():
        continue
    fields = line.split()
    if len(fields) != 3:
        print("tolerances.txt line %d is not three fields:" % number, line.strip())
        raise SystemExit(1)
    tolerances[(fields[0], fields[1])] = int(fields[2])

# The distance between two answers of a floating point type, in units in the last place: the bit patterns
# read as signed integers in sign-magnitude order, so the distance is how many representable values lie
# between them. A zero of either sign is the same value and the distance is zero; two NaNs are the same
# answer whatever their payloads; a NaN against a number is no distance at all and fails.
def value_of(pattern):
    # The bytes are written in the order the buffer holds them and an x86 buffer is little-endian, so the
    # number is those bytes the other way round.
    return int(bytes.fromhex(pattern)[::-1].hex(), 16)

def monotone(pattern):
    # How many representable values lie between two answers: the bit patterns read as signed integers in
    # sign-magnitude order, so +0 is 0, every positive value is its own pattern and every negative one is
    # the negation of its magnitude, and the distance is the difference of those.
    value = value_of(pattern)
    sign, magnitude = value >> (len(pattern) * 4 - 1), value & ((1 << (len(pattern) * 4 - 1)) - 1)
    return -magnitude if sign else magnitude

def is_nan(pattern):
    # The exponent all ones and the mantissa not zero, read off the number and not off the printed bytes.
    value = value_of(pattern)
    if len(pattern) == 4:
        return value & 0x7C00 == 0x7C00 and value & 0x03FF != 0
    return value & 0x7F800000 == 0x7F800000 and value & 0x007FFFFF != 0

def is_zero(pattern):
    return value_of(pattern) & ((1 << (len(pattern) * 4 - 1)) - 1) == 0

def distance(one, other, width):
    if is_nan(one) and is_nan(other):
        return 0
    if is_nan(one) or is_nan(other):
        return None
    # A zero of either sign is the same value, as IEEE has it: a kernel that answers +0 where the port
    # answers -0 is not off by an ulp and not off by half of one.
    if is_zero(one) and is_zero(other):
        return 0
    return abs(monotone(one) - monotone(other))

# Which operation and data type this run actually holds, so that a recorded cell of another family is
# neither counted as seen nor reported as a divergence that has gone away.
ran = set()
for line in open(sys.argv[1]):
    fields = line.split()
    if len(fields) >= 5:
        ran.add((fields[1], fields[2]))

hard, seen, differing, checked, cells = [], set(), set(), 0, 0
for one, other in zip(open(sys.argv[1]), open(sys.argv[2])):
    a, b = one.split(), other.split()
    # Five fields is a case with a result buffer in it: the marker, the operation, the data type, the
    # length and the bytes. Anything shorter is a line of its own - the graph device type, a shaped type
    # data type - and it is compared as the whole line it is.
    if len(a) < 5 or len(b) < 5 or a[1] != b[1]:
        if one != other:
            hard.append(" ".join(a))
        continue
    checked += 1
    # How many hex characters one element of this data type is: two per byte, and the bytes of the
    # types this file asks for. A predicate's result is a boolean - MPSSizeofMPSDataType(MPSDataTypeBool)
    # is 1, measured - and the case names carry that as "bool-from-<the operand's type>", so a boolean
    # cell is one byte and is compared like any other.
    # The width is in hex characters, because the bytes are written in the order the buffer holds them and
    # that is the order this reads. A float32 is 8 of them, a float16 four, an int32 eight, a boolean two.
    width = {"float32": 8, "float16": 4, "int32": 8}.get(a[2], 2 if a[2].startswith("bool") else 8)
    count = int(a[3]) * 2 // width
    cells += count
    allowed = tolerances.get((a[1], a[2]), 0)
    for i in range(count):
        key = (a[1], a[2], i)
        release = a[4][i * width:(i + 1) * width]
        mine = b[4][i * width:(i + 1) * width]
        want = (release, mine)
        listed = recorded.get(key)
        if want[0] == want[1]:
            if listed is not None:
                hard.append("%s %s element %d is on recorded-cells.txt and the two now agree" % key)
            continue
        # A boolean or an integer answer has no tolerance: it is one bit of truth or a whole number, and
        # "within N units in the last place" is not a thing for either. So the tolerance is read only for
        # the two floating point types, and a case of another type that differs is a failure.
        if allowed and a[2] in ("float32", "float16"):
            how_far = distance(release, mine, width)
            if how_far is not None and how_far <= allowed:
                continue
        differing.add(key)
        if listed is None:
            hard.append("%s %s element %d: release %s, port %s, and it is neither within %d ulp nor recorded"
                        % (key[0], key[1], key[2], want[0], want[1], allowed))
        elif listed != want:
            hard.append("%s %s element %d is recorded as release %s and port %s and answered %s and %s"
                        % (key[0], key[1], key[2], listed[0], listed[1], want[0], want[1]))
        else:
            seen.add(key)
for key, value in sorted(recorded.items()):
    if (key[0], key[1]) not in ran:
        continue
    if key not in differing:
        hard.append("%s %s element %d is recorded as release %s and port %s and the two now agree"
                    % (key[0], key[1], key[2], value[0], value[1]))
print("%s: same as the system on %d of the %d cells with a result buffer; %d within the release's own "
      "precision, %d recorded" % (sys.argv[5], cells - len(seen), cells, cells - len(seen) - len(differing), len(seen)))
for name in hard:
    print("  DIFFERS:", name)
print("checks=%d failures=%d recorded=%d" % (checked, len(hard), len(seen)))
raise SystemExit(1 if hard else 0)
PY
    verdict=$?
    set -e
    if [ "$verdict" -ne 0 ]; then
        failed=1
    fi
done

# The questions a case cannot ask. refusals.txt names the exit status each one is measured to have and the
# text its own diagnostic has to carry, or the shape it answers where it answers at all; neither is an
# allowance, because a question whose answer changed is a question this file no longer describes, and the two
# lists - the file's own and refusals.txt's - are read against each other so that a question added to one and
# not the other is a failure rather than a question nobody asks.
echo
echo "== refusals"
asked=$("$build/refusals" 2>&1 >/dev/null || true)
asked=$(printf '%s\n' "$asked" | sed 's/^name the question; these are: //')
listed=$(grep -v '^#' "$here/refusals.txt" | grep -v '^$' | cut -d' ' -f1 | sort | tr '\n' ' ')
infile=$(printf '%s\n' "$asked" | tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ')
if [ "$listed" != "$infile" ]; then
    echo "FAILED: refusals.txt asks [$listed] and refusals.m declares [$infile]"
    failed=1
else
    questions=0
    while read -r question status what; do
        case "$question" in ''|'#'*) continue ;; esac
        questions=$((questions + 1))
        set +e
        "$build/refusals" "$question" > "$build/refusal.out" 2> "$build/refusal.err"
        got=$?
        set -e
        if [ "$got" -ne "$status" ]; then
            echo "FAILED: $question exited $got and refusals.txt says $status"
            failed=1
            continue
        fi
        if [ "$what" = "-" ]; then
            # A process that is gone writes nothing this file can match, so what is checked is that it wrote
            # nothing at all: a framework that started explaining itself here would be a new answer.
            if [ -s "$build/refusal.err" ]; then
                echo "FAILED: $question is expected to die without a word and wrote: $(head -1 "$build/refusal.err")"
                failed=1
                continue
            fi
        elif ! grep -aqF -e "$what" "$build/refusal.out" "$build/refusal.err"; then
            echo "FAILED: $question is measured to carry '$what' and does not: $(tail -1 "$build/refusal.err" | cut -c1-160)"
            failed=1
            continue
        fi
        echo "  $question: exit $status, $what"
    done < "$here/refusals.txt"
    echo "compared: $questions questions of the release's own refusal and fed forms"
fi

echo
if [ "$failed" -ne 0 ]; then
    echo "mpsgraph: FAILED"
    exit 1
fi
echo "mpsgraph: every family compared, the red control fired in each, and every refusal answered as measured"
