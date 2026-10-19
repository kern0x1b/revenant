#!/usr/bin/env python3
"""List the symbols a dylib inside an old dyld shared cache imports.

    tools/dsc-imports.py <cache> <dylib-path-substring>

Xcode's dsc_extractor refuses the iOS 6 cache format, but the parts needed to
answer "what does this library link against" are simple enough to read in
place: the cache header, the mapping table that turns an address into a file
offset, the image table, and then the Mach-O symbol table of the image itself.
"""
import struct
import sys

MH_MAGIC = 0xfeedface
LC_SYMTAB = 0x2
LC_LOAD_DYLIB = 0xc
N_UNDF = 0x0
N_TYPE = 0x0e


def read_cache(path):
    with open(path, "rb") as f:
        return f.read()


def parse_header(data):
    magic = data[:16].rstrip(b"\0").decode()
    mapping_offset, mapping_count, images_offset, images_count = struct.unpack_from("<IIII", data, 16)
    mappings = []
    for i in range(mapping_count):
        address, size, file_offset, _, _ = struct.unpack_from("<QQQII", data, mapping_offset + i * 32)
        mappings.append((address, size, file_offset))
    images = []
    for i in range(images_count):
        address, _, _, path_offset, _ = struct.unpack_from("<QQQII", data, images_offset + i * 32)
        end = data.index(b"\0", path_offset)
        images.append((address, data[path_offset:end].decode()))
    return magic, mappings, images


def to_offset(mappings, address):
    for start, size, file_offset in mappings:
        if start <= address < start + size:
            return file_offset + (address - start)
    return None


def imports(data, mappings, image_address):
    offset = to_offset(mappings, image_address)
    magic, _, _, _, ncmds, _, _ = struct.unpack_from("<IiiIIII", data, offset)
    if magic != MH_MAGIC:
        sys.exit(f"not a 32-bit Mach-O at {image_address:#x}")

    undefined, dylibs = [], []
    cursor = offset + 28
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, cursor)
        if cmd == LC_SYMTAB:
            symoff, nsyms, stroff, _ = struct.unpack_from("<IIII", data, cursor + 8)
            for i in range(nsyms):
                str_index, n_type, _, _, _ = struct.unpack_from("<IBBhI", data, symoff + i * 12)
                if (n_type & N_TYPE) != N_UNDF:
                    continue
                end = data.index(b"\0", stroff + str_index)
                undefined.append(data[stroff + str_index:end].decode())
        elif cmd == LC_LOAD_DYLIB:
            name_offset, = struct.unpack_from("<I", data, cursor + 8)
            end = data.index(b"\0", cursor + name_offset)
            dylibs.append(data[cursor + name_offset:end].decode())
        cursor += cmdsize

    return sorted(set(undefined)), dylibs


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    data = read_cache(sys.argv[1])
    magic, mappings, images = parse_header(data)
    print(f"# cache: {magic}, {len(mappings)} mappings, {len(images)} images", file=sys.stderr)

    matches = [i for i in images if sys.argv[2] in i[1]]
    if not matches:
        sys.exit(f"no image matching {sys.argv[2]!r}")
    for address, path in matches:
        undefined, dylibs = imports(data, mappings, address)
        print(f"# {path}: {len(undefined)} undefined, {len(dylibs)} dylibs", file=sys.stderr)
        for name in undefined:
            print(name)


if __name__ == "__main__":
    main()
