import os
from io import StringIO

from conan import ConanFile
from conan.errors import ConanException
from conan.tools.apple import to_apple_arch
from conan.tools.cmake import CMake, CMakeToolchain
from conan.tools.files import apply_conandata_patches, copy, export_conandata_patches


class LibCxxArmv7Conan(ConanFile):
    name = "libcxx"
    user = "charon"
    channel = "stable"
    description = "The C++ runtime for armv7 / iOS 6, which no SDK of that era ships"
    license = "Apache-2.0 WITH LLVM-exception"
    homepage = "https://libcxx.llvm.org"
    package_type = "shared-library"
    settings = "os", "arch", "compiler", "build_type"

    def requirements(self):
        self.requires("apple-compat/1.0@charon/stable", headers=False, libs=False, visible=False,
                      package_id_mode="full_mode")

    @property
    def _compat(self):
        compat = self.dependencies["apple-compat"]
        return compat, list(compat.cpp_info.get_property("charon_provides") or [])

    def export_sources(self):
        export_conandata_patches(self)

    def source(self):
        source = self.conan_data["sources"][self.version]
        self.run(f'git clone --depth 1 --branch {source["tag"]} --filter=blob:none '
                 f'--sparse {source["url"]} llvm-project')
        checked_out = StringIO()
        self.run("git -C llvm-project rev-parse HEAD", stdout=checked_out)
        if checked_out.getvalue().strip() != source["commit"]:
            raise ConanException(f"{source['tag']} is {checked_out.getvalue().strip()} now, not the "
                                 f"{source['commit']} this recipe was written against; a tag that moved is not "
                                 "the release it names")
        self.run("git -C llvm-project sparse-checkout set libcxx libcxxabi libunwind "
                 "runtimes cmake third-party llvm/cmake llvm/utils/llvm-lit libc")
        apply_conandata_patches(self)

    def generate(self):
        sdk = self.conf.get("tools.apple:sdk_path")
        tc = CMakeToolchain(self)
        tc.extra_cflags += ["-mllvm", "-hot-cold-split=false"]
        tc.extra_cxxflags += ["-mllvm", "-hot-cold-split=false",
                              "-D_LIBCPP_NO_UTIMENSAT"]
        compat, provided = self._compat
        if provided:
            headers = os.path.join(compat.package_folder, "include")
            for header in compat.cpp_info.get_property("charon_force_includes") or []:
                tc.extra_cxxflags.append(f"-include {os.path.join(headers, header)}")
            tc.extra_sharedlinkflags += [f"-L{os.path.join(compat.package_folder, 'lib')}",
                                         "-Wl,-hidden-lapple-compat"]
        tc.cache_variables.update({
            "CMAKE_SYSTEM_NAME": "Darwin",
            "CMAKE_OSX_SYSROOT": sdk,
            "CMAKE_OSX_ARCHITECTURES": to_apple_arch(self),
            "LLVM_ENABLE_RUNTIMES": "libcxx;libcxxabi",
            "LIBCXX_ENABLE_SHARED": True,
            "LIBCXXABI_ENABLE_SHARED": True,
            "LIBCXX_ENABLE_STATIC": False,
            "LIBCXXABI_ENABLE_STATIC": False,
            "LIBCXX_CXX_ABI": "libcxxabi",
            "LIBCXXABI_USE_LLVM_UNWINDER": False,
            "LIBCXX_INCLUDE_BENCHMARKS": False,
            "LIBCXX_INCLUDE_TESTS": False,
            "LIBCXXABI_INCLUDE_TESTS": False,
        })
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure(build_script_folder=os.path.join("llvm-project", "runtimes"))
        cmake.build()
        _, provided = self._compat
        cmake.install()
        for library in ("libc++.1.0.dylib", "libc++abi.1.0.dylib"):
            imports = StringIO()
            self.run(f'xcrun nm -u "{os.path.join(self.package_folder, "lib", library)}"', stdout=imports)
            imported = {name[1:] for name in imports.getvalue().split() if name.startswith("_")}
            leaked = sorted((set(provided) | {f"charon_{symbol}" for symbol in provided}) & imported)
            if leaked:
                raise ConanException(f"{library} still imports {', '.join(leaked)} from the system, which "
                                     f"{self.settings.os} {self.settings.os.version} does not have; apple-compat "
                                     "was not linked into it")

    def package(self):
        copy(self, "LICENSE.TXT", os.path.join(self.source_folder, "llvm-project", "libcxx"),
             os.path.join(self.package_folder, "licenses"))

    def package_info(self):
        headers = self.cpp_info.components["headers"]
        headers.includedirs = [os.path.join("include", "c++", "v1")]
        headers.cxxflags = ["-nostdinc++"]
        headers.libdirs = []
        headers.bindirs = []
        runtime = self.cpp_info.components["runtime"]
        runtime.requires = ["headers"]
        runtime.includedirs = []
        runtime.libs = ["c++", "c++abi"]
        runtime.defines = ["_LIBCPP_DISABLE_AVAILABILITY"]
