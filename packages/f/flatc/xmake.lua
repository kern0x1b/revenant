package("flatc")
    set_kind("binary")
    set_homepage("https://flatbuffers.dev")
    set_description("The FlatBuffers schema compiler, built for the host at the version Telegram pins: its Swift models are generated with it")
    set_license("Apache-2.0")
    set_policy("package.install_only", true)

    add_urls("https://github.com/google/flatbuffers/archive/refs/tags/v$(version).zip")
    add_versions("24.12.23", "c5cd6a605ff20350c7faa19d8eeb599df6117ea4aabd16ac58a7eb5ba82df4e7")

    on_install("@macosx", "@linux", function (package)
        local configs = {"-DCMAKE_BUILD_TYPE=Release", "-DFLATBUFFERS_BUILD_TESTS=OFF", "-DFLATBUFFERS_INSTALL=OFF",
                         "-DFLATBUFFERS_BUILD_FLATLIB=OFF", "-DFLATBUFFERS_BUILD_FLATHASH=OFF"}
        os.vrunv("cmake", table.join({"-S", ".", "-B", "build"}, configs))
        os.vrunv("cmake", {"--build", "build", "--target", "flatc", "--parallel", tostring(os.cpuinfo().ncpu)})
        os.cp("build/flatc", package:installdir("bin"))
        os.cp("LICENSE", package:installdir("licenses"))
    end)

    on_test(function (package)
        local output = os.iorunv(path.join(package:installdir("bin"), "flatc"), {"--version"})
        assert(output:find("24.12.23", 1, true), "flatc does not report version 24.12.23: " .. output)
    end)
