from conan import ConanFile
from conan.errors import ConanException
from conan.tools.cmake import CMake, CMakeToolchain, cmake_layout
from conan.tools.files import copy
import glob
import os


class RevenantDeviceToolsConan(ConanFile):
    name = "revenant-device-tools"
    version = "1.0.0"
    user = "revenant"
    channel = "stable"
    description = "Command-line probes the port runs on the phone: process list, memory by VM tag, synthetic touch, jetsam limit"
    license = "MIT"
    package_type = "application"
    settings = "os", "arch", "compiler", "build_type"

    _entitlements = "entitlements"
    _launchd = "LaunchDaemons"

    def export_sources(self):
        root = os.path.join(self.recipe_folder, "..", "..", "..")
        copy(self, "CMakeLists.txt", self.recipe_folder, self.export_sources_folder)
        copy(self, "*.xml", os.path.join(self.recipe_folder, self._entitlements),
             os.path.join(self.export_sources_folder, self._entitlements))
        copy(self, "LICENSE", root, self.export_sources_folder)
        copy(self, "*.c", os.path.join(root, "tools"), os.path.join(self.export_sources_folder, "tools"))
        copy(self, "*.plist", os.path.join(root, "platform", "device"),
             os.path.join(self.export_sources_folder, "platform", "device"))

    def configure(self):
        self.settings.rm_safe("compiler.cppstd")
        self.settings.rm_safe("compiler.libcxx")

    def build_requirements(self):
        self.tool_requires("ldid/2.1.5@charon/stable")

    def layout(self):
        cmake_layout(self, src_folder=".")

    def generate(self):
        CMakeToolchain(self).generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def _installed(self):
        manifests = glob.glob(os.path.join(self.build_folder, "**", "install_manifest.txt"), recursive=True)
        if not manifests:
            raise ConanException("cmake wrote no install_manifest.txt, so what was installed is unknown")
        with open(manifests[0]) as handle:
            return [line.strip() for line in handle if line.strip()]

    def package(self):
        cmake = CMake(self)
        cmake.install()
        copy(self, "LICENSE", self.source_folder, os.path.join(self.package_folder, "licenses"))
        entitlements = os.path.join(self.source_folder, self._entitlements)
        copy(self, "*.xml", entitlements, os.path.join(self.package_folder, "res", self._entitlements))
        copy(self, "*.plist", os.path.join(self.source_folder, "platform", "device"),
             os.path.join(self.package_folder, "res", self._launchd))
        for installed in self._installed():
            document = os.path.join(entitlements, f"{os.path.basename(installed)}.xml")
            self.run(f'ldid -S{document if os.path.isfile(document) else ""} "{installed}"')

    def package_info(self):
        self.cpp_info.includedirs = []
        self.cpp_info.libdirs = []
        self.cpp_info.bindirs = ["bin"]
        self.cpp_info.resdirs = ["res"]
        self.conf_info.define_path("user.revenant:device_tools_launchd",
                                   os.path.join(self.package_folder, "res", self._launchd))
