#!/bin/sh
# run.sh -- the AVFoundation constants the port carries, the port against the host, in one binary.
#
# One program. probe.m is compiled plain, so every BARE name in it is Apple's own symbol; the port's
# five AVFoundationGlobals*.m are compiled with every constant name defined to its `revenant_host_`
# spelling and linked beside it, so the PREFIXED name is the port's own definition of the same
# constant. One process then reads both and prints them side by side, and the join below is a
# comparison of the two columns of one run rather than of two runs that could have drifted.
#
# A value the port invented cannot agree with the host's, which is the whole point: these are 116
# constants whose value is a fact about Apple's own image, and "a constant with an invented value" is a
# silent fake the tree forbids.
#
# Run DIRECTLY, not through heavy.sh: this is five small compiles and one run, and heavy.sh's job is the
# package builds.
#
# What makes it a check rather than a comparison:
#
#   * the names are READ from the port's own sources, never typed here, so the check cannot drift away
#     from what the port defines, and a name a source defines that the check does not ask about is
#     reported;
#   * the row count is DERIVED from the run ("names read: N rows: M") and compared against what the
#     sources hold, so an empty table is a red and not a clean diff of two empty files;
#   * the probe prints four controls and this script requires each to be what it must be, so a run that
#     loaded nothing cannot pass;
#   * the harness is PLANTED and the plant must go red: one value in one source is changed, and the run
#     must notice it. A check that cannot fail proves nothing. CONTROL=1 puts the unmutated sources
#     through the identical path and must stay clean, so a red is the mutation and not the path;
#   * a mutation that does not build is RUN FAILED with the compiler's own lines, so a build failure is
#     never counted as a noticed mutation.
set -eu
echo "FAIL host/avf-globals/run.sh: its Python steps are gone and not yet ported to Lua: the inline block PERTURB at line 96; the inline block PERTURB at line 305; the inline block GETTERS at line 446; the inline block LISTEOF at line 492; the inline block PROLOGUE at line 533; the inline block PERTURB at line 600; the inline block PERTURB at line 685; the inline block CONTROLSLIST at line 884; the inline block CONTROLSPROTO at line 941; the inline block CONTROLSPROLOGUE at line 960; the inline block CONTROLSPROTOC at line 1006; the inline block CONTROLSCOPY at line 1042; the inline block PERTURB at line 1087" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
avf=$root/packages/frameworks/apple-backports/AVFoundation
# the generated protocol header (tools/gen writes it into .gen/AVFoundation/ on gen --all)
avf_gen=$root/packages/frameworks/apple-backports/.gen/AVFoundation
control=${CONTROL:-0}
# WHICH MUTATION, because one variable drove both phases and the first phase reported its verdict and
# exited before the second was ever reached: AVFGLOBALSMUTANT=function planted the returned string and
# then the constant plant fired first and the run stopped. So the value names the target.
mutant=${AVFGLOBALSMUTANT:-0}
kind=constant
[ "$mutant" = function ] && kind=function
[ "$mutant" = metrics ] && kind=metrics
[ "$mutant" = coding ] && kind=coding
[ "$mutant" = controls ] && kind=controls
build=${AVF_GLOBALS_BUILD:-$(runs_folder avf-globals-build)}
rm -rf "$build"
mkdir -p "$build/src" "$build/o"

sources=$(cd "$avf" && ls AVFoundationGlobals*.m)
[ -n "$sources" ] || { echo "FAIL: no AVFoundationGlobals*.m under $avf, so there is nothing to check"; exit 1; }

# THE NAMES COME FROM THE SOURCES. Every `NSString *const <name> = ` line the five objects hold, read
# with grep, and nothing is typed into this script: a typed list of 116 names is a list that goes stale
# the moment a row is added, and the reviewer's first finding on a sibling harness was a file that
# contradicted itself over exactly that.
: > "$build/names.txt"
for source in $sources; do
    grep -o '^NSString \*const [A-Za-z_][A-Za-z0-9_]*' "$avf/$source" \
        | sed 's/^NSString \*const //' >> "$build/names.txt"
done
sort -u "$build/names.txt" > "$build/names.sorted"
mv "$build/names.sorted" "$build/names.txt"
declared=$(wc -l < "$build/names.txt" | tr -d ' ')
[ "$declared" -gt 0 ] || { echo "FAIL: no constant name was read from the port's sources"; exit 1; }
echo "the port's own sources declare $declared constants"

if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = constant ]; then
    # One value, one source, and the replacement is a string of the same shape that cannot be the
    # host's. Applied to a COPY, so the tree is never perturbed.
    echo "the mutation is applied to the renamed copy below, after the copy is made"
fi

# THE PORT'S DEFINITIONS ARE RENAMED IN THE COPY, NOT WITH -D. A -D macro renames every occurrence of
# the name, and on this host the macOS SDK's own AVFoundation headers DECLARE many of these constants
# (AVCaptureReactions.h:43 declares AVCaptureReactionTypeBalloons among them), so the macro renames the
# SDK's declaration too and the compile stops with "redefinition of revenant_host_AVCaptureReactionTypeBalloons
# with a different type". What has to be renamed is the port's DEFINITION and nothing else, so the copy is
# rewritten textually on the `NSString *const <name> =` line and the import is left exactly as it was.
# pass 1: the renamed copy of every source, so the mutation below has all of them on disk whatever
# order they are listed in. It used to run inside the compile loop, and on the first source - which is
# not the mutated one - it stopped with FileNotFoundError, so the mutation could never fire and the
# mutant run proved nothing.
for source in $sources; do
    sed -E 's/^NSString \*const ([A-Za-z_][A-Za-z0-9_]*) =/NSString *const revenant_host_\1 =/' \
        "$avf/$source" > "$build/src/$source"
done

if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = constant ]; then
    [ -f "$build/src/AVFoundationGlobals260.m" ] || {
        echo "FAIL: the mutation target's copy is not there, so this run proves nothing"; exit 1; }
    python3 - "$build/src/AVFoundationGlobals260.m" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
# One value, in the RENAMED copy, so the plant changes what the port holds and nothing else.
before = 'NSString *const revenant_host_AVFileTypeDICOM = @"org.nema.dicom";'
after = 'NSString *const revenant_host_AVFileTypeDICOM = @"org.nema.dicom.PLANTED";'
if text.count(before) != 1:
    raise SystemExit("the mutation target is not unique (%d matches), so this run proves nothing"
                     % text.count(before))
out = text.replace(before, after)
if out.count(before) != 0 or out.count(after) != 1:
    raise SystemExit("the mutation did not take, so this run proves nothing")
open(path, "w").write(out)
print("# the mutation applied: one value in one source, changed and gone afterwards")
PERTURB
fi

# pass 2: compile them.
objects=""
for source in $sources; do
    # shellcheck disable=SC2086
    if ! xcrun clang -fobjc-arc -w -I"$avf" -I"$avf_gen" -c "$build/src/$source" -o "$build/o/$source.o" \
            > "$build/o/$source.log" 2>&1; then
        echo "RUN FAILED: the port's $source did not build - a build failure is never a noticed mutation"
        head -8 "$build/o/$source.log"
        exit 1
    fi
    objects="$objects $build/o/$source.o"
done

# shellcheck disable=SC2086
xcrun clang -fobjc-arc -w "$here/probe.m" $objects -framework Foundation -framework CoreFoundation \
    -o "$build/probe" > "$build/probe.log" 2>&1 || {
        echo "FAIL: the probe did not link or build"; head -12 "$build/probe.log"; exit 1; }
"$build/probe" "$build/names.txt" > "$build/table" 2> "$build/probe.stderr" || {
    echo "FAIL: the probe did not run"; head -10 "$build/probe.stderr"; exit 1; }

# 1. the controls, each of them named, so a run that loaded nothing cannot pass
check_control() {
    # cut -f3, not ${line#*TAB}: the shell's own parameter expansion cannot be relied on to carry a
    # literal tab out of a heredoc-written script, and when it did not the control compared the name
    # against "expected HAS" and stopped on a green run.
    line=$(grep "^CONTROL	$1	" "$build/table" | cut -f3 || true)
    case "$line" in
        "") echo "FAIL: control $1 printed nothing, so the run examined nothing"; exit 1 ;;
    esac
    value=$line
    if [ "$2" = "LACKS" ]; then
        [ "$value" = "LACKS" ] || { echo "FAIL: control $1 answered [$value], expected LACKS"; exit 1; }
    else
        case "$value" in
            HAS*|STR*|NUM*) : ;;
            *) echo "FAIL: control $1 answered [$value], expected HAS"; exit 1 ;;
        esac
    fi
    echo "ok  control $1 = $value"
}
check_control AVMediaTypeVideo HAS
check_control AVMediaTypeDepthData HAS
check_control AVMediaTypeRevenantProbeNoSuchConstant LACKS
check_control AVPlayer HAS

# 2. the row count the probe reports must be the number the sources declare
read=$(sed -n 's/^names read: \([0-9][0-9]*\)  rows: \([0-9][0-9]*\).*/\1 \2/p' "$build/table" | tail -1)
set -- $read
if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo "FAIL: the probe did not report 'names read: N  rows: M', so the row count cannot be checked"
    echo "      against the run's own output. Refusing to guess it from a literal."
    exit 1
fi
if [ "$1" != "$declared" ] || [ "$2" != "$declared" ]; then
    echo "FAIL: the port's sources declare $declared constants, the probe read $1 and emitted $2 rows,"
    echo "      so this run would compare something smaller than the claim"
    exit 1
fi
echo "ok  $declared constants declared, $1 names read, $2 rows emitted"

# 3. the join. One row per name, and the two columns must be equal. A row whose PORT column is LACKS is
#    a defect the join names: the port does not define a constant it declares.
# TAB separated, read with IFS set to the tab alone, because a value is "STR <the string>" and carries
# spaces of its own. Splitting the row on spaces gave this join 60 DIFFERS rows for 116 constants that all
# agreed, and it would have done the same to a genuine difference.
differs=0
port_lacks=0
compared=0
: > "$build/diff.log"
grep -v '^CONTROL	' "$build/table" | grep -v '^names read: ' | \
while IFS=$(printf '\t') read -r name host port; do
    case "$host" in
        LACKS)
            echo "HOST-LACKS	$name	the host does not export it at all, so there is no value to compare" \
                >> "$build/diff.log"
            continue ;;
    esac
    case "$port" in
        LACKS)
            echo "PORT-LACKS	$name	the port declares it and this check cannot see its definition" \
                >> "$build/diff.log"
            continue ;;
    esac
    if [ "$host" != "$port" ]; then
        echo "DIFFERS	$name	host=[$host] port=[$port]" >> "$build/diff.log"
    fi
done
differs=$(grep -c '^DIFFERS	' "$build/diff.log" || true)
port_lacks=$(grep -c '^PORT-LACKS	' "$build/diff.log" || true)
compared=$(grep -c '	host=\|	STR \|	NUM ' "$build/diff.log" || true)
agreed=$((declared - differs - port_lacks))
echo "the join compared $agreed rows that agree and $differs that differ"
[ "$port_lacks" = 0 ] || { cat "$build/diff.log"; echo "FAIL: $port_lacks port-side definitions were not found"; exit 1; }

if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = constant ]; then
    if [ "$differs" = 0 ]; then
        echo "FAIL: the mutation left every value equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed, on $differs row(s):"
    sed -n '1,12p' "$build/diff.log"
    exit 0
fi
# A function mutation still has to get through phase one, and phase one is then an ordinary run: it must
# be clean, or the function verdict below would be read on a tree whose constants are already wrong.
if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = function ]; then
    if [ "$differs" != 0 ]; then
        echo "FAIL: the constants differ on $differs row(s) before the function mutation is even applied"
        sed -n '1,12p' "$build/diff.log"
        exit 1
    fi
    echo "ok  the constants are clean, so the function mutation below is the only thing that can go red"
fi
if [ "$mutant" != 0 ] && [ "$control" != 0 ] && [ "$kind" = constant ]; then
    if [ "$differs" != 0 ]; then
        echo "FAIL: the control is not clean: the unmutated sources through the identical path still"
        echo "      differ on $differs row(s), so the red is the path and not the mutation"
        exit 1
    fi
    echo "ok  the control is clean: the unmutated sources through the identical build-and-run path"
    exit 0
fi

if [ "$differs" != 0 ]; then
    echo "FAIL: the port's value differs from the host's on $differs of $declared constants"
    sed -n '1,24p' "$build/diff.log"
    exit 1
fi
if [ -s "$build/diff.log" ]; then
    echo "note: the host does not export these, so they have no value to compare:"
    cat "$build/diff.log"
fi
echo "ok  every one of the $declared constants the port defines holds the value the host's own symbol holds"

# ---------------------------------------------------------------------------------------------
# The four FUNCTIONS, the same way: the port's object compiled with each name defined to its
# revenant_host_ spelling, linked beside a probe that calls Apple's own symbol and the port's, and the two
# answers printed side by side. The three caption constructors return a struct of two fields out of two
# arguments, so the comparison is over field values; the reaction lookup is compared for every type the
# port carries and for one it does not, where the host's own answer is measured too.
# ---------------------------------------------------------------------------------------------
fsource=AVFoundationFunctions180.m
[ -f "$avf/$fsource" ] || {
    echo "FAIL: $avf/$fsource does not exist, so the functions this run checks for are not there"
    exit 1
}
# The DEFINITION, wherever the return type leaves it: the three constructors start a line with their
# return type in front of the name and the reaction lookup starts its line with `NSString *`. Anchoring
# on `^NAME(` found none of the four, which is why the count check below first said 0.
fnames=$(grep -o '\(AVCaptionDimensionMake\|AVCaptionPointMake\|AVCaptionSizeMake\|AVCaptureReactionSystemImageNameForType\)(' \
    "$avf/$fsource" | sed 's/($//' | sort -u)
fn=$(printf '%s\n' "$fnames" | grep -c . || true)
[ "$fn" = 4 ] || {
    echo "FAIL: $fsource defines $fn of the four functions this check asks about, so this run would"
    echo "      compare something smaller than the claim"
    exit 1
}
echo "the port's $fsource defines $fn functions"

# Two renames in this copy, and both are needed and neither is a wildcard:
#   - the four function DEFINITIONS, so the port's answer is reachable under a prefixed name;
#   - the eight reaction-type CONSTANTS the lookup compares against, so it is asked with the port's own
#     carried strings rather than Apple's. Anchored on `isEqualToString:` on purpose: a plain
#     `AVCaptureReactionType` pattern also matches the parameter's TYPE in `NSString *f(AVCaptureReactionType
#     reactionType)` and on `NSString *` the compiler is right and the link is wrong.
# The four names are replaced WHEREVER they appear, not anchored at the start of a line: the three
# constructors are written `AVCaptionDimension AVCaptionDimensionMake(...)` and the lookup
# `NSString *AVCaptureReactionSystemImageNameForType(...)`, so neither has its name at column 0. An
# anchored pattern renamed NOTHING, the four symbols then resolved against the linked AVFoundation, every
# `revenant_host_` pointer stayed NULL, and the probe segfaulted on the first call - a green-looking run
# that had compared nothing.
sed -E -e 's/(AVCaptionDimensionMake|AVCaptionPointMake|AVCaptionSizeMake|AVCaptureReactionSystemImageNameForType)\(/revenant_host_\1(/g' \
       -e 's/isEqualToString:AVCaptureReactionType/isEqualToString:revenant_host_AVCaptureReactionType/' \
    "$avf/$fsource" > "$build/src/$fsource.fn"
for name in AVCaptionDimensionMake AVCaptionPointMake AVCaptionSizeMake AVCaptureReactionSystemImageNameForType; do
    grep -q "revenant_host_$name(" "$build/src/$fsource.fn" || {
        echo "FAIL: the copy of $fsource does not define revenant_host_$name, so the probe would call a NULL"
        echo "      pointer and this run would prove nothing"
        exit 1
    }
done
# The rename has to have landed on all of them, or the port's lookup is silently comparing against
# something this copy never renamed and the link error below is the only thing that would say so.
for name in Balloons Confetti Fireworks Heart Lasers Rain ThumbsUp ThumbsDown; do
    grep -q "revenant_host_AVCaptureReactionType$name" "$build/src/$fsource.fn" || {
        echo "FAIL: the copy of $fsource does not reference revenant_host_AVCaptureReactionType$name, so the"
        echo "      lookup would compare against a symbol this build does not provide"
        exit 1
    }
done
if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = function ]; then
    python3 - "$build/src/$fsource.fn" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
# ONE returned string, so the plant changes what the port answers and nothing about its shape.
before = 'return @"heart.fill";'
after = 'return @"heart.PLANTED";'
if text.count(before) != 1:
    raise SystemExit("the mutation target is not unique (%d matches), so this run proves nothing"
                     % text.count(before))
out = text.replace(before, after)
if out.count(before) != 0 or out.count(after) != 1:
    raise SystemExit("the mutation did not take, so this run proves nothing")
open(path, "w").write(out)
print("# the mutation applied: one returned string in one function, changed and gone afterwards")
PERTURB
fi
# -x objective-c, because the copy is named .fn: clang's driver does not recognise that suffix, takes
# it for something to LINK, and with -c it exits 0 having written nothing at all - no error, no log line,
# no object. The next step then fails with "no such file or directory" and names the wrong thing.
if ! xcrun clang -fobjc-arc -w -x objective-c -include "$here/renamed.h" -I"$avf" -I"$avf_gen" \
        -c "$build/src/$fsource.fn" -o "$build/o/functions.o" \
        > "$build/o/functions.log" 2>&1; then
    echo "RUN FAILED: the port's $fsource did not build - a build failure is never a noticed mutation"
    head -8 "$build/o/functions.log"
    exit 1
fi
# The reaction TYPE constants the lookup compares against live in another object, so they are linked in
# beside it. Both objects are the 18.0 band - measured by tools/symbol-first-release.lua, not assumed - so
# neither is ever left out of a band the other is in.
#
# And that object needs the same DEFINITION-ONLY rename the five needed in phase one, for a new reason:
# this host's own macOS SDK DOES declare AVCaptureReactionTypeBalloons and its seven siblings
# (MacOSX.sdk/.../AVCaptureReactions.h:43), so an unrenamed copy collides with Apple's declaration -
# "redefinition of 'AVCaptureReactionTypeBalloons' with a different type". The probe reads the BARE name
# for the type it passes in, which is Apple's own symbol and the same string either way, so the port's
# lookup is still asked about the value it will really be asked about.
globals180="$avf/AVFoundationGlobals180.m"
sed -E 's/^NSString \*const ([A-Za-z_][A-Za-z0-9_]*) =/NSString *const revenant_host_\1 =/' \
    "$globals180" > "$build/src/globals180.fn"
if ! xcrun clang -fobjc-arc -w -x objective-c -I"$avf" -I"$avf_gen" -c "$build/src/globals180.fn" -o "$build/o/globals180.o" \
        > "$build/o/globals180.log" 2>&1; then
    echo "RUN FAILED: the port's AVFoundationGlobals180.m did not build"
    head -8 "$build/o/globals180.log"
    exit 1
fi
if ! xcrun clang -fobjc-arc -w "$here/functions.m" "$build/o/functions.o" "$build/o/globals180.o" \
        -framework Foundation -framework CoreMedia -framework CoreGraphics -framework AVFoundation \
        -o "$build/functions" > "$build/functions.log" 2>&1; then
    echo "FAIL: the functions probe did not build"; head -12 "$build/functions.log"; exit 1
fi
for object in functions.o globals180.o; do
    [ -f "$build/o/$object" ] || {
        echo "FAIL: the compile of $object reported success and wrote no object, so the link below would"
        echo "      have measured nothing. Refusing to go on."
        exit 1
    }
done
"$build/functions" > "$build/functions.table" 2> "$build/functions.stderr" || {
    echo "FAIL: the functions probe did not run"; head -10 "$build/functions.stderr"; exit 1; }

fline=$(grep "^CONTROL	AVCaptionNoSuchConstructor	" "$build/functions.table" | cut -f3 || true)
[ "$fline" = "LACKS" ] || { echo "FAIL: the planted-function control answered [$fline], expected LACKS"; exit 1; }
echo "ok  control AVCaptionNoSuchConstructor = $fline"
fline=$(grep "^CONTROL	AVCaption	" "$build/functions.table" | cut -f3 || true)
case "$fline" in HAS*) : ;; *) echo "FAIL: the AVCaption control answered [$fline], expected HAS"; exit 1 ;; esac
echo "ok  control AVCaption = $fline"
# The arithmetic control: 0 and 2 are the only answer 0 percent can have, so a probe returning anything
# else has not run the port's function at all.
fline=$(grep "^CONTROL	AVCaptionDimensionMake(0,Percent)	" "$build/functions.table" | cut -f3 || true)
[ "$fline" = "0/2 0/2" ] || { echo "FAIL: the arithmetic control answered [$fline], expected 0/2 0/2"; exit 1; }
echo "ok  control AVCaptionDimensionMake(0,Percent) port and host = $fline"

frows=$(grep -c '	same$' "$build/functions.table" || true)
fdiffers=$(grep -c '	DIFFERENT$' "$build/functions.table" || true)
react=$(grep -c '^AVCaptureReactionType' "$build/functions.table" || true)
reactdiffers=$(grep '^AVCaptureReactionType' "$build/functions.table" | grep -vc 'host=\[\(.*\)\]	port=\[\1\]$' || true)
planted=$(grep "^PLANTED-TYPE	" "$build/functions.table" | cut -f2,3 || true)

if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = function ]; then
    if [ "$differs" != 0 ]; then
        echo "FAIL: the constants differ on $differs row(s) before the function mutation is applied"
        sed -n '1,12p' "$build/diff.log"
        exit 1
    fi
    if [ "$fdiffers" = 0 ] && [ "$reactdiffers" = 0 ]; then
        echo "FAIL: the mutation left every function answer equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed: $fdiffers struct row(s) and $reactdiffers reaction row(s) differ"
    grep '	DIFFERENT$' "$build/functions.table" | head -4
    grep '^AVCaptureReactionType' "$build/functions.table" | grep -v 'host=\[\(.*\)\]	port=\[\1\]$' | head -4
    exit 0
fi
if [ "$mutant" != 0 ] && [ "$control" != 0 ] && [ "$kind" = function ]; then
    if [ "$fdiffers" != 0 ] || [ "$reactdiffers" != 0 ]; then
        echo "FAIL: the control is not clean: $fdiffers struct row(s) and $reactdiffers reaction row(s) differ"
        echo "      through the identical path, so the red would be the path and not the mutation"
        exit 1
    fi
    echo "ok  the control is clean: the unmutated function through the identical build-and-run path"
    exit 0
fi

if [ "$fdiffers" != 0 ] || [ "$reactdiffers" != 0 ]; then
    echo "FAIL: the port's function answers differ from the host's on $fdiffers struct row(s) and $reactdiffers reaction row(s)"
    grep '	DIFFERENT$' "$build/functions.table" | head -12
    grep '^AVCaptureReactionType' "$build/functions.table" | grep -v 'host=\[\(.*\)\]	port=\[\1\]$' | head -12
    exit 1
fi
echo "ok  $frows struct rows agree with the host and $react reaction types answer the same string"
echo "note: the type the port does not carry, measured on both sides: $planted"

# ---------------------------------------------------------------------------------------------
# The METRIC surface. Same shape again: the port's two metric objects compiled with every CLASS name
# defined to its revenant_host_ spelling, linked beside a probe that asks the ObjC runtime on both sides.
# The names come from the two registry files, so the probe cannot ask about something the registry does
# not carry and a row the tree forgot to register is not silently skipped.
#
# The host HAS this surface - iOS 18 added it and this macOS is 27 - so this is a real structural
# differential: every class and its superclass, and one member per property row.
# ---------------------------------------------------------------------------------------------
for msource in AVFoundationMetrics18.m AVFoundationMetrics18b.m AVFoundationMetrics26.m; do
    [ -f "$avf/$msource" ] || {
        echo "FAIL: $avf/$msource does not exist, so the metric surface this run checks for is not there"
        exit 1
    }
done
# THE PROBE'S LIST IS BUILT FROM THE REGISTRY, never typed here: one line per class row, per protocol row
# and per property row, out of the two files this family writes. A name the registry does not carry is a
# name the probe is not asked about, and a row the tree forgot to register cannot hide behind a list that
# was written by hand.
# THE DECLARED GETTER, not the property name. `@property (readonly, getter=wasReadFromCache) BOOL
# readFromCache;` declares a property called readFromCache whose accessor is -wasReadFromCache, so a probe
# that asks for -readFromCache finds nothing on EITHER side and reports the row equal - it never asks.
# RevenantAVMetrics18.h:156 is that line, and the first version of this list asked the property name, so
# `-[AVMetricMediaResourceRequestEvent readFromCache] host=no` was a statement about a selector neither side
# implements rather than about the port carrying more than the host.
#
# So the list carries the SELECTOR the header declares, read out of the header itself, and a row whose
# accessor cannot be found there is reported rather than guessed at.
python3 - "$avf/CharonAVMetrics18.h" "$build/metric-getters.tsv" <<'GETTERS'
import re, sys
text = open(sys.argv[1]).read()
# @property ... <name> ...; with an optional getter=<accessor> in the attribute list
pattern = re.compile(r"@property\s*(\([^)]*\))?\s*[^;]*?\b(\w+)\s*(?:\w+\s*)*;")
decl = {}
current = None
for line in text.split("\n"):
    match = re.match(r"@interface\s+(AVMetric\w+)", line)
    if match:
        current = match.group(1)
        continue
    if "@property" not in line or current is None:
        continue
    attributes = line.split("@property", 1)[1].split(")", 1)[0] if "(" in line.split("@property",1)[1] else ""
    getter = None
    found = re.search(r"getter=(\w+)", attributes)
    if found:
        getter = found.group(1)
    # The property NAME is the last identifier BEFORE the first annotation. Taking the last identifier of
    # the line is wrong: `API_AVAILABLE(macos(26.0), ios(26.0), ...)` ends the line, so the last token is a
    # version number and the three rendition properties came out unnamed - which the guard below turned into
    # a refusal rather than a wrong selector. The three rendition properties are what that guard was for.
    annotation = re.compile(r"^(NS_|API_|CF_|AVF_|UI_|SWIFT_|readonly|readwrite|nonatomic|atomic|strong|"
                            r"weak|copy|assign|retain|unsafe_unretained|getter|setter)")
    # The attribute list goes first: `(readonly)` is itself an annotation token, so walking the line from
    # `readonly` stops before the name is ever seen - which is what raised on `@property (readonly) NSDate
    # *date;`, the very first property in the header.
    head = re.sub(r"^\s*\([^)]*\)", "", line.split("@property", 1)[1])
    head = re.sub(r"<[^<>]*>", "", head)
    name = None
    for token in re.findall(r"\b(\w+)\b", head):
        if annotation.match(token):
            break
        name = token
    if name is None:
        raise SystemExit("cannot tell the property name on this line, so this run must not guess: " + line)
    names = [name]
    decl[(current, names[-1])] = getter or names[-1]
with open(sys.argv[2], "w") as handle:
    for (owner, prop), accessor in sorted(decl.items()):
        handle.write("%s\t%s\t%s\n" % (owner, prop, accessor))
print("the header declares %d accessors, %d of them under a name other than the property's"
      % (len(decl), sum(1 for (o, p), a in decl.items() if a != p))
      )
GETTERS
python3 - "$root/packages/a/apple-backports/registry/AVFoundation" "$build/metric-list.tsv" "$build/metric-getters.tsv" <<'LISTEOF'
import json, os, sys
folder, out, getters_path = sys.argv[1], sys.argv[2], sys.argv[3]
getters = {}
for line in open(getters_path):
    owner, prop, accessor = line.rstrip("\n").split("\t")
    getters[(owner, prop)] = accessor
rows, unnamed = [], []
for name in sorted(os.listdir(folder)):
    if not name.startswith("metrics") or not name.endswith(".json"):
        continue
    for entry in json.load(open(os.path.join(folder, name))).get("entries", []):
        if entry["kind"] == "class":
            rows.append(("class", entry["api"], ""))
        elif entry["kind"] == "protocol":
            rows.append(("protocol", entry["api"], ""))
        elif entry["kind"] == "property":
            owner, member = entry["api"].split(".", 1)
            accessor = getters.get((owner, member))
            if accessor is None:
                unnamed.append(entry["api"])
                continue
            rows.append(("member", owner, accessor))
if unnamed:
    raise SystemExit("no accessor is declared for these rows, so asking the property name would ask a "
                     "selector neither side has: " + " ".join(unnamed))
with open(out, "w") as handle:
    for kind, first, second in rows:
        handle.write("%s\t%s\t%s\n" % (kind, first, second))
print("the metric probe is asked about %d classes, protocols and members" % len(rows))
LISTEOF
# THE CLASSES ARE RENAMED WHOLESALE, and the macOS SDK is why: it ships AVMetrics.h of its own, so
# RevenantAVMetrics18.h's guard excludes every declaration here, and an unrenamed copy would compile
# AVFoundationMetrics18.m against APPLE's declarations and its @implementation would BE Apple's class -
# the probe would then be comparing the host against itself and would report every row equal.
#
# A rename of the @implementation lines alone does not work: the class extension in the .m keeps the old
# name, so clang sees a root class and stops with "no known class method for selector 'alloc'" and
# "'revenant_host_AVMetricEventStream' cannot use 'super' because it is a root class". So the copy also
# carries a prologue that declares each renamed class with the hierarchy RevenantAVMetrics18.h gives it,
# read out of that header so the two cannot disagree.
python3 - "$avf/CharonAVMetrics18.h" "$build/src/metric-prologue.h" <<'PROLOGUE'
import re, sys
text = open(sys.argv[1]).read()
out = ["// Generated by tests/backports/host/avf-globals/run.sh from RevenantAVMetrics18.h: every @interface",
       "// the header declares, with the class name prefixed. The BODY is copied with it, properties and",
       "// all - a bare `@interface revenant_host_X : NSObject @end` is not enough, because the copy's",
       "// @synthesize lines then have no declaration to synthesize and clang stops with \"property",
       "// implementation must have its declaration in interface 'revenant_host_AVMetricEvent'\".",
       "#import <Foundation/Foundation.h>",
       "#import <CoreMedia/CoreMedia.h>",
       "#import <AVFoundation/AVFoundation.h>"]
blocks = re.findall(r"(@interface\s+AVMetric\w+[^\n]*)\n(.*?)@end", text, re.S)
parents = set()
for declaration, _body in blocks:
    parent = declaration.split(":", 1)[1].strip().split()[0]
    parents.add(parent)
for parent in sorted(parents):
    if parent != "NSObject":
        out.append("@class %s;" % parent)
# THE PARENT IS RENAMED TOO, and not renaming it is what made one archived value disappear.
#
# `@interface AVMetricErrorEvent : AVMetricEvent` becomes `@interface revenant_host_AVMetricErrorEvent : AVMetricEvent`
# if only the class's own name is prefixed - and bare `AVMetricEvent` in the host build resolves to APPLE's
# class, because the host framework is linked in. The port's error event then derives from Apple's event, and
# packages/runtimes/revenant-coding's walker, which walks [object class] up to NSObject, reaches Apple's AVMetricEvent
# and reads and writes ITS ivars at ITS offsets on a port object.
#
# The dump that showed it, from the port's own class:
#
#   ivar _didRecover   owner=revenant_host_AVMetricErrorEvent   type=B    size=1
#   ivar _error        owner=revenant_host_AVMetricErrorEvent   type=@"NSError" size=8
#   ivar _date         owner=AVMetricEvent                    <- Apple's class, not the port's
#   ivar _mediaTime    owner=AVMetricEvent
#   ivar _sessionID    owner=AVMetricEvent
#
# So `didRecover` is the one value whose OWNING class is the port's, and it was the one value that went
# missing; the eight that carried were read and written through Apple's ivar offsets on a port object, which
# lined up by luck. That is a defect in this harness and not in the port, and no value of it should have been
# believed until the hierarchy was right.
for declaration, body in blocks:
    name = declaration.split()[1]
    parent = declaration.split(":", 1)[1].strip().split()[0]
    if parent == "AVMetricEventStream":
        parent = "NSObject"
    if parent.startswith("AVMetric"):
        parent = "revenant_host_" + parent
    out.append(declaration.replace("@interface " + name, "@interface revenant_host_" + name, 1)
                            .replace(" : " + declaration.split(":", 1)[1].strip().split()[0],
                                     " : " + parent, 1))
    out.append(body.rstrip())
    out.append("@end")
for parent in sorted(parents):
    if parent != "NSObject" and parent.startswith("AVMetric"):
        out.append("@class revenant_host_%s;" % parent)
open(sys.argv[2], "w").write("\n".join(out) + "\n")
print("the host build's prologue declares %d renamed classes" % len(blocks))
PROLOGUE
{
    cat "$build/src/metric-prologue.h"
    sed -E -e 's/^@implementation (AVMetric[A-Za-z0-9_]*) *$/@implementation revenant_host_\1/' \
           -e 's/^@implementation (AVMetric[A-Za-z0-9_]*) \(/@implementation revenant_host_\1 (/' \
           -e 's/^@interface (AVMetric[A-Za-z0-9_]*) \(/@interface revenant_host_\1 (/' \
        "$avf/AVFoundationMetrics18.m"
} > "$build/src/metrics18.rn"
if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = metrics ]; then
    # The plant is on the PORT's own hierarchy: one class is made to inherit from the wrong parent, which
    # is what a wrong transcription of AVMetrics.h would produce and what the SUPERCLASS row catches.
    python3 - "$build/src/metrics18.rn" <<'PERTURB'
import re, sys
path = sys.argv[1]
text = open(path).read()
# The parent is spelled revenant_host_-prefixed since the prologue began renaming parents too; an unprefixed
# anchor stopped matching then and the guard printed "the mutation target is not unique (0 matches)", which
# is the guard doing its job on a stale aim rather than on a missing plant.
before = "@interface revenant_host_AVMetricPlayerItemStallEvent : revenant_host_AVMetricPlayerItemRateChangeEvent"
after = "@interface revenant_host_AVMetricPlayerItemStallEvent : revenant_host_AVMetricEvent"
if text.count(before) != 1:
    raise SystemExit("the mutation target is not unique (%d matches), so this run proves nothing"
                     % text.count(before))
out = text.replace(before, after)
if out.count(before) != 0 or out.count(after) != 1:
    raise SystemExit("the mutation did not take, so this run proves nothing")
open(path, "w").write(out)
print("# the mutation applied: one class made to inherit from the wrong parent")
PERTURB
fi
{
    cat "$build/src/metric-prologue.h"
    sed -E -e 's/^@implementation (AVMetric[A-Za-z0-9_]*) *$/@implementation revenant_host_\1/' \
           -e 's/^@implementation (AVMetric[A-Za-z0-9_]*) \(/@implementation revenant_host_\1 (/' \
           -e 's/^@interface (AVMetric[A-Za-z0-9_]*) \(/@interface revenant_host_\1 (/' \
        "$avf/AVFoundationMetrics26.m"
} > "$build/src/metrics26.rn"
# The 18 BAND object is in this binary too. Without it the probe reports port=no for every
# AVMetricDownloadSummaryEvent accessor, because the class is not in the binary at all - which is the
# port-lacks guard doing its job on a port that was merely not linked.
{
    cat "$build/src/metric-prologue.h"
    sed -E -e 's/^@implementation (AVMetric[A-Za-z0-9_]*) *$/@implementation revenant_host_\1/' \
           -e 's/^@implementation (AVMetric[A-Za-z0-9_]*) \(/@implementation revenant_host_\1 (/' \
           -e 's/^@interface (AVMetric[A-Za-z0-9_]*) \(/@interface revenant_host_\1 (/' \
        "$avf/AVFoundationMetrics18b.m"
} > "$build/src/metrics18b.rn"
mobjs=""
for pair in "metrics18.rn:metrics18.o" "metrics18b.rn:metrics18b.o" "metrics26.rn:metrics26.o"; do
    src=${pair%%:*}; obj=${pair##*:}
    # -x objective-c for the same reason as the functions phase: the copy is named .rn, which the driver
    # does not recognise, and with -c it exits 0 having written nothing at all. The object-exists guard
    # below is what turns that into a red instead of a link error about a missing file.
    if ! xcrun clang -fobjc-arc -w -x objective-c -I"$avf" -I"$avf_gen" -c "$build/src/$src" -o "$build/o/$obj" \
            > "$build/o/$obj.log" 2>&1; then
        echo "RUN FAILED: the port's $src did not build"
        head -8 "$build/o/$obj.log"
        exit 1
    fi
    [ -f "$build/o/$obj" ] || { echo "FAIL: $obj was not written, so the link below would measure nothing"; exit 1; }
    mobjs="$mobjs $build/o/$obj"
done
# THE ARCHIVER IS COMPILED FOR THE HOST, from the tree's own source, rather than linked from the installed
# package - and that is not a preference. The installed librevenant-coding.a is `Non-fat file ... architecture:
# armv7`: it is built for the device, so linking it into an arm64 macOS binary leaves
#
#   "_revenant_intents_encode", referenced from: -[revenant_host_AVMetricEvent encodeWithCoder:]
#   ld: symbol(s) not found for architecture arm64
#
# The port's own objects are compiled for the host here in the same way, so the walker is treated the same.
coding=""
for candidate in "$root/packages/runtimes/revenant-coding/files" "$HOME/Git/projects/ios/revenant/toolchain/packages/runtimes/revenant-coding/files"; do
    [ -f "$candidate/RevenantCoding.m" ] && { coding_source="$candidate/RevenantCoding.m"; break; }
done
[ -n "${coding_source:-}" ] || {
    echo "FAIL: no RevenantCoding.m was found, so the archive would carry nothing and every"
    echo "      +supportsSecureCoding would answer no. Build the package and try again."
    exit 1
}
if ! xcrun clang -fobjc-arc -w -c "$coding_source" -o "$build/o/coding.o" > "$build/o/coding.log" 2>&1; then
    echo "RUN FAILED: the tree's own RevenantCoding.m did not build for the host"
    head -8 "$build/o/coding.log"
    exit 1
fi
[ -f "$build/o/coding.o" ] || { echo "FAIL: coding.o was not written, so the round trip would measure nothing"; exit 1; }
coding="$build/o/coding.o"
echo "revenant-coding compiled for the host from $(basename "$coding_source")"

if ! xcrun clang -fobjc-arc -w "$here/metrics.m" $mobjs $coding -framework Foundation -framework CoreMedia \
        -framework AVFoundation -o "$build/metrics" > "$build/metrics.log" 2>&1; then
    echo "FAIL: the metrics probe did not build"; head -14 "$build/metrics.log"; exit 1
fi
if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = coding ]; then
    # The plant is the SILENT wrong answer, not a crash: -initWithCoder: calling -init instead of decoding.
    # Everything still archives, everything still unarchives, and a test comparing two freshly made archives
    # would still pass - only a test that reads an archived date set to a moment in the past sees the restamp.
    python3 - "$build/src/metrics18.rn" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
# THE PLANT IS ON THE ENCODE SIDE, and that is what makes it observable.
#
# Three plants were tried here and the first two were invisible, which is worth recording because each read
# as a passing run:
#
#   1. swap revenant_intents_super_init for [self init] in -initWithCoder:. Invisible: -init stamps a date,
#      the decode then overwrites it from the archive, and every value still arrives.
#   2. delete the revenant_intents_decode call. Also invisible: NSKeyedUnarchiver has already restored the
#      ivars by the time a nil decode could matter, and the probe reads the ACCESSORS.
#   3. delete the revenant_intents_encode call - this one. The archive then has no key for these classes at
#      all and every value must notice it.
#
# Two of those edits never even landed. They were python string replacements aimed at text a previous edit
# had already replaced, and python's str.replace on a missing needle is a silent no-op - so the file kept the
# FIRST plant for four runs while the commit messages described the third. The guard below is the fix for
# that class of mistake as well as for the mutation: it reads the target out of the file and says so when it
# is not there, instead of compiling whatever is there and reporting that the mutation "was applied".
path = sys.argv[1]
text = open(path).read()
before = "    revenant_intents_encode(self, coder);"
after = "    /* PLANTED: the archive writes nothing at all */"
if text.count(before) != 1:
    raise SystemExit("the mutation target is not unique (%d matches), so this run proves nothing"
                     % text.count(before))
out = text.replace(before, after)
if out.count(before) != 0 or out.count(after) != 1:
    raise SystemExit("the mutation did not take, so this run proves nothing")
open(path, "w").write(out)
print("# the mutation applied: -encodeWithCoder: now writes nothing, so the archive carries no value")
PERTURB
    # REBUILD THE OBJECT THE PROBE LINKS, and show that the result is not the object that was there.
    #
    # The first version rebuilt with `mobjs="$mobjs $build/o/$obj"`, which APPENDS: the list then held the
    # same path twice and the linker took the first, unplanted, object - so the values still arrived and the
    # mutation did not fire. A rebuilt object that nothing relinks is not a rebuild.
    for pair in "metrics18.rn:metrics18.o" "metrics18b.rn:metrics18b.o" "metrics26.rn:metrics26.o"; do
        src=${pair%%:*}; obj=${pair##*:}
        before=$(shasum -a 256 "$build/o/$obj" | cut -d' ' -f1)
        if ! xcrun clang -fobjc-arc -w -x objective-c -I"$avf" -I"$avf_gen" -c "$build/src/$src" -o "$build/o/$obj" \
                > "$build/o/$obj.log" 2>&1; then
            echo "RUN FAILED: $src did not build after the mutation"
            head -6 "$build/o/$obj.log"
            exit 1
        fi
        after=$(shasum -a 256 "$build/o/$obj" | cut -d' ' -f1)
        # Only the object the plant was applied to has to differ. The other two are rebuilt so the link is
        # consistent, and requiring them to differ would be requiring a mutation that was never made - the
        # first version of this did that and reported a green object as a failure.
        [ "$src" = metrics18.rn ] || { echo "rebuilt $obj (the plant is not in this one)"; continue; }
        if [ "$before" = "$after" ]; then
            echo "FAIL: $obj is byte-for-byte what it was before the mutation, so the probe below links the"
            echo "      same object and this mutation can never be noticed"
            exit 1
        fi
        echo "rebuilt $obj after the mutation, and it differs: ${before%????????????????????????????????????????????????} -> ${after%????????????????????????????????????????????????}"
    done
fi
if ! xcrun clang -fobjc-arc -w "$here/coding.m" $mobjs $coding -framework Foundation -framework CoreMedia \
        -framework AVFoundation -o "$build/coding" > "$build/coding.log" 2>&1; then
    echo "FAIL: the coding probe did not build"; head -14 "$build/coding.log"; exit 1
fi
"$build/coding" > "$build/coding.table" 2> "$build/coding.stderr" || {
    echo "FAIL: the coding probe did not run"; head -10 "$build/coding.stderr"; exit 1; }
"$build/metrics" "$build/metric-list.tsv" > "$build/metrics.table" 2> "$build/metrics.stderr" || {
    echo "FAIL: the metrics probe did not run"; head -10 "$build/metrics.stderr"; exit 1; }

mcheck() {
    line=$(grep "^CONTROL	$1	" "$build/metrics.table" | cut -f3 || true)
    [ -n "$line" ] || { echo "FAIL: the metric control $1 printed nothing, so the run examined nothing"; exit 1; }
    case "$2" in
        ABSENT) [ "$line" = ABSENT ] || { echo "FAIL: control $1 answered [$line], expected ABSENT"; exit 1; } ;;
        HAS) case "$line" in HAS*|yes) : ;; *) echo "FAIL: control $1 answered [$line], expected HAS"; exit 1; ;; esac ;;
        *) echo "FAIL: no expectation given for control $1"; exit 1 ;;
    esac
    echo "ok  control $1 = $line"
}
mcheck AVMetricNoSuchClass ABSENT
mcheck AVMetricEvent HAS
mcheck "AVMetricEventStreamSubscriber" HAS
mline=$(grep "^CONTROL	-\[AVMetricEvent date\]	" "$build/metrics.table" | cut -f3 || true)
[ "$mline" = yes ] || { echo "FAIL: the -date control answered [$mline], expected yes"; exit 1; }
echo "ok  control -[AVMetricEvent date] = $mline"

mabsent=$(grep '^CLASS	' "$build/metrics.table" | awk -F'	' '{split($3,p,"="); if (p[2]=="ABSENT") print $2}' | tr '\n' ' ')
mdiffer=$(grep -c '	DIFFERENT$' "$build/metrics.table" || true)
mclasses=$(grep -c '^CLASS	' "$build/metrics.table" || true)
mmembers=$(grep -c '^RESPONDS	' "$build/metrics.table" || true)
mhostlacks=$(grep '^RESPONDS	' "$build/metrics.table" | grep -c 'host=no' || true)
mportlacks=$(grep '^RESPONDS	' "$build/metrics.table" | grep -c 'port=no' || true)

if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = metrics ]; then
    if [ "$differs" != 0 ]; then
        echo "FAIL: the constants differ on $differs row(s) before the metric mutation is applied"
        sed -n '1,12p' "$build/diff.log"
        exit 1
    fi
    if [ "$mdiffer" = 0 ] && [ -z "$mabsent" ]; then
        echo "FAIL: the mutation left every class where it was, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed: $mdiffer hierarchy row(s) differ and these names vanished: $mabsent"
    grep '	DIFFERENT$' "$build/metrics.table" | head -6
    exit 0
fi

if [ -n "$mabsent" ]; then
    echo "FAIL: the port does not define these classes its own registry rows name: $mabsent"
    exit 1
fi
if [ "$mdiffer" != 0 ]; then
    echo "FAIL: the port's hierarchy differs from the host's on $mdiffer row(s)"
    grep '	DIFFERENT$' "$build/metrics.table" | head -12
    exit 1
fi
if [ "$mportlacks" != 0 ]; then
    echo "FAIL: the port does not implement the declared accessor of $mportlacks row(s), so a registry row"
    echo "      claims a member the object does not answer"
    grep '^RESPONDS	' "$build/metrics.table" | grep 'port=no' | head -12
    exit 1
fi
echo "ok  $mclasses classes resolve on both sides with the same superclass, and $mmembers members were asked of the host"
if [ "$mhostlacks" != 0 ]; then
    echo "note: $mhostlacks of those members the host's own class does not answer - the port carries them and"
    echo "      the host's class does not, which is the direction the policy asks for; printed, not exempted:"
    grep '^RESPONDS	' "$build/metrics.table" | grep 'host=no' | head -6
fi
# the secure-coding verdict, from the table the coding probe wrote
check_coding() {
    line=$(grep "^CONTROLSECTIONPORT	$1	" "$build/coding.table" | cut -f3 || true)
    [ "$line" = YES ] || { echo "FAIL: +[$1 supportsSecureCoding] answered [$line], expected YES"; exit 1; }
    echo "ok  +[$1 supportsSecureCoding] = YES"
}
cline=$(grep "^ARCHIVE-CONTROL	" "$build/coding.table" | cut -f2 || true)
[ "$cline" = kept ] || { echo "FAIL: the Foundation-only archive control answered [$cline], expected kept"; exit 1; }
echo "ok  archive control: $cline"
check_coding AVMetricEvent
check_coding AVMetricMediaRendition
cbad=$(grep -c 'host-carried=NO' "$build/coding.table" || true)
crestamped=$(grep -c 'held=RESTAMPED' "$build/coding.table" || true)
# An OPEN row is reported and counted on its own, never as a pass: it is a value this run could not show
# carried, and folding it into either verdict would be the one thing this harness must not do.
copen=$(grep -c '	OPEN' "$build/coding.table" || true)
if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = coding ]; then
    if [ "$cbad" = 0 ] && [ "$crestamped" = 0 ]; then
        # OPEN, and the run says so instead of passing. The plant removes revenant_intents_decode from
        # -initWithCoder: and the archived values still arrive, so the phase does not yet catch it and is
        # therefore NOT a check for the archive path - only its controls and its values are evidence. The
        # plant lands in the source and the values still arrive, which points at the rebuild below not
        # reaching the object the probe links; that is not isolated yet and is recorded in
        # coordination/wave-2026-10-03/v-avf-report.md rather than guessed at here.
        echo "OPEN the coding mutation was NOT noticed: $cbad value(s) lost, $crestamped restamped, with the"
        echo "     decode removed from -initWithCoder:. This phase's controls and values stand; its"
        echo "     power to fail does not, and nothing here should be read as saying it does."
        exit 1
    fi
    echo "ok  the mutation was noticed: $cbad archived value(s) lost and $crestamped restamped"
    grep -E 'host-carried=NO|held=RESTAMPED|ARCHIVE-FAILED|UNARCHIVE-FAILED' "$build/coding.table" | head -6
    exit 0
fi
if [ "$cbad" != 0 ] || [ "$crestamped" != 0 ]; then
    echo "FAIL: $cbad archived value(s) were not carried and $crestamped were restamped by -init"
    grep -E 'host-carried=NO|held=RESTAMPED|ARCHIVE-FAILED|UNARCHIVE-FAILED' "$build/coding.table" | head -10
    exit 1
fi
echo "ok  $(grep -c 'host-carried=yes' "$build/coding.table") archived values carried, on both roots and a"
echo "    subclass, and -initWithCoder: did not go through -init"
[ "$copen" = 0 ] || echo "OPEN $copen archived value(s) this run could not show carried - printed above and"
[ "$copen" = 0 ] || echo "     in coordination/wave-2026-10-03/v-avf-report.md, not counted as a pass"

# ---------------------------------------------------------------------------------------------
# The CONTROLS surface. Same shape again, with one difference the port forced: the session's ten members
# are a CATEGORY on AVCaptureSession, and AVCaptureSession is APPLE's class on this host, so a copy
# compiled here unchanged would not be the port's category at all - it would replace Apple's own ten
# implementations in this process, and the probe would then be comparing the port against itself. So the
# copy is renamed at its @implementation line and lands on a stand-in owner this build declares
# (revenant_host_AVCaptureSession), while the port's class is renamed the way the metric phase renames its
# seventeen. The category NAME is not renamed and the stand-in declares that same name, so a category
# spelled differently in the port's source still fails to compile (clang: "cannot find interface
# declaration for '<name>'"), and the reason strings the port raises stay Apple's own text.
# ---------------------------------------------------------------------------------------------
csource=AVCaptureControls18.m
[ -f "$avf/$csource" ] || {
    echo "FAIL: $avf/$csource does not exist, so the controls surface this run checks for is not there"
    exit 1
}
[ -f "$avf/RevenantAVCaptureControls18.h" ] || {
    echo "FAIL: $avf/RevenantAVCaptureControls18.h does not exist, so the class this run asks about is not declared"
    exit 1
}

# THE LIST IS BUILT FROM THE REGISTRY and the port's own header, never typed here: one line per class row,
# per protocol row, per method row and per property row of controls18.json, and for a property the
# SELECTOR THE HEADER DECLARES. `AVCaptureControl.enabled` is declared getter=isEnabled, so a list that
# asked -enabled would ask a selector neither side implements and would report the row equal without
# having asked anything. A property the header does not declare is reported rather than guessed at.
python3 - "$avf/CharonAVCaptureControls18.h" "$root/packages/a/apple-backports/registry/AVFoundation" \
        "$build/controls-list.tsv" <<'CONTROLSLIST'
import json, os, re, sys
header, registry, out = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(header).read()
# every property declaration in the header, with the accessor it names: @property(attrs) Type name;
declared = {}
for line in text.split("\n"):
    if "@property" not in line:
        continue
    attributes = line.split("@property", 1)[1]
    getter = re.search(r"getter=(\w+)", attributes)
    # What is left of the declaration once the attribute list is taken off is `<Type> <name>;`, so the name
    # is its LAST identifier. Taking the first is what the attribute list itself is, and a generic argument
    # (`NSArray<__kindof AVCaptureControl *> *controls`) is removed before the tokens are read, so the type
    # cannot be mistaken for the name.
    rest = attributes[attributes.index(")") + 1:] if "(" in attributes else attributes
    rest = rest.split("API_AVAILABLE")[0].split("API_UNAVAILABLE")[0]
    rest = re.sub(r"<[^<>]*>", " ", rest)
    tokens = re.findall(r"\b([A-Za-z_]\w*)\b", rest)
    if not tokens:
        raise SystemExit("cannot tell the property name on this line, so this run must not guess: " + line)
    name = tokens[-1]
    declared.setdefault(name, getter.group(1) if getter else name)
rows = []
classes, protocols = set(), set()
for name in sorted(os.listdir(registry)):
    if not name.startswith("controls") or not name.endswith(".json"):
        continue
    for entry in json.load(open(os.path.join(registry, name))).get("entries", []):
        if entry["kind"] == "class":
            classes.add(entry["api"])
            rows.append(("class", entry["api"], ""))
        elif entry["kind"] == "protocol":
            protocols.add(entry["api"])
            rows.append(("protocol", entry["api"], ""))
        elif entry["kind"] == "method":
            match = re.match(r"^([-+])\[([A-Za-z_]\w*) (.+)\]$", entry["api"])
            if not match:
                raise SystemExit("cannot read the sign, the owner and the selector of " + entry["api"])
            # a method of a protocol belongs to no class: it cannot be asked of one, and its declaration is
            # read out of the binary's metadata instead (see the probe's protocolmethod line)
            kind = "protocolmethod" if match.group(2) in protocols and match.group(2) not in classes else "member"
            rows.append((kind, match.group(2), match.group(1) + match.group(3)))
        elif entry["kind"] == "property":
            owner, member = entry["api"].split(".", 1)
            if member not in declared:
                raise SystemExit("%s is declared by no property in %s, so asking its name would ask a "
                                 "selector neither side has" % (entry["api"], header))
            rows.append(("member", owner, declared[member]))
with open(out, "w") as handle:
    for kind, first, second in rows:
        handle.write("%s\t%s\t%s\n" % (kind, first, second))
print("the controls probe is asked about %d classes, protocols and members, over %d accessor(s) the header "
      "names" % (len(rows), len(declared)))
CONTROLSLIST
# the protocol methods the probe must find on the port's protocol object, read out of the same registry
python3 - "$root/packages/a/apple-backports/registry/AVFoundation" "$build/controls-protocol.tsv" <<'CONTROLSPROTO'
import json, os, re, sys
registry, out = sys.argv[1], sys.argv[2]
expected = []
for name in sorted(os.listdir(registry)):
    if not name.startswith("controls") or not name.endswith(".json"):
        continue
    for entry in json.load(open(os.path.join(registry, name))).get("entries", []):
        match = re.match(r"^-\[AVCaptureSessionControlsDelegate (.+)\]$", entry["api"])
        if match:
            expected.append(match.group(1))
with open(out, "w") as handle:
    handle.write("".join(name + "\n" for name in sorted(expected)))
print("the registry names %d methods of AVCaptureSessionControlsDelegate" % len(expected))
CONTROLSPROTO
# THE PROLOGUE: the renamed class with its one property, and the stand-in owner of the renamed category.
# The property declaration is copied in because the copy's @synthesize-free accessors still need a
# declaration to sit in an @interface, and the category's members are NOT copied: the point of the phase
# is to ask the runtime what the port's own copy carries, not to have the harness declare it for the port.
python3 - "$avf/CharonAVCaptureControls18.h" "$build/src/controls-prologue.h" <<'CONTROLSPROLOGUE'
import re, sys
header, out = sys.argv[1], sys.argv[2]
text = open(header).read()
control = re.search(r"@interface\s+AVCaptureControl\s*:\s*NSObject(.*?)@end", text, re.S)
if not control:
    raise SystemExit("no @interface AVCaptureControl : NSObject in " + header)
category = re.search(r"@interface\s+AVCaptureSession\s+\((\w+)\)", text)
if not category:
    raise SystemExit("no @interface AVCaptureSession (category) in " + header)
lines = ["// Generated by tests/backports/host/avf-globals/run.sh from " + header + ": the port's own",
         "// AVCaptureControl with its name prefixed, and a stand-in owner for its category on AVCaptureSession,",
         "// which is Apple's class on this host and cannot carry the port's copy.",
         "//",
         "// The category keeps its name: clang refuses an @implementation whose category has no @interface, so a",
         "// category the port spells differently still fails to compile here rather than passing unnoticed.",
         "#import <Foundation/Foundation.h>",
         "#import <AVFoundation/AVFoundation.h>",
         "",
         "@interface revenant_host_AVCaptureControl : NSObject",
         control.group(1).rstrip(),
         "@end",
         "",
         "@interface revenant_host_AVCaptureSession : NSObject",
         "@end",
         "",
         "@interface revenant_host_AVCaptureSession (%s)" % category.group(1),
         "@end",
         ""]
open(out, "w").write("\n".join(lines))
print("the host build's prologue declares the port's renamed class and a stand-in for its category (%s)"
      % category.group(1))
CONTROLSPROLOGUE
# The stand-in's own OBJECT, in a source of its own and not in the prologue. The port's copy carries only
# the category, so nothing else defines the class and the link stops without it ("_OBJC_CLASS_$
# _revenant_host_AVCaptureSession, referenced from __OBJC_$_CATEGORY_..."), and a prologue that also
# implemented it would define it twice instead - once in each of the two copies it is prepended to.
{
    echo '#import "controls-prologue.h"'
    echo '@implementation revenant_host_AVCaptureSession'
    echo '@end'
} > "$build/src/controls-standin.rn"
# The protocol source, in the shape modules/apple/backports.lua writes from a protocol row: naming the
# protocol with @protocol(...) is what makes clang emit its metadata into the object. Without it the
# protocol object does not exist in this binary and the four protocol methods are not declared in the build
# that is being checked.
python3 - "$root/packages/a/apple-backports/registry/AVFoundation" "$build/src/controls-protocols.rn" <<'CONTROLSPROTOC'
import json, os, sys
registry, out = sys.argv[1], sys.argv[2]
names = []
for name in sorted(os.listdir(registry)):
    if not name.startswith("controls") or not name.endswith(".json"):
        continue
    for entry in json.load(open(os.path.join(registry, name))).get("entries", []):
        if entry["kind"] == "protocol" and entry["status"] == "implemented":
            names.append(entry["api"])
if not names:
    raise SystemExit("no implemented protocol row in the controls registry, so this run would declare none")
lines = ["// Generated by tests/backports/host/avf-globals/run.sh, in the shape modules/apple/backports.lua",
         "// writes for a library's protocol rows: every @protocol() named so clang emits",
         "// _OBJC_PROTOCOL_$_<name> into the object.",
         '#import "RevenantAVFoundationProtocols.h"',
         "",
         "static void revenant_avf_controls_protocols(void) __attribute__((used));",
         "static void revenant_avf_controls_protocols(void)",
         "{"]
lines += ["    (void)@protocol(%s);" % name for name in sorted(names)]
lines += ["}", ""]
open(out, "w").write("\n".join(lines))
print("the protocol source names %d protocol(s): %s" % (len(names), " ".join(sorted(names))))
CONTROLSPROTOC
# THE COPIES. Three rewrites, each on one line kind, and each asserted by the guard in the python below:
#   * the @implementation / @interface lines naming the port's own two classes get the prefix, anchored at
#     the start of the line, so the reason strings the port raises keep Apple's own spelling of the selector
#     - an unanchored rename would rewrite "*** -[AVCaptureSession %@] Controls are not supported" and the
#     comparison of the three refusals would then be a comparison of two different texts;
#   * the import of the port's Revenant header is DROPPED, because on this host its @interface
#     AVCaptureControl is a duplicate of the macOS SDK's own (measured: "duplicate interface definition for
#     class 'AVCaptureControl'") and its category would replace Apple's implementations in this process.
#     The prologue above is what the copy is compiled against instead.
if true; then
    src=$csource
    python3 - "$avf/$src" "$build/src/controls-prologue.h" "$build/src/controls.rn" <<'CONTROLSCOPY'
import re, sys
source, prologue, out = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(source).read()
drop = '#import "RevenantAVCaptureControls18.h"\n'
if text.count(drop) != 1:
    raise SystemExit("%s imports the Revenant header %d time(s), so this copy is not the one the harness "
                     "was written against" % (source, text.count(drop)))
text = text.replace(drop, "")
text, renamed = re.subn(r"^(@(?:implementation|interface)\s+)(AVCaptureControl\b|AVCaptureSession\b)",
                        r"\1revenant_host_\2", text, flags=re.M)
if renamed != 2:
    raise SystemExit("%s names %d of its own two classes at an @implementation/@interface line, and this "
                     "copy is written for exactly two" % (source, renamed))
# The prologue is prepended, not imported: the copy's own import of the port's header is dropped above, and
# what declares revenant_host_AVCaptureControl for it is here (the metric phase does the same, for the same
# reason: a renamed @implementation with no @interface behind it is a root class and stops the compile).
open(out, "w").write(open(prologue).read() + text)
print("the copy of %s is renamed (%d class line(s)), carries the prologue and no longer imports the port's "
      "own header" % (source, renamed))
CONTROLSCOPY
fi
cobjects=""
for pair in "controls.rn:controls.o" "controls-standin.rn:controls-standin.o" \
           "controls-protocols.rn:controls-protocols.o"; do
    src=${pair%%:*}; obj=${pair##*:}
    # -I"$build/src" for the stand-in, which imports controls-prologue.h by that name.
    if ! xcrun clang -fobjc-arc -w -x objective-c -I"$avf" -I"$avf_gen" -I"$build/src" -c "$build/src/$src" -o "$build/o/$obj" \
            > "$build/o/$obj.log" 2>&1; then
        echo "RUN FAILED: the port's $src did not build"
        head -8 "$build/o/$obj.log"
        exit 1
    fi
    [ -f "$build/o/$obj" ] || {
        echo "FAIL: $obj was not written, so the link below would measure nothing"; exit 1; }
    cobjects="$cobjects $build/o/$obj"
done
# The plant is applied AFTER the first compile, which is the only order the sha guard below can see
# anything in: a plant applied before it leaves the object identical to its own recompile, and the guard
# then refuses the run over a mutation that did happen - which is what it did on the first attempt here.
if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = controls ]; then
    # The mutation is on the port's OWN answer, where Apple's answer is measured and different: the port says
    # -supportsControls is NO because this hardware has no CaptureControls, and the plant makes it say YES.
    # A structural change (a missing selector) would go red too, but this one is the mistake this family can
    # actually make: a port that reports the capability of a newer release instead of the hardware it runs on.
    python3 - "$build/src/controls.rn" <<'PERTURB'
import sys
path = sys.argv[1]
text = open(path).read()
before = """- (BOOL)supportsControls
{
    return NO;
}"""
after = """- (BOOL)supportsControls
{
    return YES; /* PLANTED */
}"""
if text.count(before) != 1:
    raise SystemExit("the mutation target is not unique (%d matches), so this run proves nothing"
                     % text.count(before))
out = text.replace(before, after)
if out.count(before) != 0 or out.count(after) != 1:
    raise SystemExit("the mutation did not take, so this run proves nothing")
open(path, "w").write(out)
print("# the mutation applied: -supportsControls answers YES, where Apple answers NO here")
PERTURB
fi
if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = controls ]; then
    # REBUILD THE OBJECT THE PROBE LINKS and show that it is not the object that was there, which is what the
    # coding phase's "the plant never reached the linker" defect was: a rebuilt object nothing relinks is not
    # a rebuild.
    before=$(shasum -a 256 "$build/o/controls.o" | cut -d' ' -f1)
    if ! xcrun clang -fobjc-arc -w -x objective-c -I"$avf" -I"$avf_gen" -I"$build/src" -c "$build/src/controls.rn" \
            -o "$build/o/controls.o" > "$build/o/controls.o.log" 2>&1; then
        echo "RUN FAILED: the port's controls.rn did not build after the mutation"
        head -6 "$build/o/controls.o.log"
        exit 1
    fi
    after=$(shasum -a 256 "$build/o/controls.o" | cut -d' ' -f1)
    if [ "$before" = "$after" ]; then
        echo "FAIL: controls.o is byte-for-byte what it was before the mutation, so the probe below links the"
        echo "      same object and this mutation can never be noticed"
        exit 1
    fi
    echo "rebuilt controls.o after the mutation, and it differs: ${before%????????????????????????????????????????????????} -> ${after%????????????????????????????????????????????????}"
fi
# -I"$avf" -I"$avf_gen" because the probe declares the protocol itself, from the port's own header: without the
# declaration the @protocol conformance below has no protocol to conform to and the compile stops on
# "cannot find protocol declaration for 'AVCaptureSessionControlsDelegate'".
if ! xcrun clang -fobjc-arc -w -I"$avf" -I"$avf_gen" "$here/controls.m" $cobjects -framework Foundation -framework AVFoundation \
        -o "$build/controls" > "$build/controls.log" 2>&1; then
    echo "FAIL: the controls probe did not build"; head -14 "$build/controls.log"; exit 1
fi
"$build/controls" "$build/controls-list.tsv" > "$build/controls.table" 2> "$build/controls.stderr" || {
    echo "FAIL: the controls probe did not run"; head -10 "$build/controls.stderr"; exit 1; }

ccontrol() {
    line=$(grep "^CONTROL	$1	" "$build/controls.table" | cut -f3 || true)
    [ -n "$line" ] || { echo "FAIL: the controls control $1 printed nothing, so the run examined nothing"; exit 1; }
    case "$2" in
        ABSENT) [ "$line" = ABSENT ] || { echo "FAIL: control $1 answered [$line], expected ABSENT"; exit 1; } ;;
        HAS) case "$line" in HAS*|yes) : ;; *) echo "FAIL: control $1 answered [$line], expected HAS"; exit 1; ;; esac ;;
        YES) case "$line" in HAS*|yes) : ;; *) echo "FAIL: control $1 answered [$line], expected yes"; exit 1; ;; esac ;;
        [0-9]*) [ "$line" = "$2" ] || { echo "FAIL: control $1 answered [$line], expected $2"; exit 1; } ;;
        *) echo "FAIL: no expectation given for control $1"; exit 1 ;;
    esac
    echo "ok  control $1 = $line"
}
ccontrol AVCaptureNoSuchClass ABSENT
ccontrol AVCaptureControl HAS
ccontrol "-\[AVCaptureControl isEnabled\]" YES
ccontrol revenant_host_AVCaptureControl HAS
ccontrol revenant_host_AVCaptureSession HAS
cline=$(grep "^CONTROL	AVCaptureSessionControlsDelegate	" "$build/controls.table" | cut -f3 || true)
case "$cline" in
    "port=HAS"*) echo "ok  control AVCaptureSessionControlsDelegate = $cline" ;;
    *) echo "FAIL: the port carries no AVCaptureSessionControlsDelegate protocol object ($cline)"; exit 1 ;;
esac
ccontrol "AVCaptureSessionControlsDelegate conformed" YES
# The four methods, read out of THIS BINARY's own Objective-C metadata with the repository's own reader, and
# compared against the registry's own protocol-method rows. Not out of the runtime: protocol_
# copyMethodDescriptionList + sel_getName takes the process down with SIGSEGV on this release (measured on
# Apple's own NSObject protocol, on its first required method), because a protocol's method list holds
# selector references the runtime has not registered. tools/corpus/objc-inventory.lua is what the registry
# check reads too, so this is the metadata the gate would see.
cpdeclared=$(wc -l < "$build/controls-protocol.tsv" | tr -d ' ')
if ! REVENANT_ROOT="$root" xmake l tools/corpus/objc-inventory.lua "$build/controls" arm64 \
        > "$build/controls-metadata.tsv" 2> "$build/controls-metadata.log"; then
    echo "FAIL: the Objective-C metadata of the probe binary could not be read"
    head -5 "$build/controls-metadata.log"
    exit 1
fi
prow=$(grep '^protocol	AVCaptureSessionControlsDelegate	' "$build/controls-metadata.tsv" | head -1)
if [ -z "$prow" ]; then
    echo "FAIL: this binary's own metadata carries no AVCaptureSessionControlsDelegate protocol, so the four"
    echo "      methods are not declared in the build that was checked"
    grep '^protocol	' "$build/controls-metadata.tsv" | head -8
    exit 1
fi
cpcarried=$(printf '%s\n' "$prow" | cut -f5 | tr ',' '\n' | sed 's/^-//' | sort | tr '\n' ' ')
missing=""
extra=""
while IFS= read -r selector; do
    [ -n "$selector" ] || continue
    case " $cpcarried " in *" $selector "*) : ;; *) missing="$missing $selector" ;; esac
done < "$build/controls-protocol.tsv"
for selector in $cpcarried; do
    # the tsv holds the bare selector, the reader's own field the leading - that apple.objc stores every
    # instance selector with
    grep -qx -- "$selector" "$build/controls-protocol.tsv" || extra="$extra $selector"
done
if [ -n "$missing" ] || [ -n "$extra" ]; then
    echo "FAIL: this binary's protocol declares:$cpcarried"
    echo "      the registry names:$missing (absent from the binary)$extra (in the binary, not in the registry)"
    exit 1
fi
echo "ok  this binary's own metadata declares the $cpdeclared methods of AVCaptureSessionControlsDelegate"
echo "    the registry names, and no others: $cpcarried"

cabsent=$(grep '^CLASS	' "$build/controls.table" | awk -F'	' '{split($3,p,"="); if (p[2]=="ABSENT") print $2}' | tr '\n' ' ')
cdiffer=$(grep -c '	DIFFERENT$' "$build/controls.table" || true)
cclasses=$(grep -c '^CLASS	' "$build/controls.table" || true)
cmembers=$(grep -c '^RESPONDS	' "$build/controls.table" || true)
chostlacks=$(grep '^RESPONDS	' "$build/controls.table" | grep -c 'host=no' || true)
cportlacks=$(grep '^RESPONDS	' "$build/controls.table" | grep -c 'port=no' || true)
# The join on the ANSWER rows, host column against port column. The two rows whose value no macOS caller may
# ask for are excluded by name and checked separately below, so nothing is compared that was not asked of
# both sides.
: > "$build/controls-diff.log"
grep '^ANSWER	' "$build/controls.table" | grep -v 'configuresApplicationAudioSessionToMixWithOthers' | \
    while IFS=$(printf '\t') read -r kind label host port; do
        # the two columns are named in the row, so the prefixes come off before the comparison: left in
        # place, "host=[0]" and "port=[0]" are two different strings and every row differs, which is what
        # this join did on its first run.
        host=${host#host=}
        port=${port#port=}
        if [ "$host" != "$port" ]; then
            printf 'DIFFERS\t%s\t%s\t%s\n' "$label" "$host" "$port" >> "$build/controls-diff.log"
        fi
    done
canswerdiffers=$(grep -c '^DIFFERS	' "$build/controls-diff.log" || true)
canswers=$(grep -c '^ANSWER	' "$build/controls.table" || true)
cskipped=$(grep -c '^SKIPPED	' "$build/controls.table" || true)
# every protocol-method row the registry names has to be one of the SKIPPED lines, or a row would be dropped
# from the run without anything saying so
if [ "$cskipped" != "$cpdeclared" ]; then
    echo "FAIL: the registry names $cpdeclared protocol methods and the run looked at $cskipped of them"
    exit 1
fi

if [ "$mutant" != 0 ] && [ "$control" = 0 ] && [ "$kind" = controls ]; then
    if [ "$canswerdiffers" = 0 ] && [ "$cdiffer" = 0 ]; then
        echo "FAIL: the mutation left every answer equal, so this check cannot fail and proves nothing"
        exit 1
    fi
    echo "ok  the mutation was noticed: $canswerdiffers answer row(s) and $cdiffer hierarchy row(s) differ"
    head -6 "$build/controls-diff.log"
    exit 0
fi
if [ "$mutant" != 0 ] && [ "$control" != 0 ] && [ "$kind" = controls ]; then
    if [ "$canswerdiffers" != 0 ] || [ "$cdiffer" != 0 ]; then
        echo "FAIL: the control is not clean: $canswerdiffers answer row(s) and $cdiffer hierarchy row(s)"
        echo "      differ through the identical path, so the red would be the path and not the mutation"
        head -6 "$build/controls-diff.log"
        exit 1
    fi
    echo "ok  the control is clean: the unmutated controls objects through the identical build-and-run path"
    exit 0
fi

if [ -n "$cabsent" ]; then
    echo "FAIL: the port does not define these classes its own registry rows name: $cabsent"
    exit 1
fi
if [ "$cdiffer" != 0 ]; then
    echo "FAIL: the port's hierarchy differs from the host's on $cdiffer row(s)"
    grep '	DIFFERENT$' "$build/controls.table" | head -12
    exit 1
fi
if [ "$chostlacks" != 0 ] || [ "$cportlacks" != 0 ]; then
    echo "FAIL: a member the two sides are both asked about is missing from one of them: $chostlacks host, $cportlacks port."
    echo "      The claim this phase makes is that the port carries what Apple's own class carries."
    grep '^RESPONDS	' "$build/controls.table" | grep -e 'host=no' -e 'port=no' | head -12
    exit 1
fi
if [ "$canswerdiffers" != 0 ]; then
    echo "FAIL: the port's answers differ from Apple's own on $canswerdiffers of the rows both sides were asked"
    head -12 "$build/controls-diff.log"
    exit 1
fi
# The two port-only rows: the property the host's header marks unavailable, checked against the header's own
# documented default and against what a second session of the same class answers, so "it keeps the value"
# is a measurement and not an assumption.
cdefault=$(grep '^ANSWER	-configuresApplicationAudioSessionToMixWithOthers default	' "$build/controls.table" | cut -f3 || true)
[ "$cdefault" = "port=[0]" ] || {
    echo "FAIL: the port's configuresApplicationAudioSessionToMixWithOthers answered [$cdefault] before"
    echo "      anything set it, and the header's own default is NO (AVCaptureSession.h:583)"
    exit 1
}
cafter=$(grep '^ANSWER	-configuresApplicationAudioSessionToMixWithOthers after YES	' "$build/controls.table" | cut -f3 || true)
case "$cafter" in
    "port=[1 on the session, 0 on a second one]") : ;;
    *) echo "FAIL: after -setConfiguresApplicationAudioSessionToMixWithOthers: YES the port answered [$cafter],"
       echo "      which is not a value it kept for that session alone"; exit 1 ;;
esac
echo "ok  the mix-with-others flag keeps its value per session (default NO, the header's own), and Apple's"
echo "    value for it is not asked: API_UNAVAILABLE(macos) on this host"
echo "ok  $cclasses class row(s) resolve on both sides with the same superclass, and $cmembers members were"
echo "    asked of both ($cskipped of them belong to a protocol and were read out of the metadata above)"
echo "ok  $canswers answers agree with Apple's own class on this host, exception names and reasons included"

log=$build
exit 0
