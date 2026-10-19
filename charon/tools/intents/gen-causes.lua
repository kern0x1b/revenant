-- gen-causes.lua --out FILE: write the generator's vocabulary of why a member is not answered, as JSON.
--
-- gen-registry writes an absent entry's reason from this, so the reason names the **cause** - a class of a later group,
-- a value this delivery does not carry, a chain the SDK forbids, a factory that answers an array, a class the headers
-- only forward declare - and not the owner class's group.
--
-- Usage:
--     xmake l tools/intents/gen-causes.lua --out FILE

import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local D = import("intents-data", {rootdir = os.scriptdir()}).data()

-- json.dump(indent=1, sort_keys=True) of a flat string-to-string map: one key per line, one space an indent.
local function json_string(text)
    if text:find('[%c\128-\255]') then
        raise("a cause sentence has a character json.dump would escape, which this writer does not implement: %s", text)
    end
    return '"' .. text:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

function main(...)
    local arguments = {...}
    local out = nil
    if arguments[1] == "--out" and arguments[2] ~= nil and #arguments == 2 then
        out = arguments[2]
    else
        raise("usage: xmake l tools/intents/gen-causes.lua --out FILE")
    end

    local keys = {}
    for key in pairs(D.causes) do
        table.insert(keys, key)
    end
    byteorder.sort(keys)

    local lines = {}
    for _, key in ipairs(keys) do
        table.insert(lines, ' ' .. json_string(key) .. ': ' .. json_string(D.causes[key]))
    end
    local text
    if #lines == 0 then
        text = "{}\n"
    else
        text = "{\n" .. table.concat(lines, ",\n") .. "\n}\n"
    end
    io.writefile(out, text, {encoding = "binary"})
    print(string.format("%s: %d causes", out, #keys))
    return 0
end
