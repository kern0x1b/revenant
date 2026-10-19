import os

from conan import ConanFile
from conan.tools.files import apply_conandata_patches, copy, export_conandata_patches, get
from conan.tools.gnu import AutotoolsDeps, AutotoolsToolchain
from conan.tools.layout import basic_layout


class LdidConan(ConanFile):
    name = "ldid"
    user = "charon"
    channel = "stable"
    description = "Signs Mach-O binaries with a code signature and entitlements, the way a jailbroken device accepts them"
    license = "AGPL-3.0-or-later"
    homepage = "https://github.com/ProcursusTeam/ldid"
    package_type = "application"
    settings = "os", "arch", "compiler", "build_type"

    def layout(self):
        basic_layout(self, src_folder="src")

    def requirements(self):
        self.requires("libplist/2.7.0@charon/stable")
        self.requires("openssl/[>=4 <5]")

    def export_sources(self):
        export_conandata_patches(self)

    def source(self):
        get(self, **self.conan_data["sources"][self.version], strip_root=True)
        apply_conandata_patches(self)

    def generate(self):
        AutotoolsToolchain(self).generate()
        AutotoolsDeps(self).generate()

    def build(self):
        makefile = os.path.join(self.source_folder, "Makefile")
        self.run(f'make -f "{makefile}" VPATH="{self.source_folder}" ldid '
                 "LIBPLIST_INCLUDES= LIBPLIST_LIBS= LIBCRYPTO_INCLUDES= LIBCRYPTO_LIBS=")

    def package(self):
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))
        copy(self, "ldid", self.build_folder, os.path.join(self.package_folder, "bin"))

    def package_info(self):
        self.cpp_info.includedirs = []
        self.cpp_info.libdirs = []
