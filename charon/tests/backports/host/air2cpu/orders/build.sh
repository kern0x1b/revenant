#!/bin/sh
# build.sh — compile one .metal at run time, write the metallib the way the differential does, and
# unpack its AIR so the codes can be read. No metal tool is involved: the host's Metal framework
# compiles the source and -[MTLDynamicLibrary serializeToURL:error:] writes the file.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=${1:-$here/../../../../../.agent-work/runs/orders}
mkdir -p "$work"
cp "$here"/*.metal "$work"/
cd "$work"
xcrun clang -O -fobjc-arc -Wno-deprecated-declarations "$here/build.m" -framework Metal -framework Foundation -o build
for source in *.metal; do
    ./build "$source" || continue
    python3 - "$source" <<'PY'
import struct, subprocess, sys
data = open(sys.argv[1].replace(".metal", ".metallib"), "rb").read()
offset, index = 0, 0
while True:
    offset = data.find(b"\xde\xc0\x17\x0b", offset)
    if offset < 0:
        break
    _, _, start, size, _ = struct.unpack_from("<5I", data, offset)
    open("%s.m%d.bc" % (sys.argv[1][:-6], index), "wb").write(data[offset + start: offset + start + size])
    offset += 4
    index += 1
print("%s: %d module(s)" % (sys.argv[1], index))
PY
done
/opt/homebrew/opt/llvm/bin/llvm-dis *.bc -o /dev/null 2>/dev/null
for bc in *.bc; do /opt/homebrew/opt/llvm/bin/llvm-dis "$bc" -o "${bc%.bc}.ll"; done
ls *.ll
