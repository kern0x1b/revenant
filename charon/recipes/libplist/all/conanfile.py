import os

from conan import ConanFile
from conan.tools.files import copy, get, rm, rmdir
from conan.tools.gnu import Autotools, AutotoolsToolchain
from conan.tools.layout import basic_layout


class LibplistConan(ConanFile):
    name = "libplist"
    user = "charon"
    channel = "stable"
    description = "Reads and writes Apple property lists, for the tools that sign and package what a port builds"
    license = "LGPL-2.1-or-later"
    homepage = "https://github.com/libimobiledevice/libplist"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"

    def layout(self):
        basic_layout(self, src_folder="src")

    def source(self):
        get(self, **self.conan_data["sources"][self.version], strip_root=True)

    def generate(self):
        toolchain = AutotoolsToolchain(self)
        toolchain.configure_args += ["--disable-shared", "--enable-static", "--without-cython", "--without-tools",
                                     "--without-tests"]
        toolchain.generate()

    def build(self):
        autotools = Autotools(self)
        autotools.configure()
        autotools.make()

    def package(self):
        copy(self, "COPYING.LESSER", self.source_folder, os.path.join(self.package_folder, "licenses"))
        Autotools(self).install()
        rmdir(self, os.path.join(self.package_folder, "lib", "pkgconfig"))
        rmdir(self, os.path.join(self.package_folder, "share"))
        rm(self, "*.la", os.path.join(self.package_folder, "lib"))

    def package_info(self):
        self.cpp_info.components["plist"].libs = ["plist-2.0"]
        self.cpp_info.components["plist"].defines = ["LIBPLIST_STATIC"]
        self.cpp_info.components["plist"].set_property("pkg_config_name", "plist-2.0")
        self.cpp_info.components["plist"].set_property("cmake_target_name", "libplist::libplist")
        self.cpp_info.components["plist++"].libs = ["plist++-2.0"]
        self.cpp_info.components["plist++"].requires = ["plist"]
        self.cpp_info.components["plist++"].set_property("pkg_config_name", "plist++-2.0")
        self.cpp_info.components["plist++"].set_property("cmake_target_name", "libplist::libplist++")
