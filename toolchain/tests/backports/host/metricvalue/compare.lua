import("core.base.json")

local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

local function load(file)
    local handle = assert(io.open(file, "rb"))
    local records = json.decode(handle:read("a"))
    handle:close()
    return records
end

local function repr(value)
    if value == nil then
        return "None"
    end
    return "'" .. tostring(value) .. "'"
end

local function starts(text, prefix)
    return text:sub(1, #prefix) == prefix
end

local function ends(text, suffix)
    return suffix == "" or text:sub(-#suffix) == suffix
end

local function named(records, prefix, test)
    local out = {}
    for name in pairs(records) do
        if starts(name, prefix) and (test == nil or test(name)) then
            out[#out + 1] = name
        end
    end
    table.sort(out, byte_less)
    return out
end

function main(systemFile, portFile)
    if not systemFile or not portFile then
        raise("compare.lua: pass the host's records and the port's")
    end
    local system, port = load(systemFile), load(portFile)
    local bad = {}

    for _, name in ipairs({ "empty.keyCount", "empty.jsonIsObject" }) do
        if system[name] ~= port[name] then
            bad[#bad + 1] = string.format("%s: the host's MetricKit wrote %s, the port wrote %s", name, repr(system[name]), repr(port[name]))
        end
    end

    local expect = {
        { "filled.keyCount", "1" },
        { "filled.hasCumulativeCPUTime", "1" },
        { "filled.unsetIsAbsent", "0" },
        { "filled.jsonKeyCount", "1" },
        { "date.endAbsent", "0" },
        { "archive.sameRepresentation", "1" },
    }
    for _, pair in ipairs(expect) do
        local name, wanted = pair[1], pair[2]
        if port[name] ~= wanted then
            bad[#bad + 1] = string.format("%s: expected %s, the port wrote %s", name, repr(wanted), repr(port[name]))
        end
    end
    for _, name in ipairs({ "filled.cumulativeCPUTime", "filled.jsonValue", "date.value", "archive.cumulativeCPUTime" }) do
        if port[name] == nil or port[name] == "" or port[name] == "(none)" then
            bad[#bad + 1] = name .. ": nothing was recorded"
        end
    end
    if port["filled.cumulativeCPUTime"] ~= port["filled.jsonValue"] then
        bad[#bad + 1] = string.format("the dictionary wrote %s and the JSON %s for the same property",
            repr(port["filled.cumulativeCPUTime"]), repr(port["filled.jsonValue"]))
    end
    if port["filled.cumulativeCPUTime"] ~= port["archive.cumulativeCPUTime"] then
        bad[#bad + 1] = string.format("the archived value came back as %s, not %s",
            repr(port["archive.cumulativeCPUTime"]), repr(port["filled.cumulativeCPUTime"]))
    end

    for _, name in ipairs(named(port, "kvc.", function(n) return ends(n, ".answers") or ends(n, ".read") end)) do
        if port[name] ~= "1" then
            bad[#bad + 1] = name .. ": no accessor answers that name on the port's own class"
        end
    end
    for _, name in ipairs(named(port, "kvc.", function(n) return ends(n, ".class") end)) do
        if port[name] ~= "1" then
            bad[#bad + 1] = name .. ": the port's own class is not in the build"
        end
    end

    if #bad > 0 then
        for _, line in ipairs(bad) do
            print("DIFFERS " .. line)
        end
        os.exit(1)
    end
    local count = 0
    for _ in pairs(port) do
        count = count + 1
    end
    print(string.format("compared %d records: the host's empty answer, and the port's own contract", count))
end
