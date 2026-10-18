#!/bin/sh
# Host differential for the update of an updatable network. For each optimiser, the generated model is trained by
# the host's MLUpdateTask (host-train) and by the port's trainer (train-check), and the updatable weights of
# every event (training begin, each mini-batch end, each epoch end) and the final weights are compared.
#
# The loss the host reports is not compared: it is not the mean squared error, and no formula found so far
# reproduces it. The weights are the checked quantity.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
PORT=${COREML_UPDATE_PORT:-$here/../../../../packages/a/apple-backports/CoreML}
build=${COREML_UPDATE_BUILD:-$(runs_folder charon-coreml-update)}
# The bound on any weight or bias: this many float32 ulps of the largest weight in the host's dump of the event.
# A float32 ulp at a magnitude m is 2^(e - 23) for the exponent e of m, so the bound scales with the weights.
ULPS=4
samples=16
minibatch=4
epochs=2
seed=7

rm -rf "$build"
mkdir -p "$build"

cc -std=c11 -Wall -O1 -I"$PORT" -c "$PORT/CharonMLProto.c" -o "$build/proto.o"
cc -std=c11 -Wall -O1 -I"$PORT" -c "$PORT/CharonMLSchema.c" -o "$build/schema.o"
cc -std=c11 -Wall -O1 -I"$PORT" -c "$PORT/CharonMLTrain.c" -o "$build/train.o"
cc -std=c11 -Wall -O1 -I"$PORT" -o "$build/gen" "$here/gen.c" -lm
cc -std=c11 -Wall -O1 -I"$PORT" -I"$here" -o "$build/train-check" "$here/train-check.c" \
    "$build/train.o" "$build/proto.o" "$build/schema.o" -lm
xcrun clang -fobjc-arc -Wall -framework Foundation -framework CoreML "$here/host-train.m" -o "$build/host-train"

cat > "$build/compare.awk" <<'AWK'
# Reads the host's dump (the first file) and the port's dump. Prints the largest absolute difference among the
# numbers, in float32 ulps of the largest weight of the host's dump, and exits non-zero when that difference is
# above ulps ulps or when the two dumps differ in shape or in a word. The bound is at the magnitude of the host's
# largest weight, so a weight of any size gets the same number of ulps.
FNR == NR {
    for (i = 1; i <= NF; i++) {
        a[FNR, i] = $i
        if (i > 2 && $i ~ /^[-+.0-9e]+$/) { v = $i < 0 ? -$i : $i; if (v > mag) mag = v }
    }
    na[FNR] = NF; lines = FNR; next
}
{
    if (FNR > lines || NF != na[FNR]) { print "shape differs at line " FNR; bad = 1; next }
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^[-+.0-9e]+$/) {
            d = $i - a[FNR, i]; if (d < 0) d = -d
            if (d > max) max = d
        } else if ($i != a[FNR, i]) { print "word differs at line " FNR; bad = 1 }
    }
    seen = FNR
}
END {
    if (seen != lines) { print "line count differs"; bad = 1 }
    if (mag == 0) mag = 1
    e = log(mag) / log(2)
    if (e != int(e) && e < 0) e = int(e) - 1; else e = int(e)
    ulp = 2 ^ (e - 23)
    printf "max abs diff %.3g = %.2f ulp (largest weight %.4g, bound %d ulp)", max + 0, (max + 0) / ulp, mag, ulps
    exit (bad || max + 0 > ulps * ulp)
}
AWK

result=0
compare() {
    # $1 is the case directory: every host dump is compared with the port's dump of the same name
    case_dir=$1
    for host_dump in "$case_dir"/host/*.dump; do
        name=$(basename "$host_dump")
        if line=$(awk -v ulps="$ULPS" -f "$build/compare.awk" "$host_dump" "$case_dir/port/$name"); then
            echo "  $name: $line"
        else
            echo "  $name: outside the bound: $line"
            result=1
        fi
    done
}

case_run() {
    # $1 case name, $2 optimiser, $3.. the optimiser's numbers as gen takes them
    name=$1
    shift
    dir="$build/$name"
    mkdir -p "$dir/host" "$dir/port"
    "$build/gen" "$dir" "$@" $minibatch $epochs $samples $seed > "$dir/gen.log"
    "$build/host-train" "$dir/model.mlmodel" "$dir/input.f32" "$dir/target.f32" "$dir/host" $samples \
        > "$dir/host.log" 2>&1 || { echo "$name: host-train failed, see $dir/host.log"; result=1; return; }
    "$build/train-check" "$dir/model.mlmodel" "$dir/input.f32" "$dir/target.f32" "$dir/port" $samples \
        > "$dir/port.log" 2>&1 || { echo "$name: train-check failed, see $dir/port.log"; result=1; return; }
    echo "$name:"
    compare "$dir"
}

# SGD without a momentum, SGD with a momentum, and Adam with the default moments.
case_run sgd sgd 0.1 0.0 0.999 1e-8
case_run sgdm sgd 0.1 0.9 0.999 1e-8
case_run adam adam 0.01 0.9 0.999 1e-8

exit $result
