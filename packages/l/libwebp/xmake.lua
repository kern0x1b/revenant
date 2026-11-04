package("libwebp")
    set_homepage("https://chromium.googlesource.com/webm/libwebp")
    set_description("libwebp, its decoder and demuxer as static libraries: WebKit decodes WebP itself, since the ImageIO of iOS 6 cannot")
    set_license("BSD-3-Clause")
    if is_mode("debug") then
        add_configs("debug", {description = "Build in the Debug configuration, which the debug mode of the project asks for.", default = true, readonly = true})
    end
    set_policy("package.strict_compatibility", true)

    add_urls("https://chromium.googlesource.com/webm/libwebp.git")
    add_versions("v1.6.0", "4fa21912338357f89e4fd51cf2368325b59e9bd9")
    add_deps("cmake", "ninja", {kind = "binary"})
    add_links("webpmux", "webpdemux", "webp", "sharpyuv")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_install("iphoneos", function (package)
        local cmake = import("@addon.revenant.apple.cmake", {anonymous = true})
        local configs = {}
        for _, tool in ipairs({"ANIM_UTILS", "CWEBP", "DWEBP", "GIF2WEBP", "IMG2WEBP", "VWEBP", "WEBPINFO", "WEBPMUX", "EXTRAS"}) do
            table.insert(configs, "-DWEBP_BUILD_" .. tool .. "=OFF")
        end
        cmake.install(package, configs, {licenses = "COPYING", prune = {"lib/pkgconfig", "share", "bin"}})
    end)

    on_test(function (package)
        for _, library in ipairs({"webp", "webpdemux", "webpmux", "sharpyuv"}) do
            assert(os.isfile(path.join(package:installdir("lib"), "lib" .. library .. ".a")), library .. " is not installed")
        end
        assert(os.isfile(path.join(package:installdir("include"), "webp", "demux.h")))
    end)
