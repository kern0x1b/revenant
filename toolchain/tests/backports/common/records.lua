local json = import("core.base.json")
local pyish = import("pyish", {rootdir = os.scriptdir(), anonymous = true})

local function load(file)
    if not os.isfile(file) then
        raise(string.format("no such file: %s", file), 0)
    end
    return json.loadfile(file)
end

local function same(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) == "table" then
        for k, v in pairs(a) do
            if not same(v, b[k]) then
                return false
            end
        end
        for k in pairs(b) do
            if a[k] == nil then
                return false
            end
        end
        return true
    end
    return a == b
end

local function shown(value, limit)
    local text
    if value == nil then
        text = "None"
    elseif type(value) == "string" then
        text = value
    else
        text = json.encode(value)
    end
    if limit and limit > 0 then
        text = text:sub(1, limit)
    end
    return text
end

local function report(a, b, keys, limit)
    local count = 0
    local cut = tonumber(limit or 0)
    for _, key in ipairs(keys) do
        if not same(a[key], b[key]) then
            count = count + 1
            print("DIFF " .. key)
            print("  system " .. shown(a[key], cut))
            print("  port   " .. shown(b[key], cut))
        end
    end
    return count
end

function diff(system_path, port_path, limit)
    local a, b = load(system_path), load(port_path)
    return report(a, b, pyish.sorted_keys(a), limit)
end

function union(system_path, port_path, limit)
    local a, b = load(system_path), load(port_path)
    local seen, keys = {}, {}
    for _, source in ipairs({a, b}) do
        for key in pairs(source) do
            if not seen[key] then
                seen[key] = true
                table.insert(keys, key)
            end
        end
    end
    table.sort(keys)
    return report(a, b, keys, limit)
end

function suffixes(system_path, prefix)
    local records = load(system_path)
    local out = {}
    for _, key in ipairs(pyish.sorted_keys(records)) do
        if key:sub(1, #prefix) == prefix then
            table.insert(out, key:sub(#prefix + 1))
        end
    end
    print(table.concat(out, " "))
    return 0
end

function value(system_path, key)
    local records = load(system_path)
    local found = records[key]
    if found == nil then
        print("")
    else
        print(shown(found, 0))
    end
    return 0
end

function without(system_path, out_path, prefix)
    local records = load(system_path)
    local parts = {}
    for _, key in ipairs(pyish.sorted_keys(records)) do
        if key:sub(1, #prefix) ~= prefix then
            table.insert(parts, json.encode(key) .. ": " .. json.encode(records[key]))
        end
    end
    io.writefile(out_path, "{" .. table.concat(parts, ", ") .. "}")
    return 0
end

function main(command, ...)
    if command == "diff" or command == "union" then
        local count = command == "diff" and diff(...) or union(...)
        os.exit(count > 0 and 1 or 0)
    elseif command == "without" then
        os.exit(without(...))
    elseif command == "suffixes" then
        os.exit(suffixes(...))
    elseif command == "value" then
        os.exit(value(...))
    end
    io.stderr:write("usage: records.lua diff|union <system.json> <port.json> [limit] | without <system.json> <out.json> <prefix> | suffixes <json> <prefix> | value <json> <key>\n")
    os.exit(2)
end
