import os

from conan import ConanFile
from conan.tools.build import can_run
from conan.tools.gnu import AutotoolsDeps
from conan.tools.layout import basic_layout


class TestPackage(ConanFile):
    settings = "os", "arch", "compiler", "build_type"
    test_type = "explicit"

    def requirements(self):
        self.requires(self.tested_reference_str)

    def layout(self):
        basic_layout(self)

    def generate(self):
        AutotoolsDeps(self).generate()

    def build(self):
        source = os.path.join(self.source_folder, "test_package.c")
        program = os.path.join(self.build_folder, "test_package")
        self.run(f'cc $CPPFLAGS $CFLAGS "{source}" -o "{program}" $LDFLAGS $LIBS', env="conanbuild")

    def test(self):
        if can_run(self):
            self.run(os.path.join(self.build_folder, "test_package"), env="conanrun")
