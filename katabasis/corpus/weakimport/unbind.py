#!/usr/bin/env python3
"""unbind.py IN OUT — IN without the bind tables of its dyld info, the shape of an image taken out of a shared cache.

dsc_extractor does not rebuild them (scripts/translate.sh says so), so such an image says what it imports only through
its symbol table and stubs: there is no bind entry for a stub to be weak or strong by."""
import struct
import sys

LC_DYLD_INFO, LC_DYLD_INFO_ONLY = 0x22, 0x80000022
# rebase, bind, weak_bind, lazy_bind, export: (offset, size) pairs after the two command words
BIND_FIELDS = (2, 3, 4, 5, 6, 7)  # bind_off/size, weak_bind_off/size, lazy_bind_off/size, as word indexes

data = bytearray(open(sys.argv[1], "rb").read())
magic, _, _, _, ncmds = struct.unpack_from("<IiiII", data, 0)
assert magic == 0xFEEDFACF, "a thin arm64 image is expected"
offset = 32
for _ in range(ncmds):
    cmd, size = struct.unpack_from("<II", data, offset)
    if cmd in (LC_DYLD_INFO, LC_DYLD_INFO_ONLY):
        for field in BIND_FIELDS:
            struct.pack_into("<I", data, offset + 4 * (field + 2), 0)
        break
    offset += size
else:
    sys.exit("unbind.py: no LC_DYLD_INFO in " + sys.argv[1])
open(sys.argv[2], "wb").write(data)
