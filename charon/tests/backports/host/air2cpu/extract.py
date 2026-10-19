#!/usr/bin/env python3
"""Pull the bitcode records out of a metallib, the same scan tools/air2es/metallib2es.py does.

Both modules of the file the runtime serialises hold the same functions, so the first is taken and the
rest are not concatenated: air2cpu would otherwise translate every kernel twice under a mangled name.
"""
import os
import struct
import sys

data = open(sys.argv[1], "rb").read()
out = sys.argv[2]
os.makedirs(os.path.join(out, "air"), exist_ok=True)
offset, index, taken = 0, 0, None
while True:
    offset = data.find(b"\xde\xc0\x17\x0b", offset)
    if offset < 0:
        break
    _, _, start, size, _ = struct.unpack_from("<5I", data, offset)
    module = data[offset + start: offset + start + size]
    if taken is None:
        taken = module
        with open(os.path.join(out, "air", "m0.bc"), "wb") as handle:
            handle.write(module)
    index += 1
    offset += 4
if taken is None:
    sys.exit("extract: %s holds no bitcode record" % sys.argv[1])
print("extract: %d bitcode record(s), took the first (%d bytes)" % (index, len(taken)))
