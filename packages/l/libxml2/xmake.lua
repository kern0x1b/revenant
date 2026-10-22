package("libxml2")
    set_homepage("https://gitlab.gnome.org/GNOME/libxml2")
    set_description("libxml2 as a static library over ICU and without iconv, linked into WebKit in place of the 2010 copy iOS 6 ships")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://gitlab.gnome.org/GNOME/libxml2.git")
    add_versions("v2.15.4", "96498992efa48d52b0e8b83058bd88dbdaf153c1")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("revenant@icu")
    add_links("xml2")
    add_includedirs("include", "include/libxml2")
    add_defines("LIBXML_STATIC")

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, {"-DLIBXML2_WITH_PROGRAMS=OFF", "-DLIBXML2_WITH_TESTS=OFF", "-DLIBXML2_WITH_PYTHON=OFF",
                                "-DLIBXML2_WITH_DOCS=OFF", "-DLIBXML2_WITH_ICU=ON", "-DLIBXML2_WITH_ICONV=OFF",
                                "-DICU_INCLUDE_DIR=" .. path.join(package:dep("icu"):installdir(), "include"),
                                "-DICU_UC_LIBRARY=" .. path.join(package:dep("icu"):installdir(), "lib", "libicuuc.a"),
                                "-DICU_I18N_LIBRARY=" .. path.join(package:dep("icu"):installdir(), "lib", "libicui18n.a"),
                                "-DICU_DATA_LIBRARY=" .. path.join(package:dep("icu"):installdir(), "lib", "libicudata.a"),
                                "-DCMAKE_INSTALL_SYSCONFDIR=/etc"},
                      {cflags = {"-fvisibility=hidden"}, licenses = "Copyright", prune = {"lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libxml2.a")))
        assert(os.isfile(path.join(package:installdir("include"), "libxml2", "libxml", "parser.h")))
    end)
