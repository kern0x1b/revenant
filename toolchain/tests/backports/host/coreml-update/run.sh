#!/bin/sh
# Host differential for the update of an updatable network. For each optimiser, the generated model is trained by the
# host's MLUpdateTask (host-train), by the port's trainer (train-check), and by the port's MLUpdateTask (port-train,
# which runs the port's own CoreML sources built for the Mac, not the host's framework). The updatable weights of
# every event (training begin, each mini-batch end, each epoch end) and of the final model are compared, and so are
# the events themselves: their order, their epoch and mini-batch indices, the completion, and the states.
#
# The loss the host reports is not compared. The port reports no loss, because the host's value is not a function
# the port has identified (facts/CoreML/Update13.md), so a loss is absent from the port's events and the events are
# compared without it.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
PORT=${COREML_UPDATE_PORT:-$here/../../../../packages/a/apple-backports/CoreML}
build=${COREML_UPDATE_BUILD:-$(runs_folder revenant-coreml-update)}
# The bound on any weight or bias: this many float32 ulps of the largest weight in the host's dump of the event.
# A float32 ulp at a magnitude m is 2^(e - 23) for the exponent e of m, so the bound scales with the weights.
ULPS=4
samples=16
minibatch=4
epochs=2
seed=7

rm -rf "$build"
mkdir -p "$build"

cc -std=c11 -Wall -O1 -I"$PORT" -c "$PORT/RevenantMLProto.c" -o "$build/proto.o"
cc -std=c11 -Wall -O1 -I"$PORT" -c "$PORT/RevenantMLSchema.c" -o "$build/schema.o"
cc -std=c11 -Wall -O1 -I"$PORT" -c "$PORT/RevenantMLTrain.c" -o "$build/train.o"
cc -std=c11 -Wall -O1 -I"$PORT" -o "$build/gen" "$here/gen.c" -lm
cc -std=c11 -Wall -O1 -I"$PORT" -I"$here" -o "$build/train-check" "$here/train-check.c" \
    "$build/train.o" "$build/proto.o" "$build/schema.o" -lm
cc -std=c11 -Wall -O1 -I"$PORT" -o "$build/dump" "$here/dump.c" "$build/proto.o" "$build/schema.o" -lm
xcrun clang -fobjc-arc -Wall -framework Foundation -framework CoreML "$here/host-train.m" -o "$build/host-train"

# The port's whole CoreML folder, for the Mac: the port's MLUpdateTask, its writer and its reader, linked without the
# host's CoreML framework, so that the classes the driver runs are the port's.
MACSDK=$(xcrun --sdk macosx --show-sdk-path)
objects="$build/port-objects"
mkdir -p "$objects"
for source in "$PORT"/*.m; do
    xcrun clang -isysroot "$MACSDK" -fobjc-arc -w -I"$PORT" -c "$source" -o "$objects/$(basename "$source" .m).o"
done
for source in "$PORT"/*.c; do
    xcrun clang -isysroot "$MACSDK" -std=c11 -w -I"$PORT" -c "$source" -o "$objects/$(basename "$source" .c).o"
done
xcrun clang -isysroot "$MACSDK" -fobjc-arc -w -I"$PORT" "$here/port-train.m" "$objects"/*.o \
    -framework Foundation -framework CoreGraphics -framework Accelerate -framework CoreVideo \
    -framework CoreImage -framework Metal -framework IOSurface -o "$build/port-train"

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
    # $1 is the host's folder of dumps, $2 the port's: every host dump is compared with the port's dump of its name
    for host_dump in "$1"/*.dump; do
        name=$(basename "$host_dump")
        if line=$(awk -v ulps="$ULPS" -f "$build/compare.awk" "$host_dump" "$2/$name"); then
            echo "  $name: $line"
        else
            echo "  $name: outside the bound: $line"
            result=1
        fi
    done
}

# The events of a log, without the loss the host reports: the step, its name, the epoch and the mini-batch; the
# completion's event; and the states, which are printed whole.
events() {
    awk '/^step /{ print $1, $2, $3, $4, $5, $6, $7; next } /^completed /{ print $1, $2, $3; next } { print }' "$1"
}

case_run() {
    # $1 case name, $2 optimiser, $3.. the optimiser's numbers as gen takes them
    name=$1
    shift
    dir="$build/$name"
    mkdir -p "$dir/host" "$dir/port" "$dir/lifecycle" "$dir/lifecycle-dump"
    "$build/gen" "$dir" "$@" $minibatch $epochs $samples $seed > "$dir/gen.log"
    "$build/host-train" "$dir/model.mlmodel" "$dir/input.f32" "$dir/target.f32" "$dir/host" $samples \
        > "$dir/host.log" 2>&1 || { echo "$name: host-train failed, see $dir/host.log"; result=1; return; }
    "$build/train-check" "$dir/model.mlmodel" "$dir/input.f32" "$dir/target.f32" "$dir/port" $samples \
        > "$dir/port.log" 2>&1 || { echo "$name: train-check failed, see $dir/port.log"; result=1; return; }
    echo "$name, the trainer against the host:"
    compare "$dir/host" "$dir/port"
    "$build/port-train" "$dir/model.mlmodel" "$dir/input.f32" "$dir/target.f32" "$dir/lifecycle" $samples \
        > "$dir/lifecycle.log" 2>&1 || { echo "$name: port-train failed, see $dir/lifecycle.log"; result=1; return; }
    echo "$name, the port's MLUpdateTask against the host:"
    if [ "$(events "$dir/host.log")" = "$(events "$dir/lifecycle.log")" ]; then
        echo "  events: the same order, indices, completion and states as the host's"
    else
        echo "  events: differ from the host's"
        events "$dir/host.log" > "$dir/host.events"
        events "$dir/lifecycle.log" > "$dir/lifecycle.events"
        diff "$dir/host.events" "$dir/lifecycle.events" || true
        result=1
    fi
    for snapshot in "$dir"/lifecycle/*.mlmodel; do
        # the reader's dump lists every layer; the host's lists the layers with weights, so the flatten is left out
        "$build/dump" "$snapshot" | grep -v '^layer [^ ]* flatten$' > "$dir/lifecycle-dump/$(basename "$snapshot" .mlmodel).dump"
    done
    compare "$dir/host" "$dir/lifecycle-dump"
}

# SGD without a momentum, SGD with a momentum, and Adam with the default moments.
case_run sgd sgd 0.1 0.0 0.999 1e-8
case_run sgdm sgd 0.1 0.9 0.999 1e-8
case_run adam adam 0.01 0.9 0.999 1e-8

# Models whose convolution asks for too many output channels. 2^31 - 1 fails the check on the dimension itself;
# 2^27 passes it, and the weights it implies (2^27 * 9) fail the check on the product. The sizes that follow
# from them overflow a 32-bit product, so the trainer must refuse each by name, before any allocation.
for channels in 2147483647 134217728; do
    dir="$build/oversized-$channels"
    mkdir -p "$dir"
    "$build/gen" "$dir" sgd 0.1 0.0 0.999 1e-8 $minibatch $epochs $samples $seed $channels > "$dir/gen.log"
    if "$build/train-check" "$dir/model.mlmodel" "$dir/input.f32" "$dir/target.f32" "$dir/port" $samples \
        > "$dir/port.log" 2>&1; then
        echo "oversized $channels: the trainer accepted it"
        result=1
    else
        echo "oversized $channels: refused: $(cat "$dir/port.log")"
    fi
done

exit $result
