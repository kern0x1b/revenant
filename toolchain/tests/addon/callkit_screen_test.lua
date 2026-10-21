import("fixtures")

local PROJECT = [[
add_repositories("revenant %s")
add_addons("revenant %s")
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
target("revenant-callkit-screen")
    add_rules("@addon/revenant/tweak")
    add_files("RevenantCallScreenTweak.m")
    add_frameworks("UIKit", "Foundation", "QuartzCore", "CoreGraphics")
    set_values("tweak.filter", "springboard.plist")
    set_values("revenant.control", "control")
]]

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local copy, version = fixtures.repository(folder)
    local root = path.directory(path.directory(path.directory(path.absolute(os.scriptdir()))))
    local tweak = path.join(root, "frameworks", "Backports", "src", "CallKit", "tweak")
    local at = path.join(folder, "probe")
    os.mkdir(at)
    os.cp(path.join(tweak, "*"), at .. "/")
    io.writefile(path.join(at, "xmake.lua"), string.format(PROJECT, copy, version))

    local refused = fixtures.refusal(function () fixtures.build(at) end)
    if refused then
        table.insert(found, "the callkit-screen tweak, out of the addon already installed and this checkout's own sources, must build: " .. refused)
    else
        local out = path.join(folder, "install")
        os.vrunv(os.programfile(), {"install", "-y", "-o", out}, {curdir = at})
        local layout = path.join(out, "Library", "MobileSubstrate", "DynamicLibraries")
        if not os.isfile(path.join(layout, "revenant-callkit-screen.dylib")) then
            table.insert(found, "the callkit-screen tweak built but its dylib is not under Library/MobileSubstrate/DynamicLibraries")
        elseif not os.isfile(path.join(layout, "revenant-callkit-screen.plist")) then
            table.insert(found, "the callkit-screen tweak built but did not carry its filter plist beside the dylib")
        end
    end
    os.tryrm(folder)
    return found
end
