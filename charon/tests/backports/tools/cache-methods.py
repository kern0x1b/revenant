import struct
import sys

from cache_reader import Cache


def methods(cache, read_only):
    method_list = cache.pointer(read_only + 32)
    found = []
    if not method_list:
        return found
    flags, count = struct.unpack("<II", cache.read(method_list, 8))
    if flags & 0x80000000:
        for index in range(count):
            entry = method_list + 8 + index * 12
            name_offset, _, implementation_offset = struct.unpack("<iii", cache.read(entry, 12))
            if flags & 0x40000000 and cache.selector_base():
                name = cache.string(cache.selector_base() + name_offset)
            else:
                name = cache.string(cache.pointer(entry + name_offset))
            found.append((name, entry + 8 + implementation_offset))
    else:
        for index in range(count):
            entry = method_list + 8 + index * 24
            found.append((cache.string(cache.pointer(entry)), cache.pointer(entry + 16)))
    return found


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: cache-methods.py <dyld_shared_cache> <image> [class ...]")
    cache = Cache(sys.argv[1])
    wanted = set(sys.argv[3:])
    image = cache.image(sys.argv[2])
    classlist = None
    for _, name, address, length in cache.sections(image):
        if name == "__objc_classlist":
            classlist = (address, length)
    if not classlist:
        sys.exit("the image has no __objc_classlist")
    for index in range(classlist[1] // 8):
        klass = cache.pointer(classlist[0] + 8 * index)
        read_only = cache.pointer(klass + 32) & 0x00007ffffffffff8
        name = cache.string(cache.pointer(read_only + 24))
        if wanted and name not in wanted:
            continue
        metaclass_read_only = cache.pointer(cache.pointer(klass) + 32) & 0x00007ffffffffff8
        for selector, implementation in methods(cache, read_only):
            print("-[%s %s]\t0x%x" % (name, selector, implementation))
        for selector, implementation in methods(cache, metaclass_read_only):
            print("+[%s %s]\t0x%x" % (name, selector, implementation))


main()
