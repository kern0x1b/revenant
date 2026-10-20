#!/bin/sh
# run.sh — the Core ML host differential: what this host's own Core ML answers for a set of real
# .mlmodel containers is recorded, the port's classes are then compiled under names of their own
# (Revenant<name>) over the port's own reader and interpreter, held to the same record, and each
# difference is either fixed in the port or written down. Mutants of the port each have to be
# caught, so a rule that quietly stops being applied cannot pass.
#
# No container is a recorded divergence: nn_image was one until 2026-10-03, and its cause was this
# port applying the network's own scaler to an array input, which neither Core ML nor coremltools
# does. facts/CoreML/CoreML.md carries the measurement. COREML_DIVERGENT still names a container
# whose prediction numbers are a recorded divergence, for whoever finds the next one.
set -eu
echo "FAIL host/coreml/run.sh: its Python steps are gone and not yet ported to Lua: the inline block PY at line 65; the inline block PY at line 99; the inline block PY at line 268" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
root=$(cd "$here/../../../.." && pwd)
coreml=${COREML:-$root/packages/frameworks/apple-backports/CoreML}
registry=${REGISTRY:-$root/packages/frameworks/apple-backports/registry/CoreML}
models=${MODELS:-$(xmake l "$root/modules/workspace.lua" run coreml-predict)/models}
build=${BUILD:-$(runs_fresh revenant-coreml)}
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -fobjc-arc -w -Wno-unguarded-availability"
libs="-framework Foundation -framework CoreGraphics -framework CoreVideo -framework CoreML"

# THE CORPUS, and it decides the verdict. tools/coreml/make-models.lua writes TEN containers:
# glm, glm_classifier, nn_classifier, nn_embedding, nn_image, nn_layers, nn_layers_shape, pipeline,
# tree_classifier, vision_image, and this host's Core ML loads and compares all ten.
#
# It did not, until 2026-10-03, and the reason was the container rather than the host: vision_image
# declared its picture input as an `imageSizeRange` of 16..256, and Core ML's own compiler refuses
# that here - "+[MLModel compileModelAtURL:error:] answers com.apple.CoreML/0, 'compiler error:
# Invalid height and width for the image input.'" - so the release had no answer for it and the 48
# keys the port answers had nothing to be compared against. A ranged image input needs a network
# with flexible blob shapes and this one has fixed shapes; with `width`/`height` = 32 on both ends
# the same network compiles and loads (measured on this host, an M4 Pro, Core ML and Vision both
# present). The count is printed on every run so the corpus a verdict belongs to is never a guess.
echo "corpus: $(ls "$models" | grep -c '\.mlmodel$') containers in $models"

# The containers are made HERE, not asked for, for the reason the vision harness now does the same:
# a fresh worktree had none, this test stopped with the command to run printed at the reader, and the
# sweep - which looks for a run.sh that reaches a check - counted the whole family DEAD. The writer is
# this repository's own and takes a second.
if [ ! -d "$models" ]; then
    echo "no containers in $models: writing them with tools/coreml/make-models.lua"
    xmake l "$root/tools/coreml/make-models.lua" --out "$models" > "$build/models.log" 2>&1 || {
        echo "FAIL: the containers could not be written, so there is nothing to record:"
        tail -3 "$build/models.log" | sed 's/^/    /'; exit 1; }
fi
if [ ! -d "$models" ]; then
    echo "no containers in $models, and the writer left none: nothing to record"
    exit 1
fi

# 1. what the system's own Core ML answers. COREML_HOST tells the cases file to compile each
#    container with the framework's own compiler first: this host refuses to read an uncompiled
#    .mlmodel, and the two runs below are of one model in the two forms each framework reads.
xcrun clang $common -DCOREML_HOST=1 -I"$here" "$here/record.m" "$here/cases.m" "$here/devices-cases.m" $libs -o "$build/system"
COREML_RECORDS="$build/system.json" "$build/system" "$models"

# 2. the same questions of the port, with every Core ML name it answers behind a Revenant prefix so
#    that the two sets of classes can sit in one binary. The registry says which names those are:
#    the classes and protocols this port carries, and the constants it exports -- a constant the
#    port also defines would be a duplicate of the framework's own.
python3 - "$registry" "$build/rename.h" <<'PY'
import glob, json, os, sys
names = set()
for path in glob.glob(os.path.join(sys.argv[1], "*.json")):
    for entry in json.load(open(path))["entries"]:
        if entry["kind"] in ("class", "protocol", "constant", "function"):
            names.add(entry["api"].replace("()", ""))
with open(sys.argv[2], "w") as out:
    for name in sorted(names):
        out.write("#define %s Revenant%s\n" % (name, name))
PY

# Compiles the port from the sources in $1 -- the whole package, its C files and the generated
# table as well as its Objective-C -- and writes the binary into $2. A mutant is a copy of the whole
# tree, so a mutant of a .c, a .h or a .m is really compiled; taking the C from the pristine tree
# would make the whole mutant layer vacuous, because the binary would be the pristine one whatever
# the copy says, and `mutants surviving: 0` would be a line that cannot fail.
port() {
    src=$1
    dir=$2
    mkdir -p "$dir"
    xcrun clang $common -include "$build/rename.h" -I"$here" -I"$src" \
        "$here/record.m" "$here/cases.m" "$here/devices-cases.m" \
        "$src"/RevenantML*.c "$src"/*.m $libs -o "$dir/run"
}
mkdir -p "$build/port"
port "$coreml" "$build/port"
COREML_RECORDS="$build/port.json" "$build/port/run" "$models"

# 3. the comparison: every key must be in both files, and must hold the same value, except the
#    numbers of the prediction of a container that is a recorded divergence, and the keys of a
#    container the release itself refused to load.
# COREML_DIVERGENT names a container whose prediction numbers are a recorded divergence and is empty
# by default: there is none, since nn_image's cause was found and fixed (see facts/CoreML/CoreML.md).
COREML_DIVERGENT=${COREML_DIVERGENT:-} python3 - "$build/system.json" "$build/port.json" "$build/verdict" <<'PY'
import json, os, sys
system, port = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
divergent = os.environ.get("COREML_DIVERGENT", "")
differences, missing, one_sided = [], [], []
# The keys whose answer is about hardware THIS RELEASE has none of, each named. iOS 6 has no Metal
# driver and no neural engine at all, so the port's list of compute devices holds the one unit it has,
# the CPU, where this host's holds a neural engine, a GPU and a CPU; and the two properties that read a
# device's own hardware answer what a device of this port's knows, which is nothing. Every other key of
# the family is compared like any other, and an allowance that stops being needed is a failure: a list
# nobody checks is a list that hides whatever it names.
HARDWARE = {
    "devices/all count": "the count of the compute devices this host has against the one this release has",
    "devices/all 0": "the first of them, which is a neural engine here and the CPU there",
    "devices/all 1": "the second of them, which only a host with a GPU or a neural engine has",
    "devices/all 2": "the third of them, which only a host with a GPU or a neural engine has",
    "devices/model count": "the same count, asked of MLModel",
    "devices/model 0": "the same first device, asked of MLModel",
    "devices/model 1": "the same second device, asked of MLModel",
    "devices/model 2": "the same third device, asked of MLModel",
    "devices/gpu listed metal device": "a GPU device's own Metal device, and this release has no Metal",
    "devices/ane listed core count": "a neural engine's own core count, and this release has no engine",
}
stale = [key for key in HARDWARE if key in system and key in port and system[key] == port[key]]
# The containers the release refused to load, read out of its own record rather than named here: one
# it refused has a model/<name>/error key and one it loaded has none. For such a container the release
# has no answer at all, so what the port answers for it is not compared against nothing, and it is not
# a port defect either: the measurement is that the release refuses this container, and what it says
# when asked is in facts/CoreML/CoreML.md. If it ever loads the container, these keys come back and are
# compared like any other - which is why the set is read out of the record and not spelled out.
refused = {key[len("model/"):-len("/error")]: system[key] for key in system
           if key.startswith("model/") and key.endswith("/error")}
for key in sorted(set(system) | set(port)):
    if key in system and key in port:
        if system[key] != port[key]:
            differences.append((key, system[key], port[key]))
        continue
    # A key of the shape every per-container key has: what was asked, of which container, of what.
    parts = key.split("/")
    container = parts[1] if len(parts) > 2 else ""
    one_sided.append((key, container, "the port" if key in system else "the release",
                      system.get(key, port.get(key))))
missing = [row for row in one_sided if row[1] not in refused and row[0] not in HARDWARE]
# A number may differ by the width of the type it is stored in: the host runs the same arithmetic
# on its own hardware, in float32, and the port's interpreter is measured against coremltools' own
# runtime to 1e-5 by tools/coreml/check-predict.sh. Here the tolerance is a float32's, and a number
# beyond it is still reported -- unless the container is one facts/CoreML/CoreML.md records as a
# divergence, whose whole point is that the two do not agree.
TOLERANCE = float(os.environ.get("COREML_TOLERANCE", "1e-3"))

def numeric(key, want, got):
    """A recorded value is one number or a comma-joined list of them, and it is compared number by
    number: a string that is not a number at all is not within a tolerance of anything."""
    left, right = str(want).split(","), str(got).split(",")
    if len(left) != len(right):
        return False
    for one, other in zip(left, right):
        try:
            if abs(float(one) - float(other)) > TOLERANCE:
                return False
        except ValueError:
            return False
    return True

informational, hard = [], []
for key, want, got in differences:
    # Recorded, in each case, by what the framework answered and not by how a key is spelled: the
    # numbers of the prediction of a container this port and this host are a measured divergence
    # apart, and a key the framework has no answer for -- it raised -- has nothing to compare
    # against. A prefix rule could not notice either of those ceasing to be true, and a rule that
    # exempts a prefix is a rule that hides a regression in whatever the prefix names.
    recorded = ((key.startswith("value/") and divergent and ("/" + divergent + "/") in key)
                or str(want).startswith("raised "))
    if key in HARDWARE:
        informational.append((key, want, got))
    elif recorded:
        informational.append((key, want, got))
    elif key.startswith("value/") and numeric(key, want, got):
        pass  # within the tolerance of the type, which is not a difference
    else:
        hard.append((key, want, got))
for key, want, got in hard:
    print("DIFF", key)
    print("  system", want[:300])
    print("  port  ", got[:300])
for key, container, side, value in missing:
    print("MISSING", key, "- no answer on the side of", side)
    print("  the side that has it", value[:200])
for key, container, side, value in one_sided:
    if container in refused:
        print("one side only:", key, "- no answer on", side, "; the release refused", container,
              "with", repr(refused[container])[:120], "and answered nothing else for it")
for key, want, got in informational:
    if key in HARDWARE:
        print("hardware (this release has none of it):", key, "-", HARDWARE[key])
    else:
        print("divergent (recorded):", key)
    print("  system", want[:200])
    print("  port  ", got[:200])
for key, container, side, value in one_sided:
    if key in HARDWARE and side == "the release":
        print("hardware (this release has none of it):", key, "-", HARDWARE[key],
              "- and no answer on the port's side either")
for key in stale:
    print("STALE ALLOWANCE", key, "- both sides now answer", repr(system[key])[:120],
          "so the difference this release's hardware causes is gone and the allowance must go with it")
unanswered = len(one_sided) - len(missing)
print("compared %d keys, %d differ, %d missing, %d recorded divergences, %d for a container the release refused"
      % (len(set(system) | set(port)), len(hard), len(missing), len(informational), unanswered))
# The verdict is written where the rest of the run can read it instead of ending the script here.
# A red comparison used to raise SystemExit at this line, which is above the mutants: a test that was
# red for any reason never reached its controls, so a dead mutant could not be seen for as long as the
# comparison stayed red. The two verdicts are reported together and either one fails the run.
with open(sys.argv[3], "w") as out:
    out.write("differs\n" if hard or missing or stale else "same\n")
PY
verdict=$(cat "$build/verdict")
echo "comparison: $verdict"

# 4. mutants: each of these has to change the PORT's own record, or the rule it stands for is not
#    being applied. Not one is here: -[MLModel predictionFromFeatures:error:]'s skip of an undefined
#    value, which is the rule that keeps an optional input the caller left out from being sent as an
#    empty value. No container exercises it -- the specification's isOptional is not set on any
#    input of any model tools/coreml/make-models.lua writes -- so a mutant of it would survive for a
#    reason that is the corpus's and not the rule's. Writing a container with an optional input is
#    what puts it back, and it is the first thing the next round does.
#
# A mutant is CAUGHT when its record is not the pristine one, and the three ways of arriving are
# told apart and counted apart, because they are three different claims about the port and a single
# number cannot tell a reader which one was made:
#
#   differing  it ran and answered something else. This is the kill mutation testing wants.
#   aborted    it did not finish: killed by a signal or a non-zero exit. Counted caught, and only
#              because the two binaries differ by the mutation and by nothing else -- the pristine
#              build above wrote its own record and exited 0, and the guard below refuses to count
#              any mutant without it. A crash is a kill in mutation testing only when the mutation
#              is what crashes, so every aborting mutant is named on its own line here: an abort
#              that was the harness's own, or the corpus's, is visible instead of hidden behind
#              `|| true`. One used to be, and cases.m asked a ragged batch in a way that could only
#              answer; it is asked through @try now (7e3e8f77), so this run reports none.
#   did not build  the mutation did not compile, so the question was never asked. Counted as
#              surviving: a mutant that cannot run is not a caught mutant.
survived=0
ran=0
controls=0
differing=0
aborted=0
misfit=0
# The counting is refused without the pristine record to compare against, because then every
# mutant's record differs from nothing and all eighteen are caught for no reason at all.
[ -s "$build/port.json" ] || {
    echo "no pristine record at $build/port.json: every mutant would count as caught for no reason"
    exit 1
}
mutant() {
    file=$1
    from=$2
    to=$3
    expect=$4
    # A mutant declared `survived` is a control, not one of the rules: it is counted apart, because
    # a run that says "18 run, 0 surviving" and has quietly added a nineteenth that did survive
    # has said something false.
    if [ "$expect" = survived ]; then controls=$((controls + 1)); else ran=$((ran + 1)); fi
    rm -rf "$build/mutant"
    mkdir -p "$build/mutant"
    cp "$coreml"/*.m "$coreml"/*.h "$coreml"/RevenantML*.c "$coreml"/*.inc "$build/mutant/" 2>/dev/null || true
    # The mutation is counted before it is applied: `text.replace` on a needle the file does not
    # hold writes the file back unchanged and prints nothing, and a "planted" run over an
    # unplanted file then reports the mutant as applied (2026-10-03).
    python3 - "$build/mutant/$file" "$from" "$to" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path).read()
assert text.count(old) == 1, "%d occurrences of %r in %s" % (text.count(old), old, path)
open(path, "w").write(text.replace(old, new, 1))
PY
    outcome=planted
    # Every mutant is named before it runs, so a line the run prints after one of them -- the
    # shell's own report of a job killed by a signal -- belongs to a mutant the reader can see,
    # instead of leaving eighteen mutations to be counted by hand.
    echo "mutant: $file $from -> $to"
    if ! port "$build/mutant" "$build/mutant" 2>/dev/null; then
        outcome=unbuilt
    else
        rm -f "$build/mutant.json"
        status=0
        COREML_RECORDS="$build/mutant.json" "$build/mutant/run" "$models" > /dev/null 2>&1 || status=$?
        if [ "$status" -ne 0 ]; then
            outcome=aborted
            echo "mutant aborted: $file $from -> $to (exit $status, and no complete record of its own)"
        elif cmp -s "$build/port.json" "$build/mutant.json"; then
            outcome=same
        else
            outcome=differing
        fi
    fi
    case "$outcome" in
        differing|aborted) caught=yes ;;
        *) caught=no ;;
    esac
    # A control has to survive, and the run is red when it does not: that is the only thing here
    # which shows the comparison can report "same" at all, so without it "0 surviving" would be a
    # claim about these eighteen and about nothing else. A control is counted out of the rules'
    # numbers, so the eighteen below stay eighteen whatever a control does.
    if [ "$expect" = survived ]; then
        if [ "$caught" = yes ]; then
            echo "THE COUNTING IS BROKEN: a mutation that cannot change an answer was caught ($outcome): $file $from -> $to"
            misfit=$((misfit + 1))
        fi
        return 0
    fi
    case "$outcome" in
        differing) differing=$((differing + 1)) ;;
        aborted) aborted=$((aborted + 1)) ;;
    esac
    if [ "$caught" = no ]; then
        echo "MUTANT SURVIVED: $outcome: $file $from -> $to"
        survived=$((survived + 1))
    fi
}
mutant MLFeatureDescription.m "if (value.isUndefined) {
        return _optional;" "if (value.isUndefined) {
        return YES;" differing
mutant MLFeatureDescription.m "if (value.type != _type) {
        return NO;" "if (value.type == 12345) {
        return NO;" differing
mutant MLFeatureDescription.m "        if (_multiArrayConstraint.dataType != (MLMultiArrayDataType)0 &&" "        if (0 &&" differing
mutant RevenantMLConstraints.h "            if ([constraint.enumeratedShapes[index] isEqualToArray:shape]) {
                return YES;
            }" "            if (YES) {
                return YES;
            }" differing
mutant RevenantMLConstraints.h "        return [[MLMultiArrayShapeConstraint alloc] revenant_initWithType:MLMultiArrayShapeConstraintTypeEnumerated" "        return [[MLMultiArrayShapeConstraint alloc] revenant_initWithType:MLMultiArrayShapeConstraintTypeRange" differing
mutant MLModel.m "type = revenant_ml_feature_type_of(described->type);" "type = MLFeatureTypeDouble;" differing
mutant MLModel.m "answer = [self predictionFromFeatures:one options:options error:error];" "answer = nil;
        (void)options;" differing
mutant MLModel.m "revenant_ml_error(error, REVENANT_ML_ERROR_IO,
                        @\"a model is read from a file" "revenant_ml_error(error, REVENANT_ML_ERROR_GENERIC,
                        @\"a model is read from a file" differing
mutant MLParameter.m "return [[[self class] alloc] revenant_initWithName:name scope:nil];" "return [[[self class] alloc] revenant_initWithName:[name uppercaseString] scope:nil];" differing
mutant MLArrayBatchProvider12.m "        } else if ([dictionary[name] count] != count) {" "        } else if (0) {" differing
mutant MLFeatureProvider.m "        return [MLFeatureValue featureValueWithInt64:[object longLongValue]];" "        return [MLFeatureValue featureValueWithDouble:[object doubleValue]];" differing
mutant MLFeatureProvider.m "    if ([object isKindOfClass:[NSArray class]]) {" "    if (0) {" differing
mutant MLFeatureValue.m "    if (_type != MLFeatureTypeInt64 || _value.kind != REVENANT_ML_VALUE_NUMBER) {" "    if (_value.kind != REVENANT_ML_VALUE_NUMBER) {" differing
mutant MLFeatureValue.m "    if (_value.kind != REVENANT_ML_VALUE_STRING) {
        return nil;
    }" "    if (_value.kind == REVENANT_ML_VALUE_NONE) {
        return nil;
    }" differing
mutant MLFeatureValue.m "        _value = revenant_ml_value_string_copy(text.UTF8String, strlen(text.UTF8String));" "        _value = revenant_ml_value_string_copy(\"\", 0);" differing
mutant MLFeatureValue.m "    [coder encodeObject:self.multiArrayValue forKey:@\"array\"];" "    [coder encodeObject:nil forKey:@\"array\"];" differing
mutant MLFeatureValue.m "        _multiArray = array;" "        _multiArray = nil;" differing
mutant MLConstants.m '@"com.apple.CoreML"' '@"CoreML"' differing

# The control: a mutation that cannot change an answer, and the counting has to report it as
# surviving. "0 surviving" is a claim about the eighteen above, and a claim nothing can fail is
# not a claim -- this is the shape the HARDWARE allowance above already has, where an allowance
# that stops being needed fails the run. The change is a space after a colon in a call the port
# makes once per batch, so the file really is recompiled and the record really is compared: the
# compiler is given a different source and answers the same, which is what "cannot change an
# answer" has to mean for the test to be worth anything.
mutant MLArrayBatchProvider12.m "    providers = [NSMutableArray arrayWithCapacity:count];" "    providers = [NSMutableArray arrayWithCapacity: count];" survived

echo "mutants: $ran run, $survived surviving, $differing caught by a differing record, $aborted by an abort, $misfit out of turn"
echo "control: $controls run, and the one that cannot change an answer was reported as caught: $misfit (0 is the only answer that passes)"
if [ "$verdict" = differs ]; then
    echo "port: DIFFERS"
else
    echo "port: same as the system"
fi
[ "$verdict" = same ] && [ "$survived" -eq 0 ] && [ "$misfit" -eq 0 ]
