from conan import ConanFile
from conan.tools.cmake import CMake, CMakeDeps, CMakeToolchain, cmake_layout
from conan.tools.files import copy, rmdir
from conan.tools.scm import Git
import os


class LibXsltConan(ConanFile):
    name = "libxslt"
    user = "revenant"
    channel = "stable"
    description = "XSLT and EXSLT, built against the libxml2 package"
    license = "MIT"
    homepage = "https://gitlab.gnome.org/GNOME/libxslt"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"

    def configure(self):
        self.settings.rm_safe("compiler.cppstd")
        self.settings.rm_safe("compiler.libcxx")

    def requirements(self):
        self.requires("libxml2/2.15.4@revenant/stable", transitive_headers=True)

    def layout(self):
        cmake_layout(self, src_folder="src")

    def source(self):
        source = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(source["url"], source["commit"])

    def generate(self):
        tc = CMakeToolchain(self)
        tc.cache_variables.update({
            "BUILD_SHARED_LIBS": False,
            "LIBXSLT_WITH_PROGRAMS": False,
            "LIBXSLT_WITH_TESTS": False,
            "LIBXSLT_WITH_PYTHON": False,
            "LIBXSLT_WITH_PROFILER": False,
            "LIBXSLT_WITH_DEBUGGER": False,
            "LIBXSLT_WITH_CRYPTO": False,
            "LIBXSLT_WITH_MODULES": False,
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
        self.cpp_info.set_property("cmake_file_name", "LibXslt")
        xslt = self.cpp_info.components["xslt"]
        xslt.set_property("cmake_target_name", "LibXslt::LibXslt")
        xslt.libs = ["xslt"]
        xslt.defines = ["LIBXSLT_STATIC"]
        xslt.requires = ["libxml2::libxml2"]
        exslt = self.cpp_info.components["exslt"]
        exslt.set_property("cmake_target_name", "LibXslt::LibExslt")
        exslt.libs = ["exslt"]
        exslt.defines = ["LIBEXSLT_STATIC"]
        exslt.requires = ["xslt"]
