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
    runs_xmake l "$root/tools/coreml/make-models.lua" --out "$models" > "$build/models.log" 2>&1 || {
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
runs_xmake l "$runs_checkout/tests/backports/common/registry.lua" names "$registry" "$build/rename.h" class,protocol,constant,function

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
runs_xmake l "$here/compare.lua" "$build/system.json" "$build/port.json" "$build/verdict"
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
    runs_xmake l "$runs_checkout/tests/backports/common/mutants.lua" once "$build/mutant/$file" "$from" "$to"
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
