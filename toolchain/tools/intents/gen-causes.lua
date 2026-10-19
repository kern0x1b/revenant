import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "..", "modules")})
local D = import("intents-data", {rootdir = os.scriptdir()}).data()

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
