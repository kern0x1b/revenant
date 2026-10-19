import struct, sys

# Rename Mach-O __DATA section names in place: __xlcls->__objc_classlist, etc.
import os
FORWARD = {b"__objc_classlist": b"__xlcls", b"__objc_catlist": b"__xlcat", b"__objc_protolist": b"__xlproto"}
REVERSE = {v: k for k, v in FORWARD.items()}
RENAME = FORWARD if (len(sys.argv) > 2 and sys.argv[2] == "toxl") else REVERSE

def pad(name):
    return name + b"\0" * (16 - len(name))

path = sys.argv[1]
data = bytearray(open(path, "rb").read())
magic = struct.unpack_from("<I", data, 0)[0]
assert magic in (0xfeedface, 0xfeedfacf), hex(magic)
is64 = magic == 0xfeedfacf
ncmds = struct.unpack_from("<I", data, 16)[0]
off = 32 if is64 else 28
seg_cmd = 0x19 if is64 else 0x01
seg_hdr = 72 if is64 else 56
sect_sz = 80 if is64 else 68
changed = 0
for _ in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", data, off)
    if cmd == seg_cmd:
        nsects = struct.unpack_from("<I", data, off + (64 if is64 else 48))[0]
        s = off + seg_hdr
        for _ in range(nsects):
            sect = bytes(data[s:s+16]).rstrip(b"\0")
            if sect in RENAME:
                data[s:s+16] = pad(RENAME[sect])
                changed += 1
            s += sect_sz
    off += cmdsize
open(path, "wb").write(data)
print("renamed %d sections" % changed)
