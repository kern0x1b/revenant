package("dynarmic")
    set_homepage("https://github.com/MC-XiaoXiao/dynarmic")
    set_description("Dynarmic, the ARM dynamic recompiler Shade runs a guest's CPU on: MC-XiaoXiao's tree at a commit, with our arm64 backend and test hooks as patches")
    set_license("0BSD")

    local commit = "21944ab87740a957c39ddd73cd4ecaeb700f7e73"
    local patches = {"0001-Apply-Charon-s-dynarmic-arm64-backend.patch",
                     "0002-tests-Implement-the-swap-callbacks-in-the-A32-test-e.patch",
                     "0003-Name-the-fault-injection-hooks-for-the-core-not-for-.patch"}
    add_urls("https://github.com/MC-XiaoXiao/dynarmic.git")
    add_versions("6.7.0", commit)

    local identity = {commit}
    for _, name in ipairs(patches) do
        local file = path.join(os.scriptdir(), "patches", name)
        local sha256 = hash.sha256(file)
        add_patches("6.7.0", file, sha256)
        table.insert(identity, name .. "=" .. sha256)
    end
    add_defines("DYNARMIC_BUILD_FINGERPRINT=0x" .. hash.strhash128(table.concat(identity, "\n")):sub(1, 16) .. "ULL")

    add_configs("test_emit_failure", {description = "Compile the fault-injection hooks of the portable emitter, for tests.", default = false, type = "boolean"})

    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("hades-third-party@boost 1.81.0")
    add_links("dynarmic", "mcl", "fmt")

    on_install("macosx|arm64", function (package)
        local boost = package:dep("boost"):installdir("include")
        local configs = {"-DCMAKE_BUILD_TYPE=Release",
                         "-DBUILD_SHARED_LIBS=OFF",
                         "-DDYNARMIC_FRONTENDS=A32",
                         "-DDYNARMIC_TESTS=OFF",
                         "-DDYNARMIC_ENABLE_TEST_EMIT_FAILURE=" .. (package:config("test_emit_failure") and "ON" or "OFF"),
                         "-DDYNARMIC_USE_BUNDLED_EXTERNALS=ON",
                         "-DDYNARMIC_USE_LLVM=OFF",
                         "-DDYNARMIC_WARNINGS_AS_ERRORS=OFF",
                         "-DDYNARMIC_USE_PRECOMPILED_HEADERS=OFF",
                         "-DBoost_NO_SYSTEM_PATHS=ON",
                         "-DBOOST_ROOT=" .. boost,
                         "-DBoost_INCLUDE_DIR=" .. boost}
        import("package.tools.cmake").install(package, configs, {cmake_generator = "Ninja"})
        os.cp("src/dynarmic/**.inc", package:installdir("include"), {rootdir = "src"})
        os.cp("LICENSE.txt", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("dynarmic/interface/A32/a32.h", {configs = {languages = "c++20"}}))
    end)
