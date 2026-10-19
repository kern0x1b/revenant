from conan import ConanFile
from conan.tools.gnu import Autotools, AutotoolsToolchain
from conan.tools.files import copy, chdir
from conan.tools.layout import basic_layout
from conan.tools.scm import Git
import os


class LibPslConan(ConanFile):
    name = "libpsl"
    user = "revenant"
    channel = "stable"
    description = "Public Suffix List library"
    license = "MIT"
    homepage = "https://github.com/rockdaboot/libpsl"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"

    def layout(self):
        basic_layout(self, src_folder="src")

    def source(self):
        source = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(source["url"], source["commit"])

    def generate(self):
        tc = AutotoolsToolchain(self)
        tc.configure_args += [
            "--disable-shared", "--enable-static",
            "--disable-runtime", "--disable-nls",
        ]
        tc.generate()

    def build(self):
        with chdir(self, self.source_folder):
            self.run("./autogen.sh" if os.path.exists(
                os.path.join(self.source_folder, "autogen.sh")) else "true")
        suffixes = os.path.join(self.source_folder, "list", "public_suffix_list.dat")
        committed = int(Git(self, os.path.dirname(suffixes)).run(
            "log -1 --format=%ct -- public_suffix_list.dat"))
        os.utime(suffixes, (committed, committed))
        autotools = Autotools(self)
        autotools.configure()
        autotools.make()

    def package(self):
        copy(self, "COPYING", self.source_folder, os.path.join(self.package_folder, "licenses"))
        copy(self, "libpsl.h", os.path.join(self.build_folder, "include"),
             os.path.join(self.package_folder, "include"))
        copy(self, "*.a", self.build_folder, os.path.join(self.package_folder, "lib"), keep_path=False)

    def package_info(self):
        self.cpp_info.libs = ["psl"]
