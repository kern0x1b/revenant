package("glslang")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/KhronosGroup/glslang")
    set_description("glslang at b5782e52 (the 1.4.335+0 release of the xmake-repo recipe, glslang 16.1.0 by its own numbering), its sources: the GLSL front end the shader translator compiles ES 3.00 with, unpatched so far")
    set_license("BSD-3-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/KhronosGroup/glslang/archive/b5782e52ee2f7b3e40bb9c80d15b47016e008bc9.tar.gz")
    add_versions("1.4.335+0", "6c242598c332050bf3a3619d299594ca2909426935f2c86c69c7356b049347c7")

    local patches = {
        {"0001-Print-the-shader-name-without-std-filesystem-on-iOS-6.patch", "d2a7e890d45758fe433bb5f8c58fec4ff854c3b8caefe67c213006def465db09"},
        {"0002-Keep-the-default-pool-allocator-in-static-storage.patch", "07c6b0e9e2b20ec059b21a64ae47f2ad40ee158ede29214a92fa4a24b962ab89"},
        {"0003-Refuse-allocation-requests-that-would-wrap-the-size.patch", "b8577f00efa5ef74ec69f580b54a6869abc5758e45a1af89abc25a7a7e8a8840"},
        {"0004-Refuse-pool-allocator-counts-that-would-wrap-the-byte-size.patch", "94e593b0cfd527286e6b607d43a5710e3106f66b1fae23869dda9aa74cd2ef47"}}

    local digests = {"xmake.lua=" .. hash.sha256(path.join(os.scriptdir(), "xmake.lua"))}
    for _, patch in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", patch[1])
        add_patches("1.4.335+0", file, patch[2])
        table.insert(digests, patch[1] .. "=" .. hash.sha256(file))
    end

    add_configs("recipe", {description = "The digest of this recipe and the patches it applies, so a changed recipe is a different package.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_load("iphoneos", function (package)
        package:add("defines", "DISABLE_THREAD_SUPPORT")
    end)

    on_install(function (package)
        os.cp("*", package:installdir() .. "/")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir(), "CMakeLists.txt")), "glslang has no CMake project")
        assert(os.isfile(path.join(package:installdir(), "glslang", "Public", "ShaderLang.h")), "glslang has no ShaderLang.h")
    end)
