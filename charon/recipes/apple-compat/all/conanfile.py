import os

from conan import ConanFile
from conan.tools.apple import to_apple_arch
from conan.errors import ConanInvalidConfiguration
from conan.tools.files import copy
from conan.tools.scm import Version


class AppleCompatConan(ConanFile):
    name = "apple-compat"
    user = "charon"
    channel = "stable"
    description = ("What a current library calls and an old Apple system does not have, provided as hidden "
                   "definitions linked into the image that calls them")
    license = "MIT"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"
    exports_sources = "src/*", "include/*", "LICENSE"

    ARRIVED = {
        "aligned_alloc": {"iOS": "13.0", "Macos": "10.15", "tvOS": "13.0", "watchOS": "6.0"},
        "clock_gettime": {"iOS": "10.0", "Macos": "10.12", "tvOS": "10.0", "watchOS": "3.0"},
        "fdopendir": {"iOS": "8.0", "Macos": "10.10", "tvOS": "9.0", "watchOS": "2.0"},
        "openat": {"iOS": "8.0", "Macos": "10.10", "tvOS": "9.0", "watchOS": "2.0"},
        "fchmodat": {"iOS": "8.0", "Macos": "10.10", "tvOS": "9.0", "watchOS": "2.0"},
        "unlinkat": {"iOS": "8.0", "Macos": "10.10", "tvOS": "9.0", "watchOS": "2.0"},
        "__sincos_stret": {"iOS": "7.0", "Macos": "10.9"},
        "__sincosf_stret": {"iOS": "7.0", "Macos": "10.9"},
        "__strlcpy_chk": {"iOS": "7.0", "Macos": "10.9"},
        "__strlcat_chk": {"iOS": "7.0", "Macos": "10.9"},
        "__ulock_wait": {"iOS": "10.0", "Macos": "10.12", "tvOS": "10.0", "watchOS": "3.0"},
        "__ulock_wake": {"iOS": "10.0", "Macos": "10.12", "tvOS": "10.0", "watchOS": "3.0"},
    }

    @property
    def _provided(self):
        system, release = str(self.settings.os), Version(str(self.settings.os.version))
        return sorted(symbol for symbol, arrived in self.ARRIVED.items()
                      if system in arrived and release < Version(arrived[system]))

    def validate(self):
        if not any(str(self.settings.os) in arrived for arrived in self.ARRIVED.values()):
            raise ConanInvalidConfiguration(f"{self.name} knows nothing an {self.settings.os} build lacks")

    def build(self):
        objects = []
        for symbol in self._provided:
            source = os.path.join(self.source_folder, "src", f"{symbol}.c")
            compiled = os.path.join(self.build_folder, f"{symbol}.o")
            flags = " ".join(self.conf.get("tools.build:cflags", default=[], check_type=list))
            sysroot = self.conf.get("tools.apple:sdk_path", check_type=str)
            target = f"-target {self._triple} -isysroot \"{sysroot}\"" if sysroot else ""
            self.run(f'xcrun clang {target} {flags} -Os -fvisibility=hidden -c "{source}" -o "{compiled}"')
            objects.append(f'"{compiled}"')
        if objects:
            self.run(f'xcrun libtool -static -o "{os.path.join(self.build_folder, "libapple-compat.a")}" '
                     + " ".join(objects))

    @property
    def _triple(self):
        return f"{to_apple_arch(self)}-apple-{str(self.settings.os).lower()}{self.settings.os.version}"

    def package(self):
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))
        copy(self, "libapple-compat.a", self.build_folder, os.path.join(self.package_folder, "lib"))
        for symbol in self._provided:
            copy(self, f"{symbol}.h", os.path.join(self.source_folder, "include", "charon"),
                 os.path.join(self.package_folder, "include", "charon"))

    def _renamed(self, symbol):
        return os.path.isfile(os.path.join(self.package_folder, "include", "charon", f"{symbol}.h"))

    def package_info(self):
        provided = self._provided
        for symbol in self.ARRIVED:
            component = self.cpp_info.components[symbol]
            component.includedirs = []
            component.bindirs = []
            if symbol in provided:
                if self._renamed(symbol):
                    header = os.path.join(self.package_folder, "include", "charon", f"{symbol}.h")
                    component.cflags = [f"-include{header}"]
                    component.cxxflags = [f"-include{header}"]
                component.libs = ["apple-compat"]
            else:
                component.libdirs = []
        self.cpp_info.set_property("charon_provides", provided)
        self.cpp_info.set_property("charon_arrived", {symbol: arrived[str(self.settings.os)]
                                                      for symbol, arrived in self.ARRIVED.items()
                                                      if str(self.settings.os) in arrived})
        self.cpp_info.set_property("charon_force_includes",
                                   [os.path.join("charon", f"{symbol}.h") for symbol in provided
                                    if self._renamed(symbol)])
