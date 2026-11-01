package("sdwebimage")
    set_homepage("https://github.com/SDWebImage/SDWebImage")
    set_description("SDWebImage 5.21.7, the asynchronous image loader and cache expo-image draws its images with, as a static libSDWebImage for armv7 iOS 6 built with ARC, its headers flattened under include/SDWebImage")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/SDWebImage/SDWebImage.git")
    add_versions("5.21.7", "2de3a496eaf6df9a1312862adcfd54acd73c39c0")
    add_links("SDWebImage")
    add_configs("revision", {description = "Raised when the install script changes, since the script is not part of the install path.", default = "1", readonly = true})

    on_load("iphoneos", function (package)
        package:add("frameworks", "Foundation", "UIKit", "ImageIO", "CoreGraphics", "QuartzCore", "CoreImage", "Accelerate", "CoreServices", "MobileCoreServices", "CoreVideo")
    end)

    local PUBLIC_HEADERS = {"SDWebImage/Core/*.h", "SDWebImage/Private/*.h", "WebImage/SDWebImage.h"}

    on_install("iphoneos", function (package)
        local sources = import("@addon.revenant.apple.sources", {anonymous = true})
        local staged = path.join(package:cachedir(), "staged", "SDWebImage")
        local installed = path.join(package:installdir("include"), "SDWebImage")
        os.rm(path.join(package:cachedir(), "staged"))
        os.mkdir(staged)
        os.mkdir(installed)
        for _, pattern in ipairs(PUBLIC_HEADERS) do
            for _, header in ipairs(os.files(pattern)) do
                local name = path.filename(header)
                assert(not os.isfile(path.join(staged, name)), name .. " is in two folders of SDWebImage")
                os.ln(header, path.join(staged, name))
                os.cp(header, path.join(installed, name))
            end
        end
        os.mkdir(package:installdir("lib"))
        sources.static(package, {
            files = {"SDWebImage/Core/*.m", "SDWebImage/Private/*.m"},
            includedirs = {path.directory(staged), path.absolute("SDWebImage/Core"), path.absolute("SDWebImage/Private")},
            mflags = {"-fobjc-arc"},
            prune = {"lib/pkgconfig"},
            licenses = {"LICENSE"},
            name = "SDWebImage"
        })
    end)

    on_test(function (package)
        for _, file in ipairs({"lib/libSDWebImage.a", "include/SDWebImage/SDWebImage.h", "include/SDWebImage/NSData+ImageContentType.h"}) do
            assert(os.isfile(path.join(package:installdir(), file)), file .. " is not installed")
        end
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {name = "probe.m", source = [[
#import <Foundation/Foundation.h>
#import <SDWebImage/SDWebImage.h>
int main(int argc, char **argv) {
    (void)argv;
    @autoreleasepool {
        const unsigned char png[] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
        NSData *data = [NSData dataWithBytes:png length:sizeof(png)];
        return [NSData sd_imageFormatForImageData:data] == SDImageFormatPNG && argc > 0 ? 0 : 1;
    }
}
]], flags = {"-fobjc-arc"}, link = true,
            ldflags = {"-fobjc-arc", "-lSDWebImage", "-framework", "Foundation", "-framework", "ImageIO"}})
        assert(ok, "SDWebImage does not compile and link against armv7 iOS 6 with ARC: " .. output)
        probe.require_architecture(path.join(package:installdir("lib"), "libSDWebImage.a"), "armv7")
    end)
