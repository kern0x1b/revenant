local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local src = path.join(backports, "src", "Network")
local programs = path.join(backports, "tests", "Network")
local SOURCES = {"NWPathMonitor.swift", "NWInterface.swift", "NWEndpoint.swift", "IPv4Address.swift", "IPv6Address.swift"}

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-Onone"}, args))
end

local function backport_files()
    local found = {}
    for _, name in ipairs(SOURCES) do
        table.insert(found, path.join(src, name))
    end
    return found
end

local function output(binary)
    local log = binary .. ".out"
    os.execv(binary, {}, {stdout = log})
    return io.readfile(log)
end

local function comparable_paths(text)
    local kept = {}
    for line in text:gmatch("[^\n]+") do
        if line == "prohibited wifi" then
            break
        end
        if not line:find("interfaces", 1, true) then
            table.insert(kept, line)
        end
    end
    return table.concat(kept, "\n")
end

local function same(name, expected, got)
    assert(expected == got, string.format("the backport %s differs from the host:\n--- host\n%s\n--- backport\n%s", name, expected, got))
end

function main()
    local out = workspace.run("backports-tests", "NetworkPath")
    local paths = path.join(programs, "paths", "main.swift")
    local host = path.join(out, "paths-host")
    local backport = path.join(out, "paths-backport")
    swiftc({paths, "-o", host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, backport_files(), {paths, "-o", backport}))
    same("path monitor", comparable_paths(output(host)), comparable_paths(output(backport)))

    local async = path.join(programs, "asyncpath", "main.swift")
    local async_host = path.join(out, "async-host")
    local async_backport = path.join(out, "async-backport")
    swiftc({async, "-o", async_host})
    swiftc(table.join({"-D", "REVENANT_BACKPORT"}, backport_files(), {async, "-o", async_backport}))
    same("async path sequence", output(async_host), output(async_backport))
end
