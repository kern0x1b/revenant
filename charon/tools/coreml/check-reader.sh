#!/bin/sh
# The CoreML reader, measured against a reference dump of every container under test: every
# container is read and the tree printed is compared with the reference dump of the same file,
# and a set of malformed containers is checked to be refused.
#
# What it proves and what it does not: that the reader reads every field of every container
# under test exactly as the reference dump reads it. The reference dumps are written by
# tools/coreml/proto.lua from the committed schema, and at the port they were checked
# byte-identical to the dumps protobuf's own Python reflection wrote for the same ten
# containers, before that generator was retired. The reference is therefore one parser's
# reading of the schema, not an independent second parser on every run. It does not prove the
# reader reads a field of a container that is not under test -- a weight matrix of a few
# thousand elements, a oneof case this set never exercises, a message the schema table holds
# but no container here reaches. The interpreter is measured separately, against predictions.
#
# Usage: sh tools/coreml/check-reader.sh <directory for the run output>
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CORE=$ROOT/packages/a/apple-backports/CoreML
OUT=${1:-$ROOT/.agent-work/runs/coreml-reader}
CC=${CC:-clang}
CFLAGS="-std=c99 -Wall -Wextra -Wno-unused-parameter -O1 -fsanitize=address"

mkdir -p "$OUT"
echo "reader check -> $OUT"

# The containers and their reference dumps are written by tools/coreml/make-models.lua, from the
# committed schema, one model per kind the port reads.
if [ ! -f "$OUT/models/manifest.json" ]; then
    echo "writing the containers..."
    xmake l "$ROOT/tools/coreml/make-models.lua" --out "$OUT/models"
fi

$CC $CFLAGS -I "$CORE" -o "$OUT/ml-dump" "$ROOT/tools/coreml/ml-dump.c" \
    "$CORE/CharonMLProto.c" "$CORE/CharonMLSchema.c"

failures=0
for model in "$OUT"/models/*.mlmodel; do
    name=$(basename "$model" .mlmodel)
    if ! "$OUT/ml-dump" "$model" > "$OUT/$name.actual" 2> "$OUT/$name.err"; then
        echo "$name: FAIL - the reader refused a container the writer made"
        sed 's/^/    /' "$OUT/$name.err"
        failures=$((failures + 1))
        continue
    fi
    if diff -u "$OUT/models/$name.ref" "$OUT/$name.actual" > "$OUT/$name.diff"; then
        echo "$name: OK - the tree read is identical to the reference dump's"
    else
        echo "$name: FAIL - the tree read differs from the reference dump's"
        head -20 "$OUT/$name.diff" | sed 's/^/    /'
        failures=$((failures + 1))
    fi
done

# Malformed containers must be refused rather than half-read. A model that is not read must
# not be run, so what the reader does with the four shapes below is part of what it promises.
# The bytes are written by the shell: a truncated copy of glm, and three short byte strings.
data=$OUT/models/glm.mlmodel
half=$(( $(wc -c < "$data") / 2 ))
head -c "$half" "$data" > "$OUT/truncated.mlmodel"
head -c 64 /dev/zero | tr '\000' '\377' > "$OUT/garbage.mlmodel"
printf '\012\177\001\002\003' > "$OUT/short-length.mlmodel"
printf '\022\100\002\001' > "$OUT/field-past-end.mlmodel"

for bad in truncated garbage short-length field-past-end; do
    if "$OUT/ml-dump" "$OUT/$bad.mlmodel" > /dev/null 2>&1; then
        echo "$bad: FAIL - a malformed container was read as a model"
        failures=$((failures + 1))
    else
        echo "$bad: OK - refused, as a malformed container must be"
    fi
done

if [ "$failures" -eq 0 ]; then
    echo "reader check: OK (0 failures)"
    exit 0
fi
echo "reader check: FAIL ($failures failures)"
exit 1
