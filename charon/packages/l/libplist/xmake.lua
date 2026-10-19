package("libplist")
    set_homepage("https://github.com/libimobiledevice/libplist")
    set_description("Reads and writes Apple property lists, for the tools that sign and package what a port builds")
    set_license("LGPL-2.1-or-later")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/libimobiledevice/libplist/releases/download/$(version)/libplist-$(version).tar.bz2")
    add_versions("2.7.0", "7ac42301e896b1ebe3c654634780c82baa7cb70df8554e683ff89f7c2643eb8b")
    add_links("plist++-2.0", "plist-2.0")
    add_defines("LIBPLIST_STATIC")

    on_install("macosx", function (package)
        import("package.tools.autoconf").install(package, {"--disable-shared", "--enable-static", "--without-cython",
                                                           "--without-tools", "--without-tests"})
        os.cp("COPYING.LESSER", package:installdir("licenses"))
        os.tryrm(package:installdir("lib", "pkgconfig"))
        os.tryrm(package:installdir("share"))
    end)

    on_test(function (package)
        assert(package:has_cfuncs("plist_new_dict", {includes = "plist/plist.h"}))
    end)
