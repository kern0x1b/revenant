package("libxslt")
    set_homepage("https://gitlab.gnome.org/GNOME/libxslt")
    set_description("libxslt and libexslt as static libraries over this tree's libxml2, which WebKit's XSLT processor runs on")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://gitlab.gnome.org/GNOME/libxslt.git")
    add_versions("v1.1.45", "35323d6a15f6e63c9919ddbc0abe64c90a0dd88a")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_deps("revenant@libxml2")
    add_links("exslt", "xslt")
    add_defines("LIBXSLT_STATIC", "LIBEXSLT_STATIC")

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, {"-DLIBXSLT_WITH_PROGRAMS=OFF", "-DLIBXSLT_WITH_TESTS=OFF", "-DLIBXSLT_WITH_PYTHON=OFF",
                                "-DLIBXSLT_WITH_PROFILER=OFF", "-DLIBXSLT_WITH_DEBUGGER=OFF", "-DLIBXSLT_WITH_CRYPTO=OFF",
                                "-DLIBXSLT_WITH_MODULES=OFF"},
                      {licenses = "Copyright", prune = {"lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        for _, library in ipairs({"xslt", "exslt"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), library .. " is not installed")
        end
        assert(os.isfile(path.join(package:installdir("include"), "libxslt", "xslt.h")))
    end)
