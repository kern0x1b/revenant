import os
import plistlib
import shutil

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.files import apply_conandata_patches, export_conandata_patches, get


class IphoneOSSdkConan(ConanFile):
    name = "iphoneos-sdk"
    user = "charon"
    channel = "stable"
    description = "The iPhoneOS SDK a build compiles and links against, fetched and verified on the machine that uses it"
    license = "LicenseRef-Apple-SDK"
    homepage = "https://github.com/theos/sdks"
    package_type = "build-scripts"
    upload_policy = "skip"
    no_copy_source = True

    @property
    def _folder(self):
        return f"iPhoneOS{self.version}.sdk"

    @property
    def _installed(self):
        return os.path.join("Platforms", "iPhoneOS.platform", "Developer", "SDKs", self._folder)

    def export_sources(self):
        export_conandata_patches(self)

    def source(self):
        get(self, **self.conan_data["sources"][self.version])
        apply_conandata_patches(self)

    def package(self):
        archived = self.conan_data["archive-folders"][self.version]
        sdk = os.path.join(self.source_folder, archived)
        with open(os.path.join(sdk, "SDKSettings.plist"), "rb") as handle:
            settings = plistlib.load(handle)
        if settings.get("CanonicalName") != f"iphoneos{self.version}":
            raise ConanException(f"{sdk} describes itself as {settings.get('CanonicalName')}, not "
                                 f"iphoneos{self.version}")
        shutil.copytree(sdk, os.path.join(self.package_folder, self._installed), symlinks=True)

    def package_info(self):
        self.cpp_info.includedirs = []
        self.cpp_info.libdirs = []
        self.cpp_info.bindirs = []
        self.conf_info.define("tools.apple:sdk_path", os.path.join(self.package_folder, self._installed))
