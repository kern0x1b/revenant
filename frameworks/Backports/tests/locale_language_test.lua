local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local source = path.absolute(path.join(backports, "..", "..", "toolchain", "src", "swift-runtime", "overlay", "Foundation", "LocaleLanguage.swift"))
local fixture = path.join(backports, "tests", "Foundation", "locale_language", "main.swift")

local NAMES = {
    {"Language", "RevLanguage"},
    {"LanguageCode", "RevLanguageCode"},
    {"Script", "RevScript"},
    {"Region", "RevRegion"},
    {"MeasurementSystem", "RevMeasurementSystem"},
    {"language", "revLanguage"},
    {"region", "revRegion"},
    {"measurementSystem", "revMeasurementSystem"},
}

local function renamed(text)
    local literals = {}
    local masked = text:gsub('"[^"\n]*"', function (literal)
        table.insert(literals, literal)
        return "\1" .. #literals .. "\2"
    end)
    masked = masked:gsub("NSLocale%.Key%.measurementSystem", "\3")
    for _, pair in ipairs(NAMES) do
        masked = masked:gsub("%f[%w_]" .. pair[1] .. "%f[^%w_]", pair[2])
    end
    masked = masked:gsub("\3", "NSLocale.Key.measurementSystem")
    return (masked:gsub("\1(%d+)\2", function (index) return literals[tonumber(index)] end))
end

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "LocaleLanguage")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local overlay = path.join(out, "RevLocaleLanguage.swift")
    local backport_dir = path.join(out, "backport-src")
    os.mkdir(backport_dir)
    local backport_fixture = path.join(backport_dir, "main.swift")
    io.writefile(overlay, renamed(io.readfile(source)))
    io.writefile(backport_fixture, renamed(io.readfile(fixture)))
    swiftc({fixture, "-o", host})
    swiftc({"-module-name", "backport", overlay, backport_fixture, "-o", backport})
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected = io.readfile(host .. ".out")
    local got = io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Locale.Language program printed nothing")
    assert(got == expected, "the backport Locale.Language differs from the host in " .. out)
end
