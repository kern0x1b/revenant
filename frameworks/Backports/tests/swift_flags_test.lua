local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local swift = path.join(backports, "src", "Swift")
local src = path.join(backports, "src")
local cmodules = {"RevenantTLS", "RevenantNetworkC"}

function main()
    local out = workspace.fresh("swift-flags")
    local nested = path.join(out, "nested")
    os.mkdir(nested)
    local values = path.join(out, "values.txt")
    io.writefile(path.join(nested, "xmake.lua"), table.concat({
        'set_project("swift-flags-fixture")',
        'target("overlay")',
        '    set_kind("phony")',
        '    on_config(function (target)',
        '        import("cmodule_flags", {rootdir = "' .. swift .. '", anonymous = true}).apply(target, "' .. src .. '", "Network", {"' .. table.concat(cmodules, '", "') .. '"})',
        '        io.writefile("' .. values .. '", table.concat(target:values("swift.flags"), "\\n"))',
        '    end)',
        'target_end()',
        ''}, "\n"))

    local log = path.join(out, "configure.log")
    local status = os.execv(os.programfile(), {"f", "-P", nested, "-y"}, {try = true, stdout = log, stderr = log, curdir = nested})
    if status ~= 0 then
        raise("the fixture project did not configure (%s): %s", tostring(status), io.readfile(log))
    end

    local flags = {}
    for line in io.readfile(values):gmatch("[^\n]+") do
        table.insert(flags, line)
    end
    for _, cmodule in ipairs(cmodules) do
        local want = "-I" .. path.join(src, "Network", cmodule)
        local found = false
        for _, flag in ipairs(flags) do
            found = found or flag == want
        end
        assert(found, string.format("swift.flags after xmake must carry %s as one value; got: %s", want, table.concat(flags, " ")))
    end

    local probe = path.join(out, "probe.swift")
    io.writefile(probe, "import RevenantTLS\nimport RevenantNetworkC\n")
    os.vrunv("xcrun", table.join({"swiftc", "-typecheck"}, flags, {probe}))
    print("swift_flags: %d cmodule directories each carry one -I value, and swiftc imports them", #cmodules)
end
