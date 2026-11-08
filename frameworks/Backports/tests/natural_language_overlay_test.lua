local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local source = path.join(backports, "src", "NaturalLanguage", "NaturalLanguage.swift")
local fixture = path.join(backports, "tests", "NaturalLanguage", "host", "main.swift")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "NaturalLanguageOverlay")
    local modules = path.join(out, "modules")
    os.mkdir(modules)
    local host = path.join(out, "host")
    local overlaid = path.join(out, "overlaid")
    swiftc({fixture, "-o", host})
    swiftc({"-module-name", "NaturalLanguage", "-Xfrontend", "-import-underlying-module", "-parse-as-library", "-emit-module",
            "-emit-module-path", path.join(modules, "NaturalLanguage.swiftmodule"), "-emit-library",
            "-o", path.join(modules, "libNaturalLanguageOverlay.dylib"), "-framework", "NaturalLanguage", source})
    swiftc({"-I", modules, "-L", modules, "-lNaturalLanguageOverlay", "-Xlinker", "-rpath", "-Xlinker", modules, fixture, "-o", overlaid})
    assert(os.iorunv("otool", {"-L", overlaid}):find("libNaturalLanguageOverlay.dylib", 1, true), "the program does not link the overlay, so the test measures the SDK's own overlay")
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(overlaid, {}, {stdout = overlaid .. ".out"})
    local expected = io.readfile(host .. ".out")
    local got = io.readfile(overlaid .. ".out")
    assert(#expected > 0, "the program built against the SDK's NaturalLanguage overlay printed nothing")
    assert(got == expected, "the NaturalLanguage overlay differs from the SDK's in " .. out)
end
