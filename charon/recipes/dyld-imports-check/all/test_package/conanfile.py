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
        output = StringIO()
        self.run("dyld-imports-check --help", stdout=output, env="conanbuild")
        text = output.getvalue()
        for expected in ("--cache", "--dist"):
            if expected not in text:
                raise ConanException(f"dyld-imports-check does not offer {expected}: {text}")
