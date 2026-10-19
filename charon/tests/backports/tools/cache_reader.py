import glob
import mmap
import struct
import sys


class Cache:
    def __init__(self, path):
        self.maps = []
        self.files = []
        for name in [path] + sorted(glob.glob(path + ".[0-9]*")):
            handle = open(name, "rb")
            data = mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ)
            self.files.append((handle, data))
            offset, count = struct.unpack_from("<II", data, 0x10)
            for index in range(count):
                address, size, file_offset, _, _ = struct.unpack_from("<QQQII", data, offset + 32 * index)
                self.maps.append((address, size, file_offset, data))
            if name == path:
                self.main = data
        self.authenticated = self.main[:16].rstrip(b"\0 ").endswith(b"arm64e")
        self.base = min(entry[0] for entry in self.maps)
        self._selector_base = False

    def locate(self, address):
        for start, size, file_offset, data in self.maps:
            if start <= address < start + size:
                return data, file_offset + address - start
        return None

    def read(self, address, count):
        found = self.locate(address)
        if not found:
            raise KeyError(hex(address))
        data, offset = found
        return data[offset:offset + count]

    def pointer(self, address):
        raw = struct.unpack("<Q", self.read(address, 8))[0]
        return self.decode(raw)

    def decode(self, raw):
        if raw == 0:
            return 0
        if self.authenticated:
            if raw >> 63:
                return self.base + (raw & 0xFFFFFFFF)
            return raw & 0x7FFFFFFFFFF
        return raw & ~0x00FFFF0000000000

    def string(self, address, limit=300):
        found = self.locate(address)
        if not found:
            return None
        data, offset = found
        end = data.find(b"\0", offset, offset + limit)
        if end < 0:
            return None
        return data[offset:end].decode("utf8", "replace")

    def printable(self, address):
        text = self.string(address)
        if text and len(text) >= 2 and all(32 <= ord(letter) < 127 for letter in text):
            return text
        return None

    def images(self):
        offset, count = struct.unpack_from("<II", self.main, 0x18)
        if count == 0:
            offset, count = struct.unpack_from("<II", self.main, 0x1C0)
        for index in range(count):
            address, _, _, path_offset, _ = struct.unpack_from("<QQQII", self.main, offset + 32 * index)
            end = self.main.find(b"\0", path_offset)
            yield address, self.main[path_offset:end].decode()

    def image(self, name):
        for address, path in self.images():
            if path == name or path.endswith("/" + name):
                return address
        raise SystemExit("image not found: " + name)

    def sections(self, image):
        command_count = struct.unpack_from("<I", self.read(image, 32), 16)[0]
        command = image + 32
        for _ in range(command_count):
            kind, size = struct.unpack("<II", self.read(command, 8))
            if kind == 0x19:
                segment = self.read(command + 8, 16).split(b"\0")[0].decode()
                total = struct.unpack_from("<I", self.read(command, 72), 64)[0]
                for index in range(total):
                    entry = self.read(command + 72 + 80 * index, 80)
                    name = entry[:16].split(b"\0")[0].decode()
                    address, length = struct.unpack_from("<QQ", entry, 32)
                    yield segment, name, address, length
            command += size

    def selector_base(self):
        if self._selector_base is False:
            self._selector_base = None
            for address, path in self.images():
                if path.endswith("libobjc.A.dylib"):
                    for _, name, start, _ in self.sections(address):
                        if name == "__objc_opt_ro":
                            relative = struct.unpack_from("<Q", self.read(start, 48), 40)[0]
                            self._selector_base = start + relative
                    break
        return self._selector_base
