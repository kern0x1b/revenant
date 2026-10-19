local lib = import("vtlib", {rootdir = os.scriptdir(), anonymous = true})
local json = import("core.base.json")

local function load_record(path)
    return json.decode(lib.read_text(path))
end

function main(systemPath, portPath)
    if not systemPath or not portPath then
        raise("compare.lua: pass SYSTEM.json PORT.json")
    end
    local system = load_record(systemPath)
    local port = load_record(portPath)
    local names = {}
    for name in pairs(system) do
        names[#names + 1] = name
    end
    lib.sort_bytes(names)
    local bad = {}
    for _, name in ipairs(names) do
        local host = system[name]
        local got = port[name]
        if got ~= host then
            bad[#bad + 1] = string.format("%s: the host has [%s] and the port has [%s]",
                name, lib.py_value(host), lib.py_value(got))
        end
    end
    if #bad > 0 then
        for i = 1, math.min(20, #bad) do
            print("DIFFERS " .. bad[i])
        end
        if #bad > 20 then
            io.write(string.format("DIFFERS ... and %d more", #bad - 20))
        end
        os.exit(1)
    end
    print(string.format("compared %d constants: every one is the host's value", lib.count_keys(system)))
end
