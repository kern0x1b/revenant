import("fixtures")
import("core.package.addon")

local CONTROL = "Package: org.revenant.tweaktest\nName: Tweak test\nArchitecture: iphoneos-arm\nDescription: a tweak the tests build\nDepends: mobilesubstrate\n"
local FILTER = '{ Filter = { Bundles = ( "com.apple.Preferences" ); }; }\n'

local PROJECT = [[
add_repositories("revenant %s")
add_addons("revenant %s")
set_config("apple_minimum", "6.0")
includes("@addon/revenant/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")

target("safearea")
    add_rules("@addon/revenant/tweak")
    add_files("safearea-tweak.m", "check.m")
    add_includedirs(".")
    add_frameworks("UIKit", "Foundation", "CoreGraphics")
    set_values("tweak.filter", "safearea.plist")
    set_values("revenant.control", "control")
]]

local function tweak(folder, version, device)
    local at = path.join(folder, "safearea")
    os.mkdir(at)
    os.cp(path.join(device, "safearea-tweak.m"), path.join(at, "safearea-tweak.m"))
    os.cp(path.join(device, "check.m"), path.join(at, "check.m"))
    os.cp(path.join(device, "check.h"), path.join(at, "check.h"))
    io.writefile(path.join(at, "control"), CONTROL)
    io.writefile(path.join(at, "safearea.plist"), FILTER)
    io.writefile(path.join(at, "xmake.lua"), string.format(PROJECT, folder .. "/revenant", version))
    return at
end

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local copy, version = fixtures.repository(folder)
    local device = path.join(copy, "tests", "backports", "device")

    local at = tweak(folder, version, device)
    local refused = fixtures.refusal(function () fixtures.build(at) end)
    if refused then
        table.insert(found, "a tweak built with the tweak rule, out of a source this repository already trusts on the device, must build: " .. refused)
    else
        local built = os.files(path.join(at, "build", "**", "safearea.dylib"))
        if #built == 0 then
            table.insert(found, "the tweak rule built no binary for the port")
        end

        local installdir = path.join(folder, "installed")
        local install_refused = fixtures.refusal(function () os.vrunv(os.programfile(), {"install", "-o", installdir, "-y"}, {curdir = at}) end)
        local library = path.join(installdir, "Library", "MobileSubstrate", "DynamicLibraries", "safearea.dylib")
        local filter = path.join(installdir, "Library", "MobileSubstrate", "DynamicLibraries", "safearea.plist")
        if install_refused then
            table.insert(found, "installing the built tweak must not be refused: " .. install_refused)
        elseif not os.isfile(library) then
            table.insert(found, "the tweak rule did not place the dylib under Library/MobileSubstrate/DynamicLibraries")
        elseif not os.isfile(filter) then
            table.insert(found, "the tweak rule did not carry tweak.filter beside the dylib as its own plist")
        end
    end

    addon.unregister("revenant", version)
    os.tryrm(path.join(addon.installdir(), addon.dirname("revenant"), version))
    os.tryrm(folder)
    return found
end
