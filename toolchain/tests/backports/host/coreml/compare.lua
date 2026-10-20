local json = import("core.base.json")
local pyish = import("pyish", {rootdir = path.join(os.scriptdir(), "..", "..", "common"), anonymous = true})

local HARDWARE_ORDER = {
    "devices/all count",
    "devices/all 0",
    "devices/all 1",
    "devices/all 2",
    "devices/model count",
    "devices/model 0",
    "devices/model 1",
    "devices/model 2",
    "devices/gpu listed metal device",
    "devices/ane listed core count",
}

local HARDWARE = {
    ["devices/all count"] = "the count of the compute devices this host has against the one this release has",
    ["devices/all 0"] = "the first of them, which is a neural engine here and the CPU there",
    ["devices/all 1"] = "the second of them, which only a host with a GPU or a neural engine has",
    ["devices/all 2"] = "the third of them, which only a host with a GPU or a neural engine has",
    ["devices/model count"] = "the same count, asked of MLModel",
    ["devices/model 0"] = "the same first device, asked of MLModel",
    ["devices/model 1"] = "the same second device, asked of MLModel",
    ["devices/model 2"] = "the same third device, asked of MLModel",
    ["devices/gpu listed metal device"] = "a GPU device's own Metal device, and this release has no Metal",
    ["devices/ane listed core count"] = "a neural engine's own core count, and this release has no engine",
}

local function load(file)
    if not os.isfile(file) then
        raise(string.format("no such file: %s", file), 0)
    end
    return json.loadfile(file)
end

local function text(value)
    if type(value) == "string" then
        return value
    end
    if type(value) == "boolean" then
        return value and "True" or "False"
    end
    if value == nil then
        return "None"
    end
    return tostring(value)
end

local function repr(value)
    local s = text(value)
    if type(value) ~= "string" then
        return s
    end
    if s:find("'", 1, true) and not s:find('"', 1, true) then
        return '"' .. s .. '"'
    end
    return "'" .. s:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"
end

local function cut(value, limit)
    return text(value):sub(1, limit)
end

local function same(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) == "table" then
        return json.encode(a) == json.encode(b)
    end
    return a == b
end

local function fields(value, separator)
    local out = {}
    local rest = text(value)
    while true do
        local at = rest:find(separator, 1, true)
        if not at then
            table.insert(out, rest)
            break
        end
        table.insert(out, rest:sub(1, at - 1))
        rest = rest:sub(at + #separator)
    end
    return out
end

local function number_of(piece)
    local s = pyish.strip(piece)
    local lower = s:lower()
    if lower:match("^[+-]?inf") or lower:match("^[+-]?nan$") then
        return pyish.float(s)
    end
    if (s:match("^[+-]?%d") or s:match("^[+-]?%.%d")) and not s:find("[xX]") then
        local value = tonumber(s)
        return value and value + 0.0 or nil
    end
    return nil
end

local function within(tolerance, want, got)
    local left, right = fields(want, ","), fields(got, ",")
    if #left ~= #right then
        return false
    end
    for i = 1, #left do
        local a, b = number_of(left[i]), number_of(right[i])
        if a == nil or b == nil then
            return false
        end
        if math.abs(a - b) > tolerance then
            return false
        end
    end
    return true
end

local function split_slash(key)
    local parts = {}
    for piece in (key .. "/"):gmatch("(.-)/") do
        table.insert(parts, piece)
    end
    return parts
end

local function starts(value, prefix)
    return type(value) == "string" and value:sub(1, #prefix) == prefix
end

local function ends(value, suffix)
    return type(value) == "string" and #value >= #suffix and value:sub(-#suffix) == suffix
end

local function union_sorted(a, b)
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
    return keys
end

function compare(system_path, port_path, verdict_path)
    local system, port = load(system_path), load(port_path)
    local divergent = os.getenv("COREML_DIVERGENT") or ""
    local differences, missing, one_sided = {}, {}, {}
    local stale = {}
    for _, key in ipairs(HARDWARE_ORDER) do
        if system[key] ~= nil and port[key] ~= nil and same(system[key], port[key]) then
            table.insert(stale, key)
        end
    end
    local refused = {}
    for key, value in pairs(system) do
        if starts(key, "model/") and ends(key, "/error") then
            refused[key:sub(#"model/" + 1, #key - #"/error")] = value
        end
    end
    for _, key in ipairs(union_sorted(system, port)) do
        if system[key] ~= nil and port[key] ~= nil then
            if not same(system[key], port[key]) then
                table.insert(differences, {key, system[key], port[key]})
            end
        else
            local parts = split_slash(key)
            local container = #parts > 2 and parts[2] or ""
            local side = system[key] ~= nil and "the port" or "the release"
            local value = system[key] ~= nil and system[key] or port[key]
            table.insert(one_sided, {key, container, side, value})
        end
    end
    local function is_missing(row)
        return refused[row[2]] == nil and HARDWARE[row[1]] == nil
    end
    for _, row in ipairs(one_sided) do
        if is_missing(row) then
            table.insert(missing, row)
        end
    end
    local tolerance = tonumber(os.getenv("COREML_TOLERANCE") or "1e-3")
    local informational, hard = {}, {}
    for _, row in ipairs(differences) do
        local key, want, got = row[1], row[2], row[3]
        local recorded = (starts(key, "value/") and divergent ~= "" and string.find(key, "/" .. divergent .. "/", 1, true) ~= nil)
            or starts(text(want), "raised ")
        if HARDWARE[key] ~= nil then
            table.insert(informational, row)
        elseif recorded then
            table.insert(informational, row)
        elseif starts(key, "value/") and within(tolerance, want, got) then
        else
            table.insert(hard, row)
        end
    end
    for _, row in ipairs(hard) do
        print("DIFF " .. row[1])
        print("  system " .. cut(row[2], 300))
        print("  port   " .. cut(row[3], 300))
    end
    for _, row in ipairs(missing) do
        print("MISSING " .. row[1] .. " - no answer on the side of " .. row[3])
        print("  the side that has it " .. cut(row[4], 200))
    end
    for _, row in ipairs(one_sided) do
        if refused[row[2]] ~= nil then
            print("one side only: " .. row[1] .. " - no answer on " .. row[3] .. " ; the release refused " .. row[2]
                .. " with " .. repr(refused[row[2]]):sub(1, 120) .. " and answered nothing else for it")
        end
    end
    for _, row in ipairs(informational) do
        if HARDWARE[row[1]] ~= nil then
            print("hardware (this release has none of it): " .. row[1] .. " - " .. HARDWARE[row[1]])
        else
            print("divergent (recorded): " .. row[1])
        end
        print("  system " .. cut(row[2], 200))
        print("  port   " .. cut(row[3], 200))
    end
    for _, row in ipairs(one_sided) do
        if HARDWARE[row[1]] ~= nil and row[3] == "the release" then
            print("hardware (this release has none of it): " .. row[1] .. " - " .. HARDWARE[row[1]]
                .. " - and no answer on the port's side either")
        end
    end
    for _, key in ipairs(stale) do
        print("STALE ALLOWANCE " .. key .. " - both sides now answer " .. repr(system[key]):sub(1, 120)
            .. " so the difference this release's hardware causes is gone and the allowance must go with it")
    end
    local unanswered = #one_sided - #missing
    print(string.format("compared %d keys, %d differ, %d missing, %d recorded divergences, %d for a container the release refused",
        #union_sorted(system, port), #hard, #missing, #informational, unanswered))
    io.writefile(verdict_path, (#hard > 0 or #missing > 0 or #stale > 0) and "differs\n" or "same\n")
    return 0
end

function main(system_path, port_path, verdict_path)
    os.exit(compare(system_path, port_path, verdict_path))
end
