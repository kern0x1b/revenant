local function file_lines(text)
    local out, at = {}, 1
    while at <= #text do
        local stop = text:find("\n", at, true)
        if stop then
            table.insert(out, text:sub(at, stop - 1))
            at = stop + 1
        else
            table.insert(out, text:sub(at))
            break
        end
    end
    return out
end

local function split_spaces(text)
    local out, at = {}, 1
    while true do
        local stop = text:find(" ", at, true)
        if not stop then
            table.insert(out, text:sub(at))
            return out
        end
        table.insert(out, text:sub(at, stop - 1))
        at = stop + 1
    end
end

local function float_text(text)
    local value = tonumber(text)
    if value == nil then
        raise(string.format("speeds.lua: rate %q is not a number", text))
    end
    local out
    for digits = 1, 17 do
        out = string.format("%." .. digits .. "g", value)
        if tonumber(out) == value then
            break
        end
    end
    if not out:find("[%.eEn]") then
        out = out .. ".0"
    end
    return out
end

local short_escapes = {['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f"}

local function json_text(value)
    if value == nil then
        return "null"
    end
    local out = {'"'}
    for _, code in utf8.codes(value) do
        local char = utf8.char(code)
        if short_escapes[char] then
            table.insert(out, short_escapes[char])
        elseif code < 0x20 or code > 0x7F then
            if code > 0xFFFF then
                local rest = code - 0x10000
                table.insert(out, string.format("\\u%04x\\u%04x", 0xD800 + (rest >> 10), 0xDC00 + (rest & 0x3FF)))
            else
                table.insert(out, string.format("\\u%04x", code))
            end
        else
            table.insert(out, char)
        end
    end
    table.insert(out, '"')
    return table.concat(out)
end

local function show(value)
    if value == nil then
        return "None"
    end
    return value
end

function main(log, out)
    if log == nil or out == nil then
        raise("usage: speeds.lua LOG OUT")
    end
    local speeds, other = {}, {}
    for _, line in ipairs(file_lines(io.readfile(log, {encoding = "binary"}))) do
        if line:startswith("speed: ") then
            local fields = {}
            for _, pair in ipairs(split_spaces(line:sub(8))) do
                local key, value = pair:match("^(.-)=(.*)$")
                if key == nil then
                    raise(string.format("speeds.lua: %q is not key=value", pair))
                end
                fields[key] = value
            end
            if fields.rate == nil or fields.name == nil or fields.numeric == nil then
                raise(string.format("speeds.lua: speed line lacks a field: %s", line))
            end
            table.insert(speeds, {rate = float_text(fields.rate), name = fields.name, numeric = fields.numeric})
        elseif line:find(": ", 1, true) then
            local key, value = line:match("^(.-): (.*)$")
            other[key] = value
        end
    end
    local count = 0
    if other.count ~= nil then
        count = tonumber(other.count)
        if count == nil then
            raise(string.format("speeds.lua: count %q is not an integer", other.count))
        end
    end
    local body = {}
    table.insert(body, "{")
    table.insert(body, string.format('  "count": %d,', count))
    table.insert(body, string.format('  "locale": %s,', json_text(other.locale)))
    if #speeds == 0 then
        table.insert(body, '  "speeds": []')
    else
        table.insert(body, '  "speeds": [')
        for index, speed in ipairs(speeds) do
            table.insert(body, "    {")
            table.insert(body, string.format('      "name": %s,', json_text(speed.name)))
            table.insert(body, string.format('      "numeric": %s,', json_text(speed.numeric)))
            table.insert(body, string.format('      "rate": %s', speed.rate))
            table.insert(body, index < #speeds and "    }," or "    }")
        end
        table.insert(body, "  ]")
    end
    table.insert(body, "}")
    io.writefile(out, table.concat(body, "\n"), {encoding = "binary"})
    print(string.format("records: %d speeds, locale %s", #speeds, show(other.locale)))
end
