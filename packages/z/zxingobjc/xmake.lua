package("zxingobjc")
    set_homepage("https://github.com/TheLevelUp/ZXingObjC")
    set_description("ZXingObjC 3.6.4, the Objective-C port of ZXing that expo-camera reads PDF417 and one-dimensional codes with, as a static libZXingObjC for armv7 iOS 6 built with ARC, its Core, OneD and PDF417 subspecs and the frameworks of that release")
    set_license("Apache-2.0")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/TheLevelUp/ZXingObjC.git")
    add_versions("3.6.4", "cac61d5404b3ee75fca58433dd2ae825c631e4ee")
    add_links("ZXingObjC")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_load("iphoneos", function (package)
        package:add("frameworks", "AVFoundation", "CoreGraphics", "CoreMedia", "CoreVideo", "ImageIO", "QuartzCore")
    end)

    local SOURCES = {
        "ZXingObjC/*.m", "ZXingObjC/client/*.m", "ZXingObjC/client/result/*.m",
        "ZXingObjC/common/*.m", "ZXingObjC/common/**/*.m", "ZXingObjC/core/*.m", "ZXingObjC/multi/*.m",
        "ZXingObjC/oned/*.m", "ZXingObjC/oned/**/*.m", "ZXingObjC/pdf417/*.m", "ZXingObjC/pdf417/**/*.m"
    }

    local SUBSPECS = {"ZXINGOBJC_USE_SUBSPECS", "ZXINGOBJC_ONED", "ZXINGOBJC_PDF417"}

    local HEADERS = {
        "ZXingObjC/*.h", "ZXingObjC/client/*.h", "ZXingObjC/client/result/*.h",
        "ZXingObjC/common/*.h", "ZXingObjC/common/**/*.h", "ZXingObjC/core/*.h", "ZXingObjC/multi/*.h",
        "ZXingObjC/oned/*.h", "ZXingObjC/oned/**/*.h", "ZXingObjC/pdf417/*.h", "ZXingObjC/pdf417/**/*.h"
    }

    on_install("iphoneos", function (package)
        local sources = import("@addon.revenant.apple.sources", {anonymous = true})
        local staged = path.join(package:cachedir(), "staged")
        local installed = path.join(package:installdir("include"), "ZXingObjC")
        os.rm(staged)
        os.mkdir(path.join(staged, "ZXingObjC"))
        os.mkdir(installed)
        for _, pattern in ipairs(HEADERS) do
            for _, header in ipairs(os.files(pattern)) do
                local name = path.filename(header)
                assert(not os.isfile(path.join(staged, "ZXingObjC", name)), name .. " is in two folders of ZXingObjC")
                os.ln(header, path.join(staged, "ZXingObjC", name))
                os.cp(header, path.join(installed, name))
            end
        end
        local folders = table.join({staged, "ZXingObjC"}, os.dirs("ZXingObjC/**"))
        os.mkdir(package:installdir("lib"))
        sources.static(package, {
            files = SOURCES,
            includedirs = folders,
            defines = SUBSPECS,
            mflags = {"-fobjc-arc", "-include", path.absolute("ios-Prefix.pch")},
            licenses = {"COPYING", "NOTICE"},
            prune = {"lib/pkgconfig"},
            name = "ZXingObjC"
        })
    end)

    on_test(function (package)
        for _, file in ipairs({"lib/libZXingObjC.a", "include/ZXingObjC/ZXMultiFormatWriter.h", "include/ZXingObjC/ZXEAN13Reader.h"}) do
            assert(os.isfile(path.join(package:installdir(), file)), file .. " is not installed")
        end
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        probe.require_architecture(path.join(package:installdir("lib"), "libZXingObjC.a"), "armv7")
    end)
