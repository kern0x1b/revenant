from conan import ConanFile
from conan.tools.cmake import CMake, CMakeDeps, CMakeToolchain, cmake_layout
from conan.tools.files import copy, rmdir
from conan.tools.scm import Git
import os


class LibXml2Conan(ConanFile):
    name = "libxml2"
    user = "revenant"
    channel = "stable"
    description = "XML parser and toolkit, linked into the engine instead of the 2010 copy iOS 6 ships"
    license = "MIT"
    homepage = "https://gitlab.gnome.org/GNOME/libxml2"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"

    def configure(self):
        self.settings.rm_safe("compiler.cppstd")
        self.settings.rm_safe("compiler.libcxx")

    def requirements(self):
        self.requires("icu/[>=78.3]@revenant/stable")

    def layout(self):
        cmake_layout(self, src_folder="src")

    def source(self):
        source = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(source["url"], source["commit"])

    def generate(self):
        tc = CMakeToolchain(self)
        tc.cache_variables.update({
            "BUILD_SHARED_LIBS": False,
            "LIBXML2_WITH_PROGRAMS": False,
            "LIBXML2_WITH_TESTS": False,
            "LIBXML2_WITH_PYTHON": False,
            "LIBXML2_WITH_DOCS": False,
            "LIBXML2_WITH_ICU": True,
            "LIBXML2_WITH_ICONV": False,
            "CMAKE_INSTALL_SYSCONFDIR": "/etc",
        })
        tc.extra_cflags.append("-fvisibility=hidden")
        tc.generate()
        CMakeDeps(self).generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        copy(self, "Copyright", self.source_folder, os.path.join(self.package_folder, "licenses"))
        cmake = CMake(self)
        cmake.install()
        for folder in ("cmake", "pkgconfig"):
            rmdir(self, os.path.join(self.package_folder, "lib", folder))
        rmdir(self, os.path.join(self.package_folder, "share"))
        rmdir(self, os.path.join(self.package_folder, "bin"))

    def package_info(self):
        self.cpp_info.set_property("cmake_file_name", "libxml2")
        self.cpp_info.set_property("cmake_target_name", "LibXml2::LibXml2")
        self.cpp_info.set_property("pkg_config_name", "libxml-2.0")
        self.cpp_info.libs = ["xml2"]
        self.cpp_info.includedirs = [os.path.join("include", "libxml2")]
        self.cpp_info.defines = ["LIBXML_STATIC"]
        self.cpp_info.requires = ["icu::icu-uc"]
