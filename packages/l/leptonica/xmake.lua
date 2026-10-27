package("leptonica")
    set_kind("library")
    set_homepage("http://leptonica.org/")
    set_description("Leptonica 1.85.0, the image library Tesseract is built on: the static library without its image codecs, since the OCR takes its pixels from the caller")
    set_license("BSD-2-Clause")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/DanBloomberg/leptonica.git")
    add_versions("1.85.0", "63aef18d98432b8582a1565e241f7bd2ee9cc8d9")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("leptonica")

    local configs = {
        "-DBUILD_SHARED_LIBS=OFF",
        "-DBUILD_PROG=OFF",
        "-DENABLE_ZLIB=OFF",
        "-DENABLE_PNG=OFF",
        "-DENABLE_GIF=OFF",
        "-DENABLE_JPEG=OFF",
        "-DENABLE_TIFF=OFF",
        "-DENABLE_WEBP=OFF",
        "-DENABLE_OPENJPEG=OFF"
    }

    on_load(function (package)
        if package:is_plat("iphoneos") then
            package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        end
    end)

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, configs, {deps = {"libcxx"}, licenses = "leptonica-license.txt"})
    end)

    on_install("macosx", function (package)
        import("package.tools.cmake").install(package, configs, {cmake_generator = "Ninja"})
        os.cp("leptonica-license.txt", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libleptonica.a")))
        assert(os.isfile(path.join(package:installdir("include"), "leptonica", "allheaders.h")))
    end)
