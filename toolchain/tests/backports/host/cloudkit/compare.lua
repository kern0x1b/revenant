local json = import("core.base.json")
local modules = path.join(os.scriptdir(), "..", "..", "..", "..", "modules")
local byteorder = import("byteorder", {rootdir = modules, anonymous = true})
local runtime = import("gyb.runtime", {rootdir = modules, anonymous = true})

local SKIPPED = {
    ["archive.CKRecord.bytes"] = "archive size: a port's own keys cannot match Apple's binary archive",
    ["archive.CKRecordID.bytes"] = "archive size",
    ["archive.CKRecordZone.bytes"] = "archive size",
    ["archive.CKRecordZoneID.bytes"] = "archive size",
    ["archive.CKReference.bytes"] = "archive size",
    ["conditions"] = "the runner's own statement of its conditions, not an answer",
    ["assertion"] = "the host runner's statement that its cases named no network operation",
}

local PRIVATE = {
    {"_NSInlineData", "NSData"},
    {"__NSCFData", "NSData"},
    {"__NSCFString", "NSString"},
    {"__NSCFConstantString", "NSString"},
    {"__NSCFNumber", "NSNumber"},
    {"__NSCFBoolean", "NSNumber"},
    {"__NSTaggedPointerString", "NSString"},
    {"__NSTaggedPointerNumber", "NSNumber"},
}

local HEX = "[0-9A-F]"
local UUID = "^" .. HEX:rep(8) .. "%-" .. HEX:rep(4) .. "%-" .. HEX:rep(4) .. "%-" .. HEX:rep(4) .. "%-" .. HEX:rep(12) .. "$"

local function word_at(text, at)
    return at >= 1 and at <= #text and text:sub(at, at):match("[%w_]") ~= nil
end

local function replace_all(text, old, new)
    local pieces, at = {}, 1
    while true do
        local first, last = text:find(old, at, true)
        if not first then
            table.insert(pieces, text:sub(at))
            return table.concat(pieces)
        end
        table.insert(pieces, text:sub(at, first - 1))
        table.insert(pieces, new)
        at = last + 1
    end
end

local function replace_uuids(text)
    local out, at = {}, 1
    while at <= #text do
        if at + 35 <= #text and text:sub(at, at + 35):match(UUID) and not word_at(text, at - 1) and not word_at(text, at + 36) then
            table.insert(out, "<UUID>")
            at = at + 36
        else
            table.insert(out, text:sub(at, at))
            at = at + 1
        end
    end
    return table.concat(out)
end

local function normalise(value)
    if type(value) == "string" then
        value = value:gsub("0x[0-9a-f]+", "0xADDR")
        value = replace_uuids(value)
        for _, pair in ipairs(PRIVATE) do
            value = replace_all(value, pair[1], pair[2])
        end
        return value
    elseif type(value) == "table" then
        local out = {}
        for key, item in pairs(value) do
            out[key] = normalise(item)
        end
        return out
    end
    return value
end

local function same(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, item in pairs(a) do
        if not same(item, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local function count(map)
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

local function shown(value)
    if type(value) == "string" then
        return value
    end
    return runtime.to_repr(value)
end

local function load(file)
    return json.decode(io.readfile(file, {encoding = "binary"}))
end

function main(host_path, port_path)
    local host, port = load(host_path), load(port_path)
    local only_host, only_port, different = {}, {}, {}
    for _, key in ipairs(byteorder.keys(host)) do
        if port[key] == nil and SKIPPED[key] == nil then
            table.insert(only_host, key)
        end
    end
    for _, key in ipairs(byteorder.keys(port)) do
        if host[key] == nil then
            table.insert(only_port, key)
        end
    end
    local shared, skipped = 0, 0
    for _, key in ipairs(byteorder.keys(host)) do
        if port[key] ~= nil then
            shared = shared + 1
            if SKIPPED[key] ~= nil then
                skipped = skipped + 1
            else
                local want, got = normalise(host[key]), normalise(port[key])
                if not same(want, got) then
                    table.insert(different, {key, want, got})
                end
            end
        end
    end

    print(string.format("host answers: %d   port answers: %d", count(host), count(port)))
    for _, key in ipairs(only_host) do
        print(string.format("only the host answered %s = %s", key, shown(host[key])))
    end
    for _, key in ipairs(only_port) do
        print(string.format("only the port answered %s = %s", key, shown(port[key])))
    end
    if #different > 0 then
        print(string.format("\n%d differ:", #different))
        for _, item in ipairs(different) do
            print(string.format("  %s\n      host: %s\n      port: %s", item[1], shown(item[2]), shown(item[3])))
        end
    else
        print(string.format("all %d compared answers agree (%d skipped)", shared - skipped, skipped))
    end
    for _, key in ipairs(byteorder.keys(SKIPPED)) do
        if host[key] ~= nil then
            print(string.format("skipped %-32s %s", key, SKIPPED[key]))
        end
    end
    if #only_host > 0 or #only_port > 0 or #different > 0 then
        os.exit(1)
    end
end
