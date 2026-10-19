#!/bin/sh
# Reproduces the lighting model of facts/SceneKit/SCNView.md: dense.swift, grazing.swift and selfillumination.swift read macOS SceneKit's
# pixels for one lit quad over angles, shininess, roughness, metalness and albedo; the fits name the formulas and
# how far every pixel is from them. Takes a few minutes; run it through coordination/heavy.sh.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../../common/runs.sh" "$here"
BUILD=${BUILD:-$(runs_fresh revenant-lighting)}
cp "$here"/fitspec.py "$here"/fitpbr.py "$here"/fitgraze.py "$here"/fitselfillumination.py "$BUILD"/
xcrun swiftc -O "$here/dense.swift" -o "$BUILD/dense"
xcrun swiftc -O "$here/grazing.swift" -o "$BUILD/grazing"
xcrun swiftc -O "$here/selfillumination.swift" -o "$BUILD/selfillumination"
xcrun swiftc -O "$here/defaultslot.swift" -o "$BUILD/defaultslot"
cd "$BUILD"
./dense | grep -v '^#' > dense.txt
./grazing | grep -v '^#' > grazing.txt
./selfillumination > selfillumination.txt
python3 fitspec.py
python3 fitpbr.py
python3 fitgraze.py
python3 fitselfillumination.py
./defaultslot
