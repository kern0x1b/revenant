#!/bin/sh
# run.sh - the port's NFCNDEFPayload and NFCNDEFMessage against NDEF byte vectors, compiled from the
# port's own sources. There is no CoreNFC on the host to compare with, so the test's include path
# carries a transcription of the SDK 16.4 declarations of the two classes (tests/backports/host/corenfc/
# CoreNFC/CoreNFC.h) and the vectors are the record shape of the NFC Forum NDEF Technical Specification.
# `--mutated` flips one byte of the text vector, which must make checks fail: a test that cannot fail is
# not guarding anything.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
port=${PORT:-$here/../../../../packages/a/apple-backports/CoreNFC}
harness=${CORENFC_HARNESS:-$here/../../device}
build=${CORENFC_BUILD:-$(runs_fresh charon-corenfc)}
rm -rf "$build"
mkdir -p "$build"
objects=""
for source in CharonNDEF NFCNDEFMessage11 NFCNDEFMessage13; do
    xcrun clang -fobjc-arc -w -I"$here" -I"$port" -c "$port/$source.m" -o "$build/$source.o"
    objects="$objects $build/$source.o"
done
xcrun clang -fobjc-arc -Wall -Wno-deprecated-declarations -I"$here" -I"$port" -I"$harness" \
    "$here/differential.m" "$harness/check.m" $objects \
    -framework Foundation -o "$build/differential"
"$build/differential" "$@"
