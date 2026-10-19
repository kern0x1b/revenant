#!/bin/sh
# The Y'CbCr conversions of vImage, iOS 8.0, held against the host's own vImage: every layout, both
# directions, both matrices, every pixel range the header's own examples name, and every picture size
# whose shape each layout allows. The port's sources are compiled with every API name they define
# renamed, so this translation unit can hold the port's answers and the host's side by side; the names
# come from the port's registry, so a name added to either file is renamed too.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
ACCELERATE=${ACCELERATE:-$here/../../../../packages/a/apple-backports/Accelerate}
BUILD=${BUILD:-$(runs_fresh charon-ypcbcr8)}
sdk=$(xcrun --show-sdk-path)
quiet="-Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-nullability-completeness"

renames=""
for name in $(python3 - "$here" <<'PY'
import json, os, sys
registry = os.path.join(sys.argv[1], "..", "..", "..", "..", "packages", "a", "apple-backports", "registry", "Accelerate")
for part in sorted(os.listdir(registry)):
    if not part.endswith(".json"):
        continue
    for entry in json.load(open(os.path.join(registry, part)))["entries"]:
        if entry["kind"] == "function" and entry["api"].startswith(("vImageConvert", "vImageExtractChannel")) \
                and ("YpCbCr" in entry["api"] or "420" in entry["api"] or "422" in entry["api"]
                     or "444" in entry["api"] or "vImageExtractChannel_ARGB8888" in entry["api"]):
            print(entry["api"].rstrip("()"))
PY
); do
    renames="$renames -D$name=charonHost_$name"
done
for name in kvImage_YpCbCrToARGBMatrix_ITU_R_601_4 kvImage_YpCbCrToARGBMatrix_ITU_R_709_2 \
            kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4 kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2; do
    renames="$renames -D$name=charonHost_$name"
done

rm -rf "$BUILD"
mkdir -p "$BUILD"
xcrun clang -fobjc-arc -isysroot "$sdk" $quiet $renames -c "$ACCELERATE/vImageYpCbCr8.m" -o "$BUILD/ypcbcr.o"
xcrun clang -fobjc-arc -isysroot "$sdk" $quiet "$here/differential.m" "$BUILD/ypcbcr.o" \
    -framework Accelerate -framework Foundation -o "$BUILD/differential"
"$BUILD/differential" > "$BUILD/log" 2>&1 && result=0 || result=$?
grep -v '^ok ' "$BUILD/log" || true
echo "log=$BUILD/log"
exit $result
