package("spirv-cross")
    set_kind("library")
    set_homepage("https://github.com/KhronosGroup/SPIRV-Cross")
    set_description("SPIRV-Cross at 2de1265f (the 1.3.268+0 release of the xmake-repo recipe) as static libraries for armv7 iOS 6: the SPIR-V to GLSL back end the shader translator writes GLSL ES 1.00 with")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/KhronosGroup/SPIRV-Cross/archive/2de1265fca722929785d9acdec4ab728c47a0254.tar.gz")
    add_versions("1.3.268+0", "3dcd276a804ad4f32543ddd45a88f28ccdaab59c05b51b6a2965f7390ef2d673")

    add_links("spirv-cross-glsl", "spirv-cross-core")

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local configs = {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DSPIRV_CROSS_SHARED=OFF", "-DSPIRV_CROSS_STATIC=ON",
                         "-DSPIRV_CROSS_CLI=OFF", "-DSPIRV_CROSS_ENABLE_TESTS=OFF", "-DSPIRV_CROSS_ENABLE_GLSL=ON",
                         "-DSPIRV_CROSS_ENABLE_HLSL=OFF", "-DSPIRV_CROSS_ENABLE_MSL=OFF", "-DSPIRV_CROSS_ENABLE_CPP=OFF",
                         "-DSPIRV_CROSS_ENABLE_REFLECT=OFF", "-DSPIRV_CROSS_ENABLE_C_API=OFF", "-DSPIRV_CROSS_ENABLE_UTIL=OFF"}
        cmake.install(package, configs, {licenses = "LICENSE", prune = {"lib/cmake", "lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libspirv-cross-core.a")), "libspirv-cross-core.a is not installed")
        assert(os.isfile(path.join(package:installdir("lib"), "libspirv-cross-glsl.a")), "libspirv-cross-glsl.a is not installed")
        assert(os.isfile(path.join(package:installdir("include"), "spirv_cross", "spirv_glsl.hpp")), "spirv-cross has no GLSL back end header")
    end)
