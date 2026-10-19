from conan import ConanFile
from conan.tools.files import apply_conandata_patches, chdir, copy, export_conandata_patches, get
from conan.errors import ConanInvalidConfiguration
import os
import shutil


class Ld64Armv7Conan(ConanFile):
    name = "ld64"
    user = "charon"
    channel = "stable"
    description = "Apple's ld64 from cctools-port, the linker that still inserts branch islands for armv7"
    license = ("APSL-2.0", "Apache-2.0 WITH LLVM-exception")
    homepage = "https://github.com/tpoechtrager/cctools-port"
    package_type = "application"
    settings = "os", "arch", "compiler", "build_type"

    def validate(self):
        if self.settings_build.os != "Macos":
            raise ConanInvalidConfiguration("this package builds on macOS")

    def _llvm_prefix(self):
        prefix = self.conf.get("user.ld64:llvm_prefix", check_type=str)
        if not prefix or not os.path.isdir(prefix):
            raise ConanInvalidConfiguration(
                "user.ld64:llvm_prefix does not name an LLVM. cctools' configure asks llvm-config where "
                "libLTO is, and a linker built without it drops LTO support, which this target builds with. "
                "The ios6-armv7 profile takes the path from LLVM_PREFIX; set it to a full LLVM, such as "
                "`brew --prefix llvm`.")
        return prefix

    def export_sources(self):
        export_conandata_patches(self)

    def source(self):
        data = self.conan_data["sources"][self.version]
        get(self, url=data["libtapi"]["url"], sha256=data["libtapi"]["sha256"], strip_root=True,
            destination="libtapi")
        get(self, **data["cctools"], strip_root=True, destination="cctools-port")
        apply_conandata_patches(self)

    def build(self):
        llvm = self._llvm_prefix()
        tapi_version = self.conan_data["sources"][self.version]["libtapi"]["version"]
        tapi_install = os.path.join(self.build_folder, "tapi-install")
        tapi_build = os.path.join(self.build_folder, "tapi-build")
        os.makedirs(tapi_build, exist_ok=True)
        with chdir(self, tapi_build):
            self.run(f'cmake -G Ninja "{os.path.join(self.source_folder, "libtapi", "src", "llvm")}"'
                     " -DCMAKE_BUILD_TYPE=Release"
                     f' -DCMAKE_INSTALL_PREFIX="{tapi_install}"'
                     ' -DLLVM_ENABLE_PROJECTS="tapi;clang"'
                     " -DLLVM_TARGETS_TO_BUILD=host"
                     " -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF"
                     " -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_DOCS=OFF"
                     " -DLLVM_BUILD_TOOLS=OFF -DCLANG_BUILD_TOOLS=OFF"
                     f" -DTAPI_REPOSITORY_STRING={tapi_version} -DTAPI_FULL_VERSION={tapi_version}")
            self.run(f"cmake --build . --parallel {os.cpu_count()} --target clangBasic vt_gen")
            self.run(f"cmake --build . --parallel {os.cpu_count()} --target libtapi")
            self.run("cmake --build . --target install-libtapi install-tapi-headers")

        cctools = os.path.join(self.source_folder, "cctools-port", "cctools")
        install = os.path.join(self.build_folder, "cctools-install")
        with chdir(self, cctools):
            self.run(f'CPPFLAGS="-I{llvm}/include" ./configure'
                     f' --prefix="{install}" --target=arm-apple-darwin11'
                     f' --with-libtapi="{tapi_install}"'
                     f' --with-llvm-config="{llvm}/bin/llvm-config"')
            for part in ("ld64/src/3rd", "ld64/src/mach_o", "ld64/src/ld"):
                self.run(f"make -C {part} -j{os.cpu_count()}")
            self.run("make -C ld64/src/ld install-binPROGRAMS")

    def package(self):
        install = os.path.join(self.build_folder, "cctools-install")
        tapi_install = os.path.join(self.build_folder, "tapi-install")
        copy(self, "arm-apple-darwin11-ld", os.path.join(install, "bin"),
             os.path.join(self.package_folder, "bin"))
        copy(self, "libtapi.dylib", os.path.join(tapi_install, "lib"),
             os.path.join(self.package_folder, "lib"))
        licenses = os.path.join(self.package_folder, "licenses")
        copy(self, "APPLE_LICENSE", os.path.join(self.source_folder, "cctools-port", "cctools", "ld64"),
             os.path.join(licenses, "ld64"))
        copy(self, "LICENSE.txt", os.path.join(self.source_folder, "libtapi", "src"),
             os.path.join(licenses, "libtapi"))
        copy(self, "LICENSE.*.txt", os.path.join(self.source_folder, "libtapi"),
             os.path.join(licenses, "libtapi"))
        ld = os.path.join(self.package_folder, "bin", "arm-apple-darwin11-ld")
        os.symlink("arm-apple-darwin11-ld", os.path.join(self.package_folder, "bin", "ld"))
        self.run(f'install_name_tool -rpath "{tapi_install}/lib" @executable_path/../lib "{ld}"')

    def package_info(self):
        self.cpp_info.includedirs = []
        self.cpp_info.libdirs = []
        bindir = os.path.join(self.package_folder, "bin")
        self.buildenv_info.append_path("PATH", bindir)
        # -B is what makes the compiler driver pick this ld over the system one.
        self.conf_info.append("tools.build:exelinkflags", f"-B{bindir}")
        self.conf_info.append("tools.build:sharedlinkflags", f"-B{bindir}")
