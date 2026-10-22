package("opus")
    set_kind("library")
    set_homepage("https://opus-codec.org")
    set_description("The Opus audio codec as a static library for armv7 iOS 6: Telegram encodes its voice messages and calls with it, and its own build uses the same release")
    set_license("BSD-3-Clause")

    add_urls("https://downloads.xiph.org/releases/opus/opus-$(version).tar.gz")
    add_versions("1.5.1", "b84610959b8d417b611aa12a22565e0a3732097c6389d19098d844543e340f85")
    add_links("opus")

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local configs = {"-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DOPUS_BUILD_SHARED_LIBRARY=OFF", "-DOPUS_BUILD_PROGRAMS=OFF",
                         "-DOPUS_BUILD_TESTING=OFF", "-DOPUS_INSTALL_PKG_CONFIG_MODULE=OFF", "-DOPUS_INSTALL_CMAKE_CONFIG_MODULE=OFF"}
        cmake.install(package, configs, {licenses = "COPYING", prune = {"lib/pkgconfig", "lib/cmake", "share", "bin"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libopus.a")), "libopus.a is not installed")
        assert(os.isfile(path.join(package:installdir("include"), "opus", "opus.h")), "opus/opus.h is not installed")
        assert(os.isfile(path.join(package:installdir("include"), "opus", "opus_multistream.h")), "opus/opus_multistream.h is not installed")
    end)
