#!/bin/sh
# The CoreML interpreter, measured against the host's own Core ML: every container the reader
# check writes is run over a fixed input, and the values the port produces are compared with the
# ones Core ML on this host produced for the same model and the same input (predict-host.m, run
# by make-models.lua when it writes the containers).
#
# What it proves: that the arithmetic of the kinds of model under test -- a dense classifier,
# a convolutional one, a tree ensemble, a GLM, a pipeline, and each of the layers those reach
# -- is the arithmetic Core ML specifies. A model with no host input recorded (an image model
# this host has no image for) is listed and not compared, and the script fails if one that was
# meant to be compared was not.
#
# Usage: sh tools/coreml/check-predict.sh <directory for the run output>
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CORE=$ROOT/packages/a/apple-backports/CoreML
OUT=${1:-$ROOT/.agent-work/runs/coreml-predict}
CC=${CC:-clang}
CFLAGS="-std=c99 -Wall -Wextra -Wno-unused-parameter -O1 -fsanitize=address"
# The float an interpreter and a compiled runtime may differ by, and the same every time: a
# conv accumulates in a different order on the two, and float32 has seven digits of it.
TOLERANCE=${TOLERANCE:-1e-5}

mkdir -p "$OUT"
echo "interpreter check -> $OUT"

if [ ! -f "$OUT/models/manifest.json" ]; then
    xmake l "$ROOT/tools/coreml/make-models.lua" --out "$OUT/models"
fi

$CC $CFLAGS -I "$CORE" -o "$OUT/ml-predict" "$ROOT/tools/coreml/predict-main.c" \
    "$CORE"/CharonML*.c

# The inputs, by name and value, as the harness takes them. They are the same inputs
# make-models.lua recorded its predictions for, written here so a change to one of them is a
# diff rather than a silent disagreement. A model whose input is more than a flat vector of
# numbers is fed by the Lua side below, from the same samples make-models.lua records.
run_case() {
    name=$1
    shift
    printf '%s\n' "$name" > "$OUT/$name.actual"
    "$OUT/ml-predict" "$OUT/models/$name.mlmodel" "$@" >> "$OUT/$name.actual" 2>&1 || true
}

run_case glm --set x 2 -1.5 0
run_case glm_classifier --set x 2 0.5 -0.5
run_case nn_classifier --set x 3 0.5 -0.25 1.0
# The models whose input is a channels-first array: the shape is given, and the values follow.
run_case nn_layers --setr x 1x1x4 4 0.5 -1.5 2.0 0.25
run_case nn_layers_shape --setr x 1x1x2 2 0.5 -0.25
run_case pipeline --set x 1 2
run_case tree_classifier --set a 1 0.25 --set b 1 1.0

# The models whose input is not one flat vector (nn_embedding, nn_image) are run by the Lua
# checker, which also compares every answer with the manifest's.
xmake l "$ROOT/tools/coreml/check-predict.lua" "$OUT" "$TOLERANCE"
