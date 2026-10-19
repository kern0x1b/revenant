import os
import shutil
from io import StringIO

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.layout import basic_layout


class TestPackage(ConanFile):
    settings = "os", "arch", "compiler", "build_type"
    generators = "VirtualBuildEnv"
    test_type = "explicit"

    def build_requirements(self):
        self.tool_requires(self.tested_reference_str)

    def layout(self):
        basic_layout(self)

    def test(self):
        binary = os.path.join(self.build_folder, "signed")
        shutil.copy(shutil.which("true"), binary)
        self.run(f'ldid -S "{binary}"', env="conanbuild")
        output = StringIO()
        self.run(f'ldid -h "{binary}"', stdout=output, env="conanbuild")
        if "CDHash=" not in output.getvalue():
            raise ConanException(f"ldid did not leave a code signature it can read back: {output.getvalue()}")
