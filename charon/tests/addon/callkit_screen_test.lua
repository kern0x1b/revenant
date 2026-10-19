import("fixtures")

-- Proves the CallKit call screen's SpringBoard side (packages/a/apple-callkit-screen) builds and packages for real,
-- the way a port building it would: against the charon addon already installed on this machine and this checkout's own
-- package repository, read directly off disk rather than cloned. tweak_test already proves the tweak rule itself works
-- from a fresh, isolated addon install; that dance is also where tests/addon's own pre-existing flakiness lives
-- (documented in fixtures.repository's callers), so a package that only needs to be built, not the rule's own install
-- path re-proven, does not pay for it again here.

local PROJECT = [[
add_repositories("charon %s")
add_addons("charon")
set_config("apple_minimum", "6.0")
includes("@addon/charon/apple-ios")
set_allowedplats("iphoneos")
set_allowedarchs("iphoneos|armv7")
set_defaultplat("iphoneos")
set_defaultarchs("iphoneos|armv7")
add_requires("charon@apple-callkit-screen", {alias = "callkit-screen"})
target("probe")
    set_kind("phony")
    add_packages("callkit-screen")
]]

function failures(opt)
    local found = {}
    local folder = fixtures.scratch()
    local root = path.absolute(path.join(os.scriptdir(), "..", ".."))
    local at = path.join(folder, "probe")
    os.mkdir(at)
    io.writefile(path.join(at, "xmake.lua"), string.format(PROJECT, root))

    local refused = fixtures.refusal(function () fixtures.build(at) end)
    if refused then
        table.insert(found, "the callkit-screen tweak, out of the addon already installed and this checkout's own package repository, must build: " .. refused)
    else
        local dylib = os.files(path.join(os.getenv("HOME"), ".xmake", "packages", "a", "apple-callkit-screen", "**",
                                          "Library", "MobileSubstrate", "DynamicLibraries", "charon-callkit-screen.dylib"))
        local filter = os.files(path.join(os.getenv("HOME"), ".xmake", "packages", "a", "apple-callkit-screen", "**",
                                           "Library", "MobileSubstrate", "DynamicLibraries", "charon-callkit-screen.plist"))
        if #dylib == 0 then
            table.insert(found, "the callkit-screen tweak built but its dylib is not under Library/MobileSubstrate/DynamicLibraries")
        elseif #filter == 0 then
            table.insert(found, "the callkit-screen tweak built but did not carry its filter plist beside the dylib")
        end
    end
    os.tryrm(folder)
    return found
end
