package("mozjpeg")
    set_kind("library")
    set_homepage("https://github.com/mozilla/mozjpeg")
    set_description("mozjpeg, the JPEG encoder Telegram writes its photos with, as static libjpeg and libturbojpeg for armv7 iOS 6, at master commit 61e03cc6, the snapshot Telegram vendors (4.1.4 plus 22 commits)")
    set_license("BSD-3-Clause")

    add_urls("https://github.com/mozilla/mozjpeg.git")
    add_versions("4.1.4-22", "61e03cc6b25ea506085dce1ee93ddd1f4b6588e6")
    add_links("turbojpeg", "jpeg")

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local configs = {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DPNG_SUPPORTED=FALSE", "-DENABLE_SHARED=FALSE",
                         "-DWITH_JPEG8=1", "-DBUILD=10000", "-DCMAKE_INSTALL_LIBDIR=" .. path.join(package:installdir(), "lib")}
        cmake.install(package, configs, {licenses = "LICENSE.md", prune = {"lib/pkgconfig", "lib/cmake", "share", "bin"}})
    end)

    on_test(function (package)
        for _, library in ipairs({"jpeg", "turbojpeg"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), "lib" .. library .. ".a is not installed")
        end
        for _, header in ipairs({"turbojpeg.h", "jpeglib.h", "jmorecfg.h", "jconfig.h"}) do
            assert(os.isfile(path.join(package:installdir("include"), header)), header .. " is not installed")
        end
    end)
