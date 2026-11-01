if not is_plat("iphoneos") or (get_config("component") ~= "" and get_config("component") ~= "packages") then
    return
end

local here = os.scriptdir()

add_requires("revenant@sdwebimage 5.21.7", {alias = "sdwebimage"})
add_requires("revenant@libwebp 1.6.0", {alias = "libwebp"})
add_requires("revenant@sdwebimage-webp 0.14.6", {alias = "sdwebimage-webp"})
add_requires("revenant@zxingobjc 3.6.4", {alias = "zxingobjc"})

local SUITES = {
    {name = "sdwebimage", source = "sdwebimage.m", packages = {"sdwebimage"}, mflags = {"-fobjc-arc"},
     frameworks = {"Foundation", "ImageIO"}},
    {name = "sdwebimage_webp", source = "sdwebimage_webp.m", packages = {"sdwebimage-webp", "sdwebimage", "libwebp"}, mflags = {"-fobjc-arc"},
     frameworks = {"Foundation", "UIKit", "ImageIO", "CoreGraphics", "QuartzCore", "CoreImage", "Accelerate", "CoreServices", "MobileCoreServices", "CoreVideo"}},
    {name = "libwebp", source = "libwebp.c", packages = {"libwebp"}, cflags = {}},
    {name = "zxingobjc", source = "zxingobjc.m", packages = {"zxingobjc"}, mflags = {"-fobjc-arc"},
     defines = {"ZXINGOBJC_USE_SUBSPECS", "ZXINGOBJC_ONED", "ZXINGOBJC_PDF417"},
     frameworks = {"Foundation", "AVFoundation", "CoreGraphics", "CoreMedia", "CoreVideo", "ImageIO", "QuartzCore"}},
}

local names = {}
for _, suite in ipairs(SUITES) do
    table.insert(names, suite.name)
    target(suite.name)
        add_rules("@addon/revenant/apple-ios")
        set_kind("binary")
        set_default(false)
        add_files(path.join(here, suite.source))
        add_packages(table.unpack(suite.packages))
        add_defines(table.unpack(suite.defines or {}))
        add_mflags(table.unpack(suite.mflags or {}))
        add_frameworks(table.unpack(suite.frameworks or {}))
    target_end()
end

target("packages")
    set_kind("phony")
    set_default(false)
    add_deps(table.unpack(names))
    for _, name in ipairs(names) do
        add_tests(name)
    end
    on_test(function (target, opt)
        local name = path.filename(opt.name)
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local built = import("core.project.project").target(name):targetfile()
        if not os.isfile(built) then
            opt.errors = name .. " did not build against armv7 iOS 6"
            return false
        end
        probe.require_architecture(built, "armv7")
        return true
    end)
target_end()
