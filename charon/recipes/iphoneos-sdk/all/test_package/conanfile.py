import os
import plistlib
from io import StringIO

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.layout import basic_layout


class TestPackage(ConanFile):
    settings = "os", "arch", "compiler", "build_type"
    test_type = "explicit"

    def build_requirements(self):
        self.tool_requires(self.tested_reference_str)

    def layout(self):
        basic_layout(self)

    def test(self):
        sdk = self.conf.get("tools.apple:sdk_path", check_type=str)
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"a consumer must receive tools.apple:sdk_path from the package: got {sdk}")
        version = self.dependencies.build["iphoneos-sdk"].ref.version
        if os.path.basename(sdk) != f"iPhoneOS{version}.sdk":
            raise ConanException(f"the linker reads the SDK version from the folder name, and {sdk} does not carry it")
        developer = os.path.dirname(os.path.dirname(sdk))
        if os.path.basename(os.path.dirname(sdk)) != "SDKs" or not developer.endswith(
                os.path.join("iPhoneOS.platform", "Developer")):
            raise ConanException(f"{sdk} is not laid out as Xcode lays it out, and build systems that derive "
                                 "<platform>/Developer/SDKs/<sdk> from it would not find it")
        with open(os.path.join(sdk, "SDKSettings.plist"), "rb") as handle:
            if plistlib.load(handle).get("CanonicalName") != f"iphoneos{version}":
                raise ConanException(f"{sdk} is not iphoneos{version}")
        for needed in ("usr/lib/libSystem.tbd", "usr/include/stdio.h"):
            if not os.path.exists(os.path.join(sdk, needed)):
                raise ConanException(f"{sdk} has no {needed}")
        probe = os.path.join(self.build_folder, "simd.c")
        with open(probe, "w") as handle:
            handle.write("#include <simd/base.h>\nint simd_library_version = SIMD_LIBRARY_VERSION;\n")
        preprocessed = StringIO()
        self.run(f'clang -target arm64-apple-ios12.0 -isysroot "{sdk}" -E "{probe}"', stdout=preprocessed)
        if "simd_library_version = 3;" not in preprocessed.getvalue():
            raise ConanException(f"{sdk} selects a simd library newer than iOS 12 has for an iOS 12 target, so "
                                 "simd calls reach functions that release does not export")
