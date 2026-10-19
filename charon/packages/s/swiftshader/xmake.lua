package("swiftshader")
    set_kind("binary")
    set_homepage("https://swiftshader.googlesource.com/SwiftShader")
    set_description("A Vulkan implementation on the CPU, the ICD the emulator draws an old iOS's OpenGL ES through on a host without a usable GPU driver")
    set_license("Apache-2.0")

    add_urls("https://swiftshader.googlesource.com/SwiftShader.git", {submodules = false})
    add_versions("2026.09.16", "1e80438d2b93ef36a7c05f8d2b81233bac0e3d16")

    add_deps("cmake", "ninja", {kind = "binary"})

    on_install("macosx|arm64", function (package)
        import("package.tools.cmake").build(package, {"-DCMAKE_BUILD_TYPE=Release", "-DSWIFTSHADER_BUILD_TESTS=OFF",
                                                      "-DSWIFTSHADER_BUILD_BENCHMARKS=OFF", "-DSWIFTSHADER_BUILD_PVR=OFF",
                                                      "-DSWIFTSHADER_WARNINGS_AS_ERRORS=OFF"},
                                            {builddir = "build", target = "vk_swiftshader", cmake_generator = "Ninja"})
        local built = os.files(path.join("build", "**", "libvk_swiftshader.dylib"))[1]
        if not built then
            raise("the SwiftShader build left no libvk_swiftshader.dylib under build/")
        end
        os.cp(built, package:installdir("lib") .. "/")
        io.writefile(path.join(package:installdir("share", "vulkan", "icd.d"), "vk_swiftshader_icd.json"),
                     '{\n  "file_format_version": "1.0.0",\n  "ICD": {\n    "library_path": "../../../lib/libvk_swiftshader.dylib",\n    "api_version": "1.0.5"\n  }\n}\n')
        os.cp("LICENSE.txt", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libvk_swiftshader.dylib")))
        assert(os.isfile(path.join(package:installdir("share", "vulkan", "icd.d"), "vk_swiftshader_icd.json")))
    end)
