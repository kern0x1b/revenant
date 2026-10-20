#!/bin/sh
# build.sh — compile one .metal at run time, write the metallib the way the differential does, and
# unpack its AIR so the codes can be read. No metal tool is involved: the host's Metal framework
# compiles the source and -[MTLDynamicLibrary serializeToURL:error:] writes the file.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../../common/runs.sh" "$here"
work=${1:-$(runs_folder orders)}
mkdir -p "$work"
cp "$here"/*.metal "$work"/
cd "$work"
xcrun clang -O -fobjc-arc -Wno-deprecated-declarations "$here/build.m" -framework Metal -framework Foundation -o build
for source in *.metal; do
    ./build "$source" || continue
    runs_xmake l "$here/../tools.lua" modules "$source"
done
/opt/homebrew/opt/llvm/bin/llvm-dis *.bc -o /dev/null 2>/dev/null
for bc in *.bc; do /opt/homebrew/opt/llvm/bin/llvm-dis "$bc" -o "${bc%.bc}.ll"; done
ls *.ll
