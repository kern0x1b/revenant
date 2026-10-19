import struct, sys
# weaken_classrefs.py BINARY SYMFILE : mark the undefined symbols listed in SYMFILE (one per
# line, e.g. _OBJC_CLASS_$_NSUserActivity) as weak imports in a 32-bit Mach-O, so dyld binds an
# absent symbol to 0 instead of hard-failing the load. Sets the weak flag in BOTH the symbol
# table (N_WEAK_REF) and the LC_DYLD_INFO bind opcode stream (BIND_SYMBOL_FLAGS_WEAK_IMPORT) --
# dyld honours the bind-opcode flag for the actual bind. Used for iOS 7+ Objective-C class
# references a translated app makes that neither stock iOS 6 nor the backports provide: the app
# then loads with those classes nil and faults only if one is actually used.
N_WEAK_REF = 0x0040
WEAK_IMPORT = 0x1  # BIND_SYMBOL_FLAGS_WEAK_IMPORT
path, symfile = sys.argv[1], sys.argv[2]
want = set(l.strip() for l in open(symfile) if l.strip())
data = bytearray(open(path, "rb").read())
magic = struct.unpack_from("<I", data, 0)[0]
assert magic == 0xfeedface, "expected a 32-bit (armv7) Mach-O, got %#x" % magic
ncmds = struct.unpack_from("<I", data, 16)[0]
off = 28
symoff = nsyms = stroff = 0
dyld_info = None
for _ in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", data, off)
    if cmd == 0x2:  # LC_SYMTAB
        symoff, nsyms, stroff, strsize = struct.unpack_from("<IIII", data, off + 8)
    elif cmd in (0x22, 0x80000022):  # LC_DYLD_INFO(_ONLY)
        dyld_info = struct.unpack_from("<IIIIIIIIII", data, off + 8)  # rebase,bind,weak,lazy,export off/size pairs
    off += cmdsize

# (1) symbol table N_WEAK_REF
sym_weak = 0
for i in range(nsyms):
    e = symoff + i * 12
    n_strx, n_type, n_sect, n_desc, n_value = struct.unpack_from("<IBBhI", data, e)
    if (n_type & 0x0e) != 0x0:
        continue
    end = data.index(b"\0", stroff + n_strx)
    name = data[stroff + n_strx:end].decode("ascii", "replace")
    if name in want and not (n_desc & N_WEAK_REF):
        struct.pack_into("<h", data, e + 6, n_desc | N_WEAK_REF)
        sym_weak += 1

# (2) bind opcode streams: set WEAK_IMPORT on SET_SYMBOL_TRAILING_FLAGS_IMM for wanted symbols
def uleb(buf, p):
    r = shift = 0
    while True:
        b = buf[p]; p += 1
        r |= (b & 0x7f) << shift
        if not (b & 0x80):
            return r, p
        shift += 7

bind_weak = 0
if dyld_info:
    streams = [(dyld_info[2], dyld_info[3]), (dyld_info[4], dyld_info[5]), (dyld_info[6], dyld_info[7])]  # bind, weak, lazy
    for base, size in streams:
        p = base; end = base + size
        while p < end:
            b = data[p]
            op = b & 0xf0
            imm = b & 0x0f
            opcode_at = p
            p += 1
            if op == 0x00:  # DONE
                continue
            elif op in (0x10, 0x30, 0x50, 0xb0):  # *_IMM: no trailing operand
                continue
            elif op in (0x20, 0x80, 0xa0):  # *_ULEB
                _, p = uleb(data, p)
            elif op == 0x60:  # SET_ADDEND_SLEB
                _, p = uleb(data, p)
            elif op == 0x70:  # SET_SEGMENT_AND_OFFSET_ULEB
                _, p = uleb(data, p)
            elif op == 0xc0:  # DO_BIND_ULEB_TIMES_SKIPPING_ULEB
                _, p = uleb(data, p); _, p = uleb(data, p)
            elif op == 0x90:  # DO_BIND
                pass
            elif op == 0x40:  # SET_SYMBOL_TRAILING_FLAGS_IMM: imm=flags, then cstring
                s = p
                e2 = data.index(b"\0", s)
                name = data[s:e2].decode("ascii", "replace")
                if name in want and not (imm & WEAK_IMPORT):
                    data[opcode_at] = 0x40 | (imm | WEAK_IMPORT)
                    bind_weak += 1
                p = e2 + 1
            else:
                pass
print("weakened %d symtab + %d bind-opcode entries" % (sym_weak, bind_weak))
open(path, "wb").write(data)
