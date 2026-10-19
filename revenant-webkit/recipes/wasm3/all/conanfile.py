from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, cmake_layout
from conan.tools.files import copy
from conan.tools.scm import Git
import os


class Wasm3Conan(ConanFile):
    name = "wasm3"
    user = "revenant"
    channel = "stable"
    description = "WebAssembly interpreter"
    license = "MIT"
    homepage = "https://github.com/wasm3/wasm3"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"
    exports_sources = "CMakeLists.txt"

    def configure(self):
        self.settings.rm_safe("compiler.cppstd")
        self.settings.rm_safe("compiler.libcxx")

    def layout(self):
        cmake_layout(self, src_folder=".")

    def source(self):
        source = self.conan_data["sources"][self.version]
        Git(self, folder="src").fetch_commit(source["url"], source["commit"])

    def generate(self):
        CMakeToolchain(self).generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build(target="m3")

    def package(self):
        copy(self, "LICENSE", os.path.join(self.source_folder, "src"), os.path.join(self.package_folder, "licenses"))
        cmake = CMake(self)
        cmake.install()

    def package_info(self):
        self.cpp_info.libs = ["m3"]
