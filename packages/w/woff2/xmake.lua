package("woff2")
    set_homepage("https://github.com/google/woff2")
    set_description("WOFF2, its decoder and common libraries as static libraries against brotli, at the head of master: the one release is from 2017 and its build predates CMake 3.5")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/google/woff2.git")
    add_versions("2026.06.29", "fb9c3379f2605b10f3e8f1d9636664ab5576775c")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("revenant@brotli")
    add_deps("revenant@libcxx", {alias = "libcxx"})
    add_links("woff2dec", "woff2common")

    on_install("iphoneos", function (package)
        local cmake = import("apple.cmake", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "toolchain", "modules"), anonymous = true})
        local builddir = cmake.install(package, {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DCANONICAL_PREFIXES=ON"},
                                       {deps = true, targets = {"woff2common", "woff2dec"}, install = false})
        for _, library in ipairs({"woff2common", "woff2dec"}) do
            os.cp(path.join(builddir, "lib" .. library .. ".a"), package:installdir("lib") .. "/")
        end
        os.cp("include/woff2", package:installdir("include") .. "/")
        import("apple.install", {rootdir = path.join(package:scriptdir(), "..", "..", "..", "toolchain", "modules"), anonymous = true}).finish(package, {licenses = "LICENSE"})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libwoff2dec.a")))
        assert(os.isfile(path.join(package:installdir("include"), "woff2", "decode.h")))
    end)
