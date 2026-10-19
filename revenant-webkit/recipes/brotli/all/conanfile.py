from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, cmake_layout
from conan.tools.files import copy, rmdir
from conan.tools.scm import Git
import os


class BrotliConan(ConanFile):
    name = "brotli"
    user = "revenant"
    channel = "stable"
    description = "Brotli compression format"
    license = "MIT"
    homepage = "https://github.com/google/brotli"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"
    options = {"fPIC": [True, False]}
    default_options = {"fPIC": True}

    def config_options(self):
        if self.settings.os == "Windows":
            del self.options.fPIC

    def layout(self):
        cmake_layout(self)

    def source(self):
        source = self.conan_data["sources"][self.version]
        git = Git(self)
        git.fetch_commit(source["url"], source["commit"])

    def generate(self):
        tc = CMakeToolchain(self)
        tc.cache_variables["BROTLI_DISABLE_TESTS"] = True
        tc.cache_variables["BROTLI_BUILD_TOOLS"] = False
        tc.cache_variables["BROTLI_BUNDLED_MODE"] = False
        tc.cache_variables["BUILD_SHARED_LIBS"] = False
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))
        CMake(self).install()
        rmdir(self, os.path.join(self.package_folder, "lib", "pkgconfig"))
        rmdir(self, os.path.join(self.package_folder, "share"))

    def package_info(self):
        self.cpp_info.components["brotlicommon"].libs = ["brotlicommon"]
        self.cpp_info.components["brotlidec"].libs = ["brotlidec"]
        self.cpp_info.components["brotlidec"].requires = ["brotlicommon"]
        self.cpp_info.components["brotlienc"].libs = ["brotlienc"]
        self.cpp_info.components["brotlienc"].requires = ["brotlicommon"]
