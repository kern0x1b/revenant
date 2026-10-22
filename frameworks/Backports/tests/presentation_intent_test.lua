local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local source = path.absolute(path.join(backports, "..", "..", "toolchain", "src", "swift-runtime", "overlay", "Foundation", "PresentationIntent.swift"))
local fixture = path.join(backports, "tests", "Foundation", "presentation_intent", "main.swift")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "PresentationIntent")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    swiftc({fixture, "-o", host})
    swiftc({"-module-name", "backport", source, fixture, "-o", backport})
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected = io.readfile(host .. ".out")
    local got = io.readfile(backport .. ".out"):gsub("backport%.PresentationIntent", "Foundation.PresentationIntent")
    assert(#expected > 0, "the host PresentationIntent program printed nothing")
    assert(got == expected, "the backport PresentationIntent differs from the host in " .. out)
end
