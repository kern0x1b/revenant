#!/bin/sh
# The case files and record.m, run once against the host's own MLCompute and once against the port's own
# translation units, with every name the port defines renamed so both answers can be in one process tree.
# The host's answers are what the port is held to; run.sh says nothing about whether they are right, and
# facts/MLCompute/ carries what was measured and where it came from.
#
# The names come from the port's own sources, not from a list kept here, so a class the port adds is
# renamed too.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${MLCOMPUTE_PORT:-$here/../../../../packages/a/apple-backports/MLCompute}
registry=${MLCOMPUTE_REGISTRY:-$here/../../../../packages/a/apple-backports/registry/MLCompute}
build=${MLCOMPUTE_BUILD:-$(runs_folder charon-mlcompute-host)}
# The engine the port's own MLCInferenceGraph computes its forward pass with, built by the one script both
# MLCompute harnesses use and kept beside $build rather than inside it, so the rm below does not throw it away
# and a second run does not build it again. The release build compiles the engine's five C units for armv7
# and needs no C++ runtime; this is the harness only.
engine=${MLCOMPUTE_ENGINE_BUILD:-$(runs_folder charon-mlcompute-engine-host)}
rm -rf "$build"
mkdir -p "$build"
sdk=$(xcrun --show-sdk-path)
common="-target arm64-apple-ios15.0-macabi -isysroot $sdk -fobjc-arc -w -I$here"
libs="-framework Foundation -framework Accelerate"
ggmlhost=$(sh "$here/ggml-host.sh" "$engine")
ggml=${MLCOMPUTE_GGML:-$(ls -td "$HOME"/.xmake/packages/g/ggml/0.25.3/*/ 2>/dev/null | head -1 | sed "s:/$::")}
# The port's own translation units, the engine's archive and the engine's header: CharonMLCGraph.mm is where
# the port computes, so a case that asks the port what an execute computed is asking the port's arithmetic.
portsources() {
    printf '%s' "$port/MLCTypes14.m $port/MLCDevice15.m $port/MLCTensors14.m $port/MLCDescriptors14.m \
$port/MLCLayers14.m $port/MLCOptimizers14.m $port/MLCOptimizers15.m $port/MLCAdamAMSGrad15.m \
$port/MLCGraph14.m $port/MLCInferenceGraph14.m $port/MLCTrainingGraph14.m $port/MLCGraphConstants15.m \
$port/CharonMLCGraph.mm"
}

# Every MLC name the port's own sources define, taken from the sources so that nothing can be added to one
# and missed here. The classes come from the @interface and @implementation lines and the functions from the
# definitions; the enumerations are header values with no symbol, and are renamed by the same list so a
# case may name one of them.
python3 - "$port" "$build/rename.h" <<'PY'
import os, re, sys
port, out = sys.argv[1], sys.argv[2]
names = set()
classes = re.compile(r"^@(?:interface|implementation)\s+(MLC\w+)", re.M)
functions = re.compile(r"^(?:NSString \*|NSUInteger|void|BOOL)\s+(MLC\w+)\(", re.M)
for entry in sorted(os.listdir(port)):
    if not entry.endswith((".m", ".h")):
        continue
    text = open(os.path.join(port, entry)).read()
    names.update(classes.findall(text))
    names.update(functions.findall(text))
    names.update(re.findall(r"^\s*(MLC\w+),?$", text, re.M))     # the enumerations of a case list
    names.update(re.findall(r"\b(MLCDataType\w+|MLCPoolingType\w+)\b", text))
# The port's own private names never collide with the framework's and are not renamed.
with open(out, "w") as handle:
    for name in sorted(names):
        handle.write("#define %s Charon%s\n" % (name, name))
print("renamed %d names" % len(names))
PY

# The system side: the host's framework answers every case.
xcrun clang $common "$here/record.m" "$here/cases.m" "$here/layer-cases.m" "$here/optimizer-cases.m" "$here/graph-cases.m" "$here/inference-cases.m" $libs -framework MLCompute -o "$build/system"
"$build/system" > "$build/system.log" 2>&1 || { echo "the system run failed:"; tail -20 "$build/system.log"; exit 1; }

# The port side: the same program with the port's own files, which answer every case in their place. A
# Metal device does not exist for the port to name, so the cases that ask MLCDevice about a GPU get the
# answer a machine with no GPU gives; the run.sh notes those lines below as the ones that are meant to
# differ, and they are the only ones.
xcrun clang $common -include "$build/rename.h" -I"$port" -I"$ggml/include" "$here/record.m" "$here/cases.m" \
    "$here/layer-cases.m" "$here/optimizer-cases.m" "$here/graph-cases.m" "$here/inference-cases.m" \
    $(portsources) "$ggmlhost" $libs -lc++ -o "$build/port"
"$build/port" > "$build/port.log" 2>&1 || { echo "the port run failed:"; tail -20 "$build/port.log"; exit 1; }

# The red control: the same program and the same objects with every optimizer default one step off, which
# is what a default nobody measured looks like. It exists because a comparison that cannot see a wrong
# number is not a comparison: -DCHARON_MLC_PLANT is compiled into CharonMLCOptimizerState's initialiser in
# MLCompute/MLCOptimizers14.m and into nothing else, so a build of the library carries no plant.
xcrun clang $common -DCHARON_MLC_PLANT=1 -include "$build/rename.h" -I"$port" -I"$ggml/include" "$here/record.m" \
    "$here/cases.m" "$here/layer-cases.m" "$here/optimizer-cases.m" "$here/graph-cases.m" \
    "$here/inference-cases.m" $(portsources) "$ggmlhost" $libs -lc++ -o "$build/port-plant1"
"$build/port-plant1" > "$build/port-plant1.log" 2>&1 || { echo "the planted port run failed:"; tail -20 "$build/port-plant1.log"; exit 1; }
plant_wrong=$(diff "$build/system.log" "$build/port-plant1.log" | grep -c '^<' || true)
if [ "$plant_wrong" -lt 1 ]; then
    echo "the red control did not fire: the planted build printed exactly what the system printed"
    exit 1
fi
echo "red control: the planted build differs from the host in $plant_wrong cases"

# The names of the two must be the same set, not merely the same number: a case answered by one side and
# not by the other, with a different case elsewhere making the counts even, is a case that is not being
# checked. The two sets are compared by name.
cut -f1 "$build/system.log" | sort > "$build/system.keys"
cut -f1 "$build/port.log" | sort > "$build/port.keys"
if ! diff -q "$build/system.keys" "$build/port.keys" > /dev/null; then
    echo "the two runs did not answer the same cases:"
    diff "$build/system.keys" "$build/port.keys" | head -20
    exit 1
fi
# The cases whose answer is about hardware this release has none of, and which are therefore meant to
# differ. A GPU through Metal and the Neural Engine: the host has both, the port has neither, and each side
# answers as a machine with what it has. The cases record the difference rather than hide it, and the facts
# say what the port answers and why.
# Only the three that really differ, so what is printed is true: the framework has a Metal device and
# a Neural Engine and this release has neither, and each side answers as a machine with what it has.
# The CPU device, a device for "any", a copy of one and the empty device list are answered the same way
# by both: they are in the cases and they are compared like any other.
names="gpuDevice|aneDevice|deviceWithType GPU"
allowed="^($names)$"
tab=$(printf '\t')
diffout=$(diff "$build/system.log" "$build/port.log" || true)
system_only=$(echo "$diffout" | grep "^<" | sed "s/^< //" || true)
# Both sides of the diff, not only the left one: a case the port answered and the host did not is as much a
# divergence as the other way round, and looking at one side alone passed it.
port_only=$(echo "$diffout" | grep "^>" | sed "s/^> //" || true)
unexpected=$(printf '%s\n%s\n' "$system_only" "$port_only" | cut -f1 | grep -v -E "$allowed" | grep -v '^$' || true)
if [ -n "$unexpected" ]; then
    echo "the port answers differently where it should not:"
    echo "$unexpected" | while IFS= read -r name; do
        printf '%s\n%s\n' "$system_only" "$port_only" | grep -F "$(printf '%s\t' "$name")"
    done | head -40
    echo "log=$build/system.log $build/port.log"
    exit 1
fi
echo "the port answers as the host does on every case that is not about hardware this release lacks"
echo "the cases that differ, and are meant to:"
echo "$system_only" | grep -E "^($names)${tab}" | sed "s/^/  system /" | head -20
echo "$diffout" | grep "^>" | sed "s/^> //" | grep -E "^($names)${tab}" | sed "s/^/  port   /" | head -20
echo "cases=$(grep -c "	" "$build/system.log") log=$build/system.log"

