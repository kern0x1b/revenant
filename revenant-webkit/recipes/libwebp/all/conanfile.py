from conan import ConanFile
from conan.tools.cmake import CMake, CMakeToolchain, cmake_layout
from conan.tools.files import copy
from conan.tools.scm import Git
import os


class LibWebPConan(ConanFile):
    name = "libwebp"
    user = "revenant"
    channel = "stable"
    description = "WebP image codec"
    license = "BSD-3-Clause"
    homepage = "https://chromium.googlesource.com/webm/libwebp"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"

    def layout(self):
        cmake_layout(self)

    def source(self):
        source = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(source["url"], source["commit"])

    def generate(self):
        tc = CMakeToolchain(self)
        tc.cache_variables["BUILD_SHARED_LIBS"] = False
        tc.cache_variables["WEBP_BUILD_ANIM_UTILS"] = False
        tc.cache_variables["WEBP_BUILD_CWEBP"] = False
        tc.cache_variables["WEBP_BUILD_DWEBP"] = False
        tc.cache_variables["WEBP_BUILD_GIF2WEBP"] = False
        tc.cache_variables["WEBP_BUILD_IMG2WEBP"] = False
        tc.cache_variables["WEBP_BUILD_VWEBP"] = False
        tc.cache_variables["WEBP_BUILD_WEBPINFO"] = False
        tc.cache_variables["WEBP_BUILD_WEBPMUX"] = False
        tc.cache_variables["WEBP_BUILD_EXTRAS"] = False
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))
        copy(self, "*.h", os.path.join(self.source_folder, "src", "webp"),
             os.path.join(self.package_folder, "include", "webp"))
        copy(self, "*.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)

    def package_info(self):
        self.cpp_info.components["webp"].libs = ["webp", "sharpyuv"]
        self.cpp_info.components["webpdemux"].libs = ["webpdemux"]
        self.cpp_info.components["webpdemux"].requires = ["webp"]
