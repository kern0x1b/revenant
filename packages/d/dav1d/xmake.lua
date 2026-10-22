package("dav1d")
    set_kind("library")
    set_homepage("https://code.videolan.org/videolan/dav1d")
    set_description("dav1d, the AV1 decoder Telegram decodes with, as a static libdav1d for armv7 iOS 6, at 1.5.0 plus 23 commits, the snapshot Telegram vendors")
    set_license("BSD-2-Clause")

    add_urls("https://github.com/videolan/dav1d.git")
    add_versions("1.5.0-23", "330e20672e85f9de1678dccd6957845898ef57a1")
    add_deps("revenant@meson", {kind = "binary", host = true})
    add_deps("ninja", {kind = "binary", host = true})
    add_links("dav1d")

    on_install("iphoneos", function (package)
        import("package.tools.meson").install(package, {"-Denable_tools=false", "-Denable_tests=false",
            "-Denable_examples=false"})
        import("@addon.revenant.apple.install", {anonymous = true}).finish(package, {
            licenses = "COPYING", prune = {"lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libdav1d.a")), "libdav1d.a is not installed")
        for _, header in ipairs({"dav1d/dav1d.h", "dav1d/version.h", "dav1d/picture.h"}) do
            assert(os.isfile(path.join(package:installdir("include"), header)), header .. " is not installed")
        end
    end)
