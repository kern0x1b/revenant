local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local fixture = path.join(backports, "tests", "Network", "main.swift")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

local function mutant_of(files, folder)
    os.mkdir(folder)
    local written = {}
    for _, file in ipairs(files) do
        local text = io.readfile(file)
        if path.filename(file) == "NWPathMonitor.swift" then
            local replaced, count = text:gsub("usedInterfaceType == type", "false", 1)
            assert(count == 1, "the NWPath interface lookup is not where the negative control expects it")
            text = replaced
        end
        local target = path.join(folder, path.filename(file))
        io.writefile(target, text)
        table.insert(written, target)
    end
    return written
end

function main()
    local out = workspace.run("backports-tests", "Network")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local broken = path.join(out, "broken")
    local files = os.files(path.join(src, "*.swift"))
    swiftc({fixture, "-o", host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, files, {fixture, "-o", backport}))
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, mutant_of(files, path.join(out, "mutant")), {fixture, "-o", broken}))
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    os.execv(broken, {}, {stdout = broken .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Network program printed nothing")
    assert(expected == got, "the backport Network differs from the host in " .. out)
    assert(io.readfile(broken .. ".out") ~= expected, "the negative control with usesInterfaceType answering false matched the host in " .. out)
end
