package("zxing-cpp")
    set_kind("library")
    set_homepage("https://github.com/zxing-cpp/zxing-cpp")
    set_description("ZXing-C++ 3.1.1 QR and PDF417 readers for Vision barcode detection")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/zxing-cpp/zxing-cpp.git")
    add_versions("v3.1.1", "287c85df6f961c8efbfb5ffd736cd9457b8b890e")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("ZXing")
    on_load(function (package)
        if package:is_plat("iphoneos") then
            package:add("deps", "revenant@libcxx", {alias = "libcxx"})
        end
    end)

    local configs = {
        "-DBUILD_SHARED_LIBS=OFF",
        "-DZXING_READERS=ON",
        "-DZXING_WRITERS=OLD",
        "-DZXING_USE_BUNDLED_ZINT=OFF",
        "-DZXING_ENABLE_1D=OFF",
        "-DZXING_ENABLE_AZTEC=OFF",
        "-DZXING_ENABLE_DATAMATRIX=OFF",
        "-DZXING_ENABLE_MAXICODE=OFF",
        "-DZXING_ENABLE_PDF417=ON",
        "-DZXING_ENABLE_QRCODE=ON"
    }

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        cmake.install(package, table.join(configs, {"-DCMAKE_CXX_STANDARD=20"}), {deps = {"libcxx"}, licenses = "LICENSE"})
    end)

    on_install("macosx", function (package)
        import("package.tools.cmake").install(package, table.join(configs, {"-DCMAKE_CXX_STANDARD=20"}), {cmake_generator = "Ninja"})
        os.cp("LICENSE", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libZXing.a")))
        assert(os.isfile(path.join(package:installdir("include"), "ZXing", "ReadBarcode.h")))
    end)
