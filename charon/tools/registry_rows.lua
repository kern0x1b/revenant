import("core.base.json")

local ROW_MEMBERS = {"entries"}

local REFUSED = {
    {member = "constants", reason = "the Intents manifest is a generator input and not a row list, and lives at "
        .. "tools/intents/constants.json since the coordinator's ruling of 2026-10-03"},
}

local function string_end(text, at)
    local i = at + 1
    while true do
        local found = text:find('["\\]', i)
        if text:sub(found, found) == '"' then
            return found
        end
        i = found + 2
    end
end

local function scan(text)
    local at = 1
    local objects = {}

    local function skip()
        at = text:find("[^ \t\r\n]", at) or (#text + 1)
    end

    local value

    local function object()
        local node = {kind = "object", keys = {}, map = {}, repeated = {}}
        local counts = {}
        at = at + 1
        skip()
        if text:sub(at, at) == "}" then
            at = at + 1
        else
            while true do
                skip()
                local stop = string_end(text, at)
                local key = json.decode(text:sub(at, stop))
                at = stop + 1
                skip()
                at = at + 1
                local member = value()
                counts[key] = (counts[key] or 0) + 1
                if counts[key] == 1 then
                    table.insert(node.keys, key)
                end
                node.map[key] = member
                skip()
                local separator = text:sub(at, at)
                at = at + 1
                if separator == "}" then
                    break
                end
            end
        end
        for _, key in ipairs(node.keys) do
            if counts[key] > 1 then
                table.insert(node.repeated, key)
            end
        end
        table.insert(objects, node)
        return node
    end

    local function array()
        local node = {kind = "array", items = {}}
        at = at + 1
        skip()
        if text:sub(at, at) == "]" then
            at = at + 1
            return node
        end
        while true do
            table.insert(node.items, value())
            skip()
            local separator = text:sub(at, at)
            at = at + 1
            if separator == "]" then
                return node
            end
        end
    end

    function value()
        skip()
        local c = text:sub(at, at)
        if c == "{" then
            return object()
        elseif c == "[" then
            return array()
        elseif c == '"' then
            local stop = string_end(text, at)
            local node = {kind = "string", value = json.decode(text:sub(at, stop))}
            at = stop + 1
            return node
        else
            at = text:find("[,%]}%s]", at) or (#text + 1)
            return {kind = "scalar"}
        end
    end

    local root = value()
    return root, objects
end

function parse(text)
    json.decode(text)
    return scan(text)
end

function read(file)
    return parse(io.readfile(file, {encoding = "binary"}))
end

function rows(root, file)
    if root.kind == "array" then
        return root.items
    end
    if root.kind ~= "object" then
        raise("%s: a registry document is neither an object nor a list of rows", file)
    end
    for _, refused in ipairs(REFUSED) do
        if root.map[refused.member] ~= nil then
            raise("%s: a registry document holds %s, which this reader refuses by name: %s",
                  file, refused.member, refused.reason)
        end
    end
    local held = {}
    for _, member in ipairs(ROW_MEMBERS) do
        if root.map[member] ~= nil then
            table.insert(held, member)
        end
    end
    if #held == 1 and root.map[held[1]].kind == "array" then
        return root.map[held[1]].items
    end
    raise("%s: a registry document holds %s, which is not a shape this reader knows; its keys are %s",
          file, #held > 0 and table.concat(held, " and ") or "no row member",
          #root.keys > 0 and table.concat(root.keys, ", ") or "(none)")
end

local function api_of(row)
    if row.kind == "object" and row.map.api ~= nil and row.map.api.kind == "string" then
        return row.map.api.value
    end
    return false
end

function apis(root, file)
    local out = {}
    for index, row in ipairs(rows(root, file)) do
        out[index] = api_of(row)
    end
    return out
end
