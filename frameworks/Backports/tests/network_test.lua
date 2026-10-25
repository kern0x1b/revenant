local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local fixture = path.join(backports, "tests", "Network", "main.swift")
local mapping = path.join(backports, "tests", "Network", "mapping", "main.swift")
local live = path.join(backports, "tests", "Network", "live", "main.swift")

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-Onone"}, args))
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

local function backport_program(source, files, output)
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, files, {source, "-o", output}))
    return output
end

function main()
    local out = workspace.run("backports-tests", "Network")
    local host = path.join(out, "host")
    local files = os.files(path.join(src, "*.swift"))
    swiftc({fixture, "-o", host})
    local backport = backport_program(fixture, files, path.join(out, "backport"))
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host Network program printed nothing")
    if expected ~= got then
        os.execv("diff", {"-u", host .. ".out", backport .. ".out"}, {try = true})
    end
    assert(expected == got, "the backport Network differs from the host in " .. out)

    local mutant = mutant_of(files, path.join(out, "mutant"))
    local mapped = backport_program(mapping, files, path.join(out, "mapping"))
    os.execv(mapped, {}, {stdout = mapped .. ".out"})
    local broken = backport_program(mapping, mutant, path.join(out, "mapping-broken"))
    assert(os.execv(broken, {}, {try = true, stdout = broken .. ".out"}) ~= 0,
           "the mapping table passed with usesInterfaceType answering false in " .. out)

    local lived = backport_program(live, files, path.join(out, "live"))
    os.execv(lived, {}, {stdout = lived .. ".out"})
end
