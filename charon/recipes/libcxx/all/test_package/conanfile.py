from conan import ConanFile


class TestPackage(ConanFile):
    python_requires = "ios6-base/1.0@charon/stable"
    python_requires_extend = "ios6-base.Ios6TestPackage"
