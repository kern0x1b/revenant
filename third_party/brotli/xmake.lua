package("brotli")
    set_homepage("https://github.com/google/brotli")
    set_description("Brotli, its decoder, encoder and common libraries as static libraries: what WebKit decodes WOFF2 fonts and brotli content with")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/google/brotli.git")
    add_versions("v1.2.0", "028fb5a23661f123017c060daa546b55cf4bde29")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("brotlienc", "brotlidec", "brotlicommon")

    on_install("iphoneos", function (package)
        local cmake = import("apple.cmake", {rootdir = path.join(package:scriptdir(), "..", "..", "toolchain", "modules"), anonymous = true})
        cmake.install(package, {"-DBROTLI_DISABLE_TESTS=ON", "-DBROTLI_BUILD_TOOLS=OFF", "-DBROTLI_BUNDLED_MODE=OFF"},
                      {licenses = "LICENSE", prune = {"lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        for _, library in ipairs({"brotlicommon", "brotlidec", "brotlienc"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), library .. " is not installed")
        end
        assert(os.isfile(path.join(package:installdir("include"), "brotli", "decode.h")))
    end)
