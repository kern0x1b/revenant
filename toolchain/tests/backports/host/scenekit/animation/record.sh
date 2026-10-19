#!/bin/sh
# record.sh <out-dir> : macOS SceneKit's series of Telegram's animations (series.swift), one file per case, for
# compare.py. Real time: each case runs as long as its animation. Run it through coordination/heavy.sh.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../../common/runs.sh" "$here"
OUT=$1
BUILD=${BUILD:-$(runs_fresh charon-animation)}
mkdir -p "$OUT"
cp "$here/series.swift" "$BUILD/main.swift"
xcrun swiftc -O "$BUILD/main.swift" "$here/srgblevels.swift" -o "$BUILD/series"
for c in euler-basic euler-basic-mutant euler-spring euler-spring-mutant euler-spring-velocity scale-reverse gradient gradient-metal shimmer shimmer-metal opacity-later remove-midway; do
    "$BUILD/series" "$c" > "$OUT/$c.txt"
done
echo "recorded $OUT"
