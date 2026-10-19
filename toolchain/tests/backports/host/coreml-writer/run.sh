#!/bin/sh
# The port's writer of a CoreML model (CharonMLWrite.c) against the host. Each model below is read with the
# port's reader, written back with the port's writer, and the written bytes are compared with the original
# (byte for byte: the writer keeps the field order and the packing of the input), then the host reads the
# written file and must describe it as it describes the original. The two models are system files of the
# TuriCore framework, copied to the run folder; the test fails if either is missing.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
build=${WRITER_BUILD:-$(runs_folder charon-coreml-writer-host)}
rm -rf "$build"
mkdir -p "$build/tmp"
core="$runs_checkout/packages/a/apple-backports/CoreML"
models="/System/Library/PrivateFrameworks/TuriCore.framework/Versions/A/Resources"
xcrun clang -std=c11 -Wall -Wextra -Wno-unused-parameter -I"$core" -c "$core/CharonMLWrite.c" -o "$build/write.o"
xcrun clang -std=c11 -I"$core" -c "$core/CharonMLProto.c" -o "$build/proto.o"
xcrun clang -std=c11 -I"$core" -c "$core/CharonMLSchema.c" -o "$build/schema.o"
xcrun clang -std=c11 -I"$core" "$here/roundtrip.c" "$build/write.o" "$build/proto.o" "$build/schema.o" -o "$build/roundtrip"
xcrun clang -fobjc-arc -framework Foundation -framework CoreML "$here/host-check.m" -o "$build/host-check"
for name in maml-video-light resnet-16; do
    if [ ! -f "$models/$name.mlmodel" ]; then
        echo "coreml-writer: $models/$name.mlmodel is missing" >&2
        exit 1
    fi
    cp "$models/$name.mlmodel" "$build/$name.mlmodel"
    "$build/roundtrip" "$build/$name.mlmodel" "$build/$name-written.mlmodel" > "$build/$name.log"
    if cmp -s "$build/$name.mlmodel" "$build/$name-written.mlmodel"; then
        echo "$name: written bytes identical to the original" >> "$build/summary"
    else
        echo "$name: written bytes DIFFER from the original" >> "$build/summary"
    fi
    # TMPDIR keeps the host's compiled copy inside the run folder
    TMPDIR="$build/tmp/" "$build/host-check" "$build/$name.mlmodel" "$build/$name-written.mlmodel" >> "$build/summary"
done
diff "$here/expected.txt" "$build/summary"
echo "coreml-writer: the port's writer round-trips both models and the host reads them back"
