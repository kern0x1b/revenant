#!/bin/sh
# run.sh — records what the system's Vision answers for every case of device/vision-cases.m in a Mac Catalyst binary, writes the answers
# where the device test reads them, then compiles the port's Vision classes under names of their own (Revenant<name>) and holds them to the
# same records, with mutants of the port that each have to be told apart.
set -eu
echo "FAIL host/vision/run.sh: its Python steps are gone and not yet ported to Lua: the inline block at line 73; the one-line step at line 109; the inline block PY at line 124; compare.py; the inline block PY at line 162" >&2
exit 1
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
vision=${VISION:-$here/../../../../packages/frameworks/apple-backports/Vision}
registry=${REGISTRY:-$here/../../../../packages/frameworks/apple-backports/registry/Vision/ios11.json}
# The Core ML containers the picture cases run against. Without them the picture cases are NOT
# SKIPPED, they are simply not there: the same command then records 37 keys instead of 45, still
# prints "port: same as the system", and lets the mutant of VNRequests.m that removes the wrapper's
# refusal survive -- so a missing corpus read as a defect in the port. It is a corpus, and a check
# that cannot see its cases must say so before it reports anything.
models=${MODELS:-$(runs_folder coreml-models-2)}
# resolved so the failure below names a path a reader can paste, and so the count does not depend on
# how the run was invoked
models=$(cd "$(dirname "$models")" 2>/dev/null && pwd)/$(basename "$models")
expected_records=45
# The containers the cases name. This is the same list device/vision-cases.m builds its URLs from,
# and it is checked here rather than inferred from the record: a container that is absent and a
# container that is present and cannot be run produce the same number of records and differ on ONE
# value (picture/error), and a run that is short a container must not be a run that passes. Kept in
# step with the case file by the sentence above, which is where a new container is added.
required="glm_classifier.mlmodel nn_image.mlmodel vision_image.mlmodel"
build=${BUILD:-$(runs_fresh revenant-vision)}
sdk=$(xcrun --show-sdk-path)
frameworks="-iframework $sdk/System/iOSSupport/System/Library/Frameworks"
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk $frameworks -fobjc-arc -w"
libs="-framework Foundation -framework CoreGraphics -framework CoreImage -framework CoreVideo -framework ImageIO -framework CoreML"

# The containers are made HERE, not asked for. tools/coreml/make-models.lua is this repository's own
# writer, one model per kind the port interprets, with the reference dump and the manifest the cases
# read, and it takes a second. This test used to stop with the command
# to run printed at the reader, which meant a fresh worktree guarded nothing at all: the sweep found
# no directory and called the test DEAD, and a person who ran it by hand had to know to go and write
# the models first. Nothing outside the tree is needed and nothing is downloaded.
if [ ! -d "$models" ]; then
    echo "no Core ML containers in $models: writing them with tools/coreml/make-models.lua"
    xmake l "$here/../../../../tools/coreml/make-models.lua" --out "$models" > "$build/models.log" 2>&1 || {
        echo "FAIL: the containers could not be written, so the picture cases have nothing to read:"
        tail -3 "$build/models.log" | sed 's/^/    /'; exit 1; }
fi
if [ ! -d "$models" ]; then
    echo "no Core ML containers in $models"
    echo "the picture cases need them, and without them this run records $((expected_records - 8)) records instead of $expected_records and lets a mutant survive: write them with"
    echo "    xmake l $here/../../../../tools/coreml/make-models.lua --out $models"
    exit 1
fi
missing=""
for c in $required; do
    [ -f "$models/$c" ] || missing="$missing $c"
done
if [ -n "$missing" ]; then
    echo "the corpus is missing$missing, which the cases in $device/vision-cases.m name"
    echo "vision_image is the one a case EXPECTS to fail: it is expected to be PRESENT and to fail,"
    echo "and a corpus without it is short, not excused -- absent is not failing"
    exit 1
fi
echo "corpus: $(ls "$models" | grep -c '\.mlmodel$') Core ML containers in $models"
echo "corpus: every container the cases name is here: $required"

xcrun clang $common -I"$device" "$here/record.m" "$device/vision-cases.m" $libs -framework Vision -o "$build/system"
VISION_COREML_MODELS="$models" VISION_RECORDS="$build/system.json" "$build/system"
# A container the cases NAME and the corpus does not have. This is checked BEFORE the record is
# written into the committed file, so a corpus that is short a container cannot leave a different
# record behind: absent is not the same as a container that is present and fails, and the record is
# where the two look alike. vision_image is the one a case expects to fail -- it is expected to be
# PRESENT and to fail -- so a corpus without it is short, not excused.
absent=$(python3 -c "
import json
d = json.load(open('$build/system.json'))
print(' '.join(sorted(k[len('coreml.model.absent.'):] for k in d if k.startswith('coreml.model.absent.'))))
" 2>/dev/null || echo "")
if [ -n "$absent" ]; then
    echo "a case recorded a container of its own as absent: $absent, and the corpus check above passed"
    echo "a container that is expected to fail must be PRESENT and fail; absent is not failing, and the case records nothing for it"
    exit 1
fi

# The record goes to the run folder. The committed device/vision-expectations.h is written only by RECORD=1, an explicit
# mode, and a commit that changes that file names the reason: a plain run on this machine must not rewrite a tracked file.
record="$build/vision-expectations.h"
if [ "${RECORD:-}" = 1 ]; then
    record="$device/vision-expectations.h"
fi
xmake l "$here/../../common/embed.lua" "$build/system.json" "$record" foundation2_expectations
sed -i.bak 's/foundation2_expectations/vision_expectations/' "$record" && rm -f "$record.bak"
# The record may not carry this machine's home path, and the file is already written by the line above, so this is
# checked before anything reads it. It happened once: a case recorded failure.localizedDescription, which is a framework
# sentence naming the model's file URL, and the run went on to print a pass. The cases now record the error's domain and
# code instead; this is the check that says that is not enough on its own.
home=$(grep -c '/Users/' "$record" || true)
if [ "$home" != "0" ]; then
    echo "$record holds $home line(s) with this machine's home path in it"
    echo "a case is recording a framework message that names a file URL; record the error's domain and code instead"
    exit 1
fi
echo "no home path in $record"

recorded=$(runs_harness records "$build/system.json")
# A container the cases name failing to compile is a case going wrong. vision_image is the one they
# expect to fail -- this host's Core ML does not run an image model -- and it is listed, with its
# reason, in vision-cases.m beside the compile. Anything else that fails is recorded under
# coreml.compile.unexpected and fails here: a run that skips a case must not be a run that passes.
unexpected=$(python3 -c "import json; print(json.load(open('$build/system.json')).get('coreml.compile.unexpected',''))" 2>/dev/null || echo "")
if [ -n "$unexpected" ]; then
    echo "a container the cases name failed to compile, and no case expects it to: $unexpected"
    echo "the expected ones are listed with their reasons in $device/vision-cases.m, at compile_failure_expected"
    exit 1
fi

echo "records: $recorded of $expected_records expected"
if [ "$recorded" -lt "$expected_records" ]; then
    echo "this run recorded $recorded records and expected $expected_records: the picture cases did not all run, and everything below would compare a smaller record than the one the device test holds"
    echo "check the corpus above, then the cases in $device/vision-cases.m that are being skipped"
    exit 1
fi


python3 - "$registry" "$build/rename.h" <<'PY'
import json, sys
names = set()
for entry in json.load(open(sys.argv[1]))["entries"]:
    if entry["kind"] in ("class", "constant", "function"):
        names.add(entry["api"].replace("()", ""))
with open(sys.argv[2], "w") as out:
    for name in sorted(names):
        out.write("#define %s Revenant%s\n" % (name, name))
PY

port() {
    dir=$1
    xcrun clang $common -include "$build/rename.h" -I"$device" -I"$vision" "$here/record.m" "$device/vision-cases.m" \
        "$dir/RevenantVisionBilinear.c" "$dir/VNConstants.m" "$dir/VNObservations.m" "$dir/VNRecognizedObjectObservation.m" "$dir/VNRequests.m" "$dir/VNHandlers.m" $libs -o "$dir/run"
}
mkdir -p "$build/port"
cp "$vision"/*.c "$vision"/*.m "$vision"/*.h "$build/port/"
port "$build/port"
VISION_COREML_MODELS="$models" VISION_RECORDS="$build/port.json" "$build/port/run"
# Everything is compared, including the scores of a Core ML prediction: the model they come from is
# nn_image and this port's prediction of it was a recorded divergence apart until 2026-10-03, when
# the cause turned out to be the network's own scaler being applied to an array input
# (facts/CoreML/CoreML.md). compare.py has no exception left.
# The comparison's verdict is kept rather than ending the run: the mutants are below, and a red
# comparison used to exit here, so a red test never checked that its controls still fire. Both
# verdicts are reported and either one fails the run.
if python3 "$here/compare.py" "$build/system.json" "$build/port.json"; then verdict=same; else verdict=differs; fi
echo "comparison: $verdict"

# 4. mutants: each of these has to change the record, or the rule it stands for is not applied
survived=0
ran=0
mutant() {
    ran=$((ran + 1))
    file=$1; from=$2; to=$3
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$vision"/*.c "$vision"/*.m "$vision"/*.h "$build/mutant/"
    python3 - "$build/mutant/$file" "$from" "$to" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path).read()
assert old in text, old
open(path, "w").write(text.replace(old, new, 1))
PY
    port "$build/mutant"
    rm -f "$build/mutant.json"
    VISION_COREML_MODELS="$models" \
        VISION_RECORDS="$build/mutant.json" timeout 60 "$build/mutant/run" > /dev/null 2>&1 || true
    # Judged against the PORT's own record: the port already differs from this host on the recorded
    # divergences, so "mutant == system" can never hold and its failing is what would make every
    # mutant look killed whatever it did.
    if cmp -s "$build/port.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $file $from -> $to"; survived=$((survived + 1)); fi
}
mutant VNConstants.m "return CGPointMake(normalizedPoint.x * (double)imageWidth, normalizedPoint.y * (double)imageHeight);" "return CGPointMake(normalizedPoint.x * (double)imageHeight, normalizedPoint.y * (double)imageWidth);"
mutant VNConstants.m "x = imageRect.origin.x / (double)imageWidth;" "x = imageRect.origin.x / (double)imageHeight;"
mutant VNConstants.m "if (imageWidth) {" "if (imageWidth > 1) {"
mutant VNConstants.m "faceBoundingBox.origin.x * width + faceBoundingBox.size.width * width * (double)faceLandmarkPoint.x" "faceBoundingBox.size.width * width * (double)faceLandmarkPoint.x"
mutant VNConstants.m "faceBoundingBox.size.height * (double)imageHeight * (double)faceLandmarkPoint.y" "faceBoundingBox.size.height * (double)imageHeight * (double)faceLandmarkPoint.x"
mutant VNConstants.m 'VNBarcodeSymbology const VNBarcodeSymbologyQR = @"VNBarcodeSymbologyQR";' 'VNBarcodeSymbology const VNBarcodeSymbologyQR = @"QR";'
mutant VNConstants.m "return CGRectEqualToRect(normalizedRect, CGRectMake(0, 0, 1, 1));" "return normalizedRect.size.width == 1;"
mutant VNRequests.m "_minimumAspectRatio = 0.5f;" "_minimumAspectRatio = 0.4f;"
mutant VNRequests.m "_quadratureTolerance = 30;" "_quadratureTolerance = 45;"
mutant VNRequests.m "_maximumObservations = 1;" "_maximumObservations = 2;"
mutant VNRequests.m "_minimumSize = 0.2f;" "_minimumSize = 0.25f;"
mutant VNRequests.m "_trackingLevel = VNRequestTrackingLevelFast;" "_trackingLevel = VNRequestTrackingLevelAccurate;"
mutant VNRequests.m "_regionOfInterest = CGRectMake(0, 0, 1, 1);" "_regionOfInterest = CGRectMake(0, 0, 1, 0.5);"
mutant VNRequests.m "_imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;" "_imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFit;"
mutant VNRequests.m "_symbologies = [[self class] supportedSymbologies];" "_symbologies = @[];"
mutant VNRequests.m "copy->_results = nil;" "copy->_results = nil; copy->_usesCPUOnly = NO;"
mutant VNObservations.m "_confidence = 1;" "_confidence = 0.5f;"
mutant VNObservations.m "_requestRevision = requestRevision;" "_requestRevision = requestRevision + 1;"
mutant VNObservations.m "return [self observationWithRequestRevision:0 boundingBox:boundingBox];" "return [self observationWithRequestRevision:1 boundingBox:boundingBox];"
mutant VNObservations.m "return YES;" "return NO;"
mutant VNObservations.m "return revenant_vision_clone(self, zone);" "return [[VNObservation alloc] init];"
mutant VNRequests.m "    if ([wrapper revenant_coreml_image_feature] == nil) {" "    if (0) {"
# The wrapper's refusal, which is the host's own answer for every image model in the corpus and the
# one this mutant kills: a wrapper that answered for a model with no image in any of its inputs
# would be a difference the picture case would see.
mutant VNHandlers.m "VNErrorUnsupportedRevision" "VNErrorNotImplemented"
mutant VNHandlers.m "if (handler)
            handler(request, failure);" "if (handler)
            handler(request, nil);"
# NOT HERE, and named rather than left to fail the line: the two crop-and-scale rules in
# RevenantVisionImage.h, the Core ML branch of revenant_vision_perform, and the request path's own
# resampler. Every shape of an image model in the corpus is refused by the host's own Vision before
# the request path reaches a picture -- "Failed to initialize VNCoreMLTransformer" for the ranged
# and the preprocessed one, "The VNCoreMLTransform request failed" for the fixed one -- so the
# request is answered by the generic refusal and nothing under those rules is run. What would put
# them in a record is a container the host's transform accepts, which
# tools/coreml/make-models.lua has not found yet; the shapes it has tried are written down in
# facts/CoreML/CoreML.md. The crop-and-scale rules are measured against Core ML's own image constructor -- the
# oracle facts/Vision/Vision.md cites -- by comparing pixels, which is NOT yet a check in this
# tree: the review measured 1996 of 50176 pixels differing for 100x50 to 224x224 and 22 of 64 for
# 13x7 to 8x8 against a paste, and the interpolation quality in RevenantVisionImage.h is the change
# made for it, unverified here.
echo "mutants: $ran run, $survived surviving"

if [ "$verdict" = differs ]; then echo "port: DIFFERS"; else echo "port: same as the system"; fi
[ "$verdict" = same ] && [ "$survived" -eq 0 ]
