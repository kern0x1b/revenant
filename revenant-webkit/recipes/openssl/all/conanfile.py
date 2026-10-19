import os

from conan import ConanFile
from conan.errors import ConanException, ConanInvalidConfiguration
from conan.tools.files import apply_conandata_patches, copy, export_conandata_patches
from conan.tools.scm import Git


class OpenSSLConan(ConanFile):
    name = "openssl"
    user = "revenant"
    channel = "stable"
    description = ("OpenSSL, the newest release, through its own iOS Configure targets with the ARM assembly "
                   "kept; armv7 carries a perlasm fix for OPENSSL_armcap_P on Mach-O (openssl/openssl#26510)")
    license = "Apache-2.0"
    homepage = "https://www.openssl.org"
    package_type = "static-library"
    settings = "os", "arch", "compiler", "build_type"

    _configure_targets = {"armv7": "ios-xcrun", "armv8": "ios64-xcrun"}

    def export_sources(self):
        export_conandata_patches(self)

    def validate(self):
        if str(self.settings.arch) not in self._configure_targets:
            raise ConanInvalidConfiguration(f"OpenSSL has no iOS Configure target for {self.settings.arch}")

    def source(self):
        data = self.conan_data["sources"][self.version]
        Git(self).fetch_commit(url=data["url"], commit=data["commit"])
        apply_conandata_patches(self)

    def _environment(self):
        sdk = self.conf.get("tools.apple:sdk_path", check_type=str)
        if not sdk or not os.path.isdir(sdk):
            raise ConanException(f"tools.apple:sdk_path names {sdk or 'no SDK'}, and the compiler reads its sysroot "
                                 "from it through SDKROOT")
        commit_time = Git(self, folder=self.source_folder).run("log -1 --format=%ct")
        return {"SDKROOT": sdk, "SOURCE_DATE_EPOCH": commit_time}

    def build(self):
        arch = str(self.settings.arch)
        atomics = ["-DBROKEN_CLANG_ATOMICS"] if arch == "armv7" else []
        environment = " ".join(f'{key}="{value}"' for key, value in self._environment().items())
        options = ["no-shared", "no-dso", "no-tests", "no-docs", "no-apps", "no-ui-console", "no-engine", "no-async",
                   *atomics, f"-mios-version-min={self.settings.os.version}"]
        self.run(f'{environment} ./Configure {self._configure_targets[arch]} CC=cc {" ".join(options)}',
                 cwd=self.source_folder)
        self.run(f"{environment} make -j{os.cpu_count()} build_libs", cwd=self.source_folder)

    def package(self):
        copy(self, "LICENSE.txt", self.source_folder, os.path.join(self.package_folder, "licenses"))
        for library in ("libcrypto.a", "libssl.a"):
            copy(self, library, self.source_folder, os.path.join(self.package_folder, "lib"), keep_path=False)
        copy(self, "*.h", os.path.join(self.source_folder, "include", "openssl"),
             os.path.join(self.package_folder, "include", "openssl"))

    def package_info(self):
        self.cpp_info.libs = ["ssl", "crypto"]
