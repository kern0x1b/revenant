local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local foundation = path.join(backports, "src", "Foundation")
local fixture = path.join(backports, "tests", "NaturalLanguage", "main.m")

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-fobjc-arc", "-target", "arm64-apple-macos13", "-isysroot", os.iorunv("xcrun", {"--sdk", "macosx", "--show-sdk-path"}):trim()}, args))
end

function main()
    local out = workspace.run("backports-tests", "NaturalLanguage")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    clang({"-o", host, fixture, "-framework", "Foundation", "-framework", "NaturalLanguage"})
    local sources = {"NLLanguage.m", "NLLanguageRecognizer.m", "NLTokenizer.m", "NLConstants12.m", "NLConstants13.m", "NLConstants16.m", "NLConstants17.m"}
    local files = {fixture}
    for _, name in ipairs(sources) do
        table.insert(files, path.join(foundation, name))
    end
    clang(table.join({"-o", backport}, files, {"-framework", "Foundation"}))
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host NaturalLanguage program printed nothing")
    assert(expected == got, "the backport NaturalLanguage differs from the host in " .. out)
end
