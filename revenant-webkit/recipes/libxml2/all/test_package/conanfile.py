from conan import ConanFile


class TestPackage(ConanFile):
    python_requires = "charon-base/1.0@charon/stable"
    python_requires_extend = "charon-base.CharonTestPackage"
