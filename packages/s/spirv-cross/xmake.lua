package("spirv-cross")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/KhronosGroup/SPIRV-Cross")
    set_description("SPIRV-Cross at 2de1265f (the 1.3.268+0 release of the xmake-repo recipe), its sources: the SPIR-V to GLSL back end the shader translator writes GLSL ES 1.00 with, unpatched so far")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/KhronosGroup/SPIRV-Cross/archive/2de1265fca722929785d9acdec4ab728c47a0254.tar.gz")
    add_versions("1.3.268+0", "3dcd276a804ad4f32543ddd45a88f28ccdaab59c05b51b6a2965f7390ef2d673")

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir(), "main.cpp")), "spirv-cross has no CLI source")
        assert(os.isfile(path.join(package:installdir(), "spirv_glsl.hpp")), "spirv-cross has no GLSL back end")
    end)
