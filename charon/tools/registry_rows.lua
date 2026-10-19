-- registry_rows.lua: the rows of one registry document, whatever shape that document has.
--
--   local registry_rows = import("registry_rows", {rootdir = os.scriptdir()})
--   local root = registry_rows.read(file)
--   for _, row in ipairs(registry_rows.rows(root, file)) do ... end
--
-- A registry document is one of two shapes, and a reader that knows only the first does not say so - it
-- crashes, or skips the file, and both cost the rows in it:
--
--   * {"entries": [ {...}, ... ]} - the shape of most of the files under packages/a/apple-backports/registry: 598
--     of its 619 at the time of this port, counted by a line that opens an entries array. The api is a field of
--     the row.
--   * [ {...}, ... ] - a bare list of rows (the other one).
--
-- A third shape was taught once and is now refused by name instead. It is what registry/Intents/constants.json
-- was - a "constants" object under a document that also carries "note" and "source" - and it was a generator
-- input and not a row list: it held the 83 extern constants a regeneration would otherwise drop, and nothing read
-- it. It is at tools/intents/constants.json since the coordinator's ruling of 2026-10-03. So a document carrying
-- "constants" under a registry is refused with that reason named, rather than read.
--
-- Any other shape is refused with the document's own keys named, because a shape this does not know is a file
-- whose rows would go uncounted, and an uncounted row is indistinguishable from a row that is not there.
--
-- The parse keeps what a Lua table cannot say on its own. An empty list and an empty object are both an empty
-- table, so the parse records the kind of every value, and a document that is {} is refused rather than counted
-- as zero rows. And a JSON parser keeps the last of a duplicated key, so a file that lost a brace between two
-- entries parses cleanly and silently merges them: the parse records every key an object repeats, and
-- tools/registry-shape.lua reports it.
--
-- This is the one place that knows the shapes. registry-shape.lua reads through it.

import("core.base.json")

-- The member of a document that holds rows.
local ROW_MEMBERS = {"entries"}

-- Shapes that were taught once and are refused by name, with the reason they are not taught again.
local REFUSED = {
    {member = "constants", reason = "the Intents manifest is a generator input and not a row list, and lives at "
        .. "tools/intents/constants.json since the coordinator's ruling of 2026-10-03"},
}

-- The index of the closing quote of the string whose opening quote is at `at`. A backslash skips the next
-- character, so an escaped quote is not the end.
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

-- The parse proper. json.decode has checked the text, so this may assume valid JSON and only has to say what each
-- value is. Returns the root node and every object node, in the order each object closes, which is the order
-- json.load's object hook would have seen them in.
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
                at = at + 1 -- the colon
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
        -- the keys a repeat names, in the order each first appears, as a Counter lists them
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
            -- a number, true, false or null: the parse does not need what it is, only where it ends
            at = text:find("[,%]}%s]", at) or (#text + 1)
            return {kind = "scalar"}
        end
    end

    local root = value()
    return root, objects
end

-- The parsed document and its objects, from the text of a registry file. json.decode refuses malformed text the
-- way json.load does, and raises.
function parse(text)
    json.decode(text)
    return scan(text)
end

-- As parse, from the file at `file`.
function read(file)
    return parse(io.readfile(file, {encoding = "binary"}))
end

-- The rows of one parsed document: the nodes of its row list. `file` names the document in the refusal.
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

-- The api of one row node, or false when the row has none: a false keeps the list's length, which a nil would not.
local function api_of(row)
    if row.kind == "object" and row.map.api ~= nil and row.map.api.kind == "string" then
        return row.map.api.value
    end
    return false
end

-- The api of every row, in the document's own order.
function apis(root, file)
    local out = {}
    for index, row in ipairs(rows(root, file)) do
        out[index] = api_of(row)
    end
    return out
end
