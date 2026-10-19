import os
from io import StringIO

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.files import mkdir, save
from conan.tools.layout import basic_layout

SYSTEM_STUB = """--- !tapi-tbd-v3
archs:           [ armv7 ]
platform:        ios
install-name:    /usr/lib/libSystem.B.dylib
current-version: 1281
exports:
  - archs:           [ armv7 ]
    re-exports:      [ /usr/lib/system/libfoo.dylib ]
    symbols:         [ dyld_stub_binder ]
--- !tapi-tbd-v3
archs:           [ armv7 ]
platform:        ios
install-name:    /usr/lib/system/libfoo.dylib
current-version: 1
parent-umbrella: System
exports:
  - archs:           [ armv7 ]
    symbols:         [ _foo ]
...
"""


class TestPackage(ConanFile):
    settings = "os", "arch", "compiler", "build_type"
    generators = "VirtualBuildEnv"
    test_type = "explicit"

    def build_requirements(self):
        self.tool_requires(self.tested_reference_str)

    def layout(self):
        basic_layout(self)

    def test(self):
        output = StringIO()
        self.run("arm-apple-darwin11-ld -v", stdout=output, stderr=output, env="conanbuild")
        expected = f"ld64-{self.dependencies.build['ld64'].ref.version}"
        if expected not in output.getvalue():
            raise ConanException(f"arm-apple-darwin11-ld is not {expected}: {output.getvalue()}")
        self._inlined_stub_wins_over_search_path()

    def _inlined_stub_wins_over_search_path(self):
        folder = os.path.join(self.build_folder, "inlined")
        save(self, os.path.join(folder, "iPhoneOS6.0.sdk", "usr", "lib", "libSystem.tbd"), SYSTEM_STUB)
        save(self, os.path.join(folder, "foo.c"), "int foo(void) { return 7; }\n")
        save(self, os.path.join(folder, "main.c"), "extern int foo(void);\nint main(void) { return foo(); }\n")
        mkdir(self, os.path.join(folder, "host"))
        self.run("xcrun clang -dynamiclib -arch arm64 -install_name /usr/lib/system/libfoo.dylib foo.c "
                 "-o host/libfoo.dylib", cwd=folder)
        self.run("xcrun clang -target armv7-apple-ios6.0 -Wno-incompatible-sysroot -c main.c -o main.o", cwd=folder)
        traced = StringIO()
        self.run("arm-apple-darwin11-ld -arch armv7 -ios_version_min 6.0 -syslibroot iPhoneOS6.0.sdk -e _main "
                 "-o linked main.o -lSystem -Lhost -t", stdout=traced, stderr=traced, env="conanbuild", cwd=folder)
        if "host/libfoo.dylib" in traced.getvalue():
            raise ConanException("the linker read a same-named file on a search path instead of the library the "
                                 f"linked text stub defines inline: {traced.getvalue()}")
