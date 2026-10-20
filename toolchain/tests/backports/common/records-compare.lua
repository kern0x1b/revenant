local json = import("core.base.json")
local byteorder = import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "..", "modules"), anonymous = true})

local SHOWN = 400

local function load(file)
    local records = json.decode(io.readfile(file, {encoding = "binary"}))
    if type(records) ~= "table" then
        raise("%s holds no JSON object of records", file)
    end
    return records
end

local function shown(value)
    if value == nil then
        return "None"
    end
    return tostring(value):sub(1, SHOWN)
end

local function words(text)
    local out = {}
    for word in (text or ""):gmatch("%S+") do
        table.insert(out, word)
    end
    return out
end

local function pinned(text)
    local out = {}
    for _, entry in ipairs(words(text)) do
        local key, value = entry:match("^([^=]*)=(.*)$")
        if not key then
            raise("%s pins no value: a pinned record is written key=value", entry)
        end
        out[key] = value
    end
    return out
end

local function shared(system, port, skipped)
    local failed = false
    for _, key in ipairs(byteorder.keys(system)) do
        if not skipped[key] and system[key] ~= port[key] then
            failed = true
            print("DIFF " .. key)
            print("  system " .. shown(system[key]))
            print("  port   " .. shown(port[key]))
        end
    end
    for _, key in ipairs(byteorder.keys(port)) do
        if system[key] == nil then
            failed = true
            print("ONLY IN THE PORT " .. key .. " " .. shown(port[key]))
        end
    end
    return failed
end

local function compare(system_file, port_file, divergent)
    local system, port = load(system_file), load(port_file)
    local skipped = {}
    for _, key in ipairs(words(divergent)) do
        skipped[key] = true
    end
    local failed = shared(system, port, skipped)
    for _, key in ipairs(words(divergent)) do
        if system[key] == port[key] then
            failed = true
            print("NO LONGER DIVERGENT " .. key .. " - " .. shown(system[key]))
        else
            print(string.format("differs on purpose: %s | system %s | port %s", key, shown(system[key]), shown(port[key])))
        end
    end
    return failed
end

local function compare_pinned(system_file, port_file, pins)
    local system, port = load(system_file), load(port_file)
    local divergent = pinned(pins)
    local failed = shared(system, port, divergent)
    for _, key in ipairs(byteorder.keys(divergent)) do
        local value = divergent[key]
        if system[key] == value then
            failed = true
            print("NO LONGER DIVERGENT " .. key .. " - " .. shown(system[key]))
        elseif port[key] ~= value then
            failed = true
            print(string.format("DIFF %s | expected %s | port %s", key, value, shown(port[key])))
        else
            print(string.format("differs on purpose: %s | system %s | port %s", key, shown(system[key]), shown(port[key])))
        end
    end
    return failed
end

local ESCAPES = {['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"}

local function quoted(text)
    return '"' .. text:gsub('[%c"\\]', function (character)
        return ESCAPES[character] or string.format("\\u%04x", character:byte())
    end) .. '"'
end

local function write(records, out)
    local lines = {}
    for _, key in ipairs(byteorder.keys(records)) do
        if type(records[key]) ~= "string" then
            raise("the record %s is not a string, and only string records are written", key)
        end
        table.insert(lines, "    " .. quoted(key) .. ": " .. quoted(records[key]))
    end
    io.writefile(out, "{\n" .. table.concat(lines, ",\n") .. "\n}", {encoding = "binary"})
end

local function expect_port(system_file, port_file, divergent, out)
    local system, port = load(system_file), load(port_file)
    for _, key in ipairs(words(divergent)) do
        if port[key] == nil then
            raise("the port recorded no %s, so the device has nothing to be held to there", key)
        end
        system[key] = port[key]
    end
    write(system, out)
end

local function expect_pinned(system_file, pins, out)
    local system = load(system_file)
    for key, value in pairs(pinned(pins)) do
        system[key] = value
    end
    write(system, out)
end

local USAGE = "usage: records-compare.lua compare <system.json> <port.json> <divergent keys> | "
              .. "compare-pinned <system.json> <port.json> <key=value ...> | "
              .. "expect-port <system.json> <port.json> <divergent keys> <out.json> | "
              .. "expect-pinned <system.json> <key=value ...> <out.json>"

function main(command, ...)
    local arguments = {...}
    if command == "compare" and #arguments == 3 then
        if compare(arguments[1], arguments[2], arguments[3]) then
            os.exit(1)
        end
    elseif command == "compare-pinned" and #arguments == 3 then
        if compare_pinned(arguments[1], arguments[2], arguments[3]) then
            os.exit(1)
        end
    elseif command == "expect-port" and #arguments == 4 then
        expect_port(arguments[1], arguments[2], arguments[3], arguments[4])
    elseif command == "expect-pinned" and #arguments == 3 then
        expect_pinned(arguments[1], arguments[2], arguments[3])
    else
        raise(USAGE)
    end
end
