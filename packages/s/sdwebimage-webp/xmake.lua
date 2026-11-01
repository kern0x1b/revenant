package("sdwebimage-webp")
    set_homepage("https://github.com/SDWebImage/SDWebImageWebPCoder")
    set_description("SDWebImageWebPCoder 0.14.6, the WebP coder of SDWebImage that expo-image decodes WebP with, as a static libSDWebImageWebPCoder for armv7 iOS 6 built with ARC against libwebp and SDWebImage, its headers flattened under include/SDWebImageWebPCoder")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/SDWebImage/SDWebImageWebPCoder.git")
    add_versions("0.14.6", "f534cfe830a7807ecc3d0332127a502426cfa067")
    add_links("SDWebImageWebPCoder")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@sdwebimage 5.21.7", {alias = "sdwebimage"})
        package:add("deps", "revenant@libwebp 1.6.0", {alias = "libwebp"})
        package:add("frameworks", "CoreGraphics", "Accelerate")
    end)

    local PUBLIC_HEADERS = {"SDWebImageWebPCoder/Classes/*.h", "SDWebImageWebPCoder/Module/SDWebImageWebPCoder.h"}

    on_install("iphoneos", function (package)
        local sources = import("@addon.revenant.apple.sources", {anonymous = true})
        local headers = path.join(package:installdir("include"), "SDWebImageWebPCoder")
        os.mkdir(headers)
        for _, pattern in ipairs(PUBLIC_HEADERS) do
            for _, header in ipairs(os.files(pattern)) do
                local destination = path.join(headers, path.filename(header))
                assert(not os.isfile(destination), path.filename(header) .. " is in two folders of SDWebImageWebPCoder")
                os.cp(header, destination)
            end
        end
        os.mkdir(package:installdir("lib"))
        sources.static(package, {
            files = {"SDWebImageWebPCoder/Classes/*.m"},
            includedirs = {headers, "SDWebImageWebPCoder/Private"},
            mflags = {"-fobjc-arc"},
            deps = {"sdwebimage", "libwebp"},
            licenses = {"LICENSE"},
            name = "SDWebImageWebPCoder"
        })
    end)

    on_test(function (package)
        for _, file in ipairs({"lib/libSDWebImageWebPCoder.a", "include/SDWebImageWebPCoder/SDImageWebPCoder.h"}) do
            assert(os.isfile(path.join(package:installdir(), file)), file .. " is not installed")
        end
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        probe.require_architecture(path.join(package:installdir("lib"), "libSDWebImageWebPCoder.a"), "armv7")
    end)
