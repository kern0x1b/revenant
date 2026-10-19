from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, CMakeDeps, cmake_layout
from conan.tools.files import copy
from conan.tools.scm import Git
import os


class Woff2Conan(ConanFile):
    name = "woff2"
    user = "revenant"
    channel = "stable"
    description = "WOFF2 font decoder"
    license = "MIT"
    homepage = "https://github.com/google/woff2"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"

    def requirements(self):
        self.requires("brotli/[>=1.2.0]@revenant/stable", transitive_headers=True, transitive_libs=True)
        self.requires("libcxx/[>=21.1]@charon/stable", transitive_headers=True, transitive_libs=True)

    def layout(self):
        cmake_layout(self)

    def source(self):
        source = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(source["url"], source["commit"])

    def generate(self):
        CMakeDeps(self).generate()
        tc = CMakeToolchain(self)
        tc.cache_variables["BUILD_SHARED_LIBS"] = False
        tc.cache_variables["CMAKE_MACOSX_BUNDLE"] = False
        tc.cache_variables["CMAKE_POLICY_VERSION_MINIMUM"] = "3.5"
        brotli = self.dependencies["brotli"].cpp_info
        tc.cache_variables["CANONICAL_PREFIXES"] = True
        tc.preprocessor_definitions["WOFF2_EXTERNAL_BROTLI"] = "1"
        tc.extra_cflags.append(f"-I{brotli.includedirs[0]}")
        libcxx = self.dependencies["libcxx"].cpp_info.aggregated_components()
        tc.extra_cxxflags += [f"-I{brotli.includedirs[0]}", "-nostdinc++", f"-isystem{libcxx.includedirs[0]}",
                              *(f"-D{define}" for define in libcxx.defines)]
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build(target="woff2common")
        cmake.build(target="woff2dec")

    def package(self):
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))
        copy(self, "*.h", os.path.join(self.source_folder, "include"),
             os.path.join(self.package_folder, "include"))
        copy(self, "*.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)

    def package_info(self):
        self.cpp_info.libs = ["woff2dec", "woff2common"]
