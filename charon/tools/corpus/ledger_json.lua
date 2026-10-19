import("core.base.json")

local OBJECT, ARRAY = {}, {}

function null()
    return json.null
end

function object(pairs_list)
    return {[OBJECT] = pairs_list or {}}
end

function array(list)
    return {[ARRAY] = list or {}}
end

function is_null(value)
    return value == nil or value == json.null
end

local NAMED = {['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f"}

local function code_points(text)
    local out, at, size = {}, 1, #text
    while at <= size do
        local byte = text:byte(at)
        local need, value
        if byte < 0x80 then
            need, value = 0, byte
        elseif byte >= 0xc2 and byte <= 0xdf then
            need, value = 1, byte & 0x1f
        elseif byte >= 0xe0 and byte <= 0xef then
            need, value = 2, byte & 0x0f
        elseif byte >= 0xf0 and byte <= 0xf4 then
            need, value = 3, byte & 0x07
        end
        local good = need ~= nil and at + need <= size
        if good then
            for index = 1, need do
                local next_byte = text:byte(at + index)
                if next_byte < 0x80 or next_byte > 0xbf then
                    good = false
                    break
                end
                value = (value << 6) | (next_byte & 0x3f)
            end
        end
        if good and ((need == 2 and (value < 0x800 or (value >= 0xd800 and value <= 0xdfff)))
                or (need == 3 and (value < 0x10000 or value > 0x10ffff))) then
            good = false
        end
        if good then
            table.insert(out, value)
            at = at + need + 1
        else
            table.insert(out, 0xfffd)
            at = at + 1
        end
    end
    return out
end

function string_text(text)
    local parts = {'"'}
    for _, point in ipairs(code_points(text)) do
        if point >= 0x20 and point <= 0x7e then
            local char = string.char(point)
            table.insert(parts, NAMED[char] or char)
        elseif point < 0x80 and NAMED[string.char(point)] then
            table.insert(parts, NAMED[string.char(point)])
        elseif point < 0x10000 then
            table.insert(parts, string.format("\\u%04x", point))
        else
            local shifted = point - 0x10000
            table.insert(parts, string.format("\\u%04x\\u%04x", 0xd800 | (shifted >> 10), 0xdc00 | (shifted & 0x3ff)))
        end
    end
    table.insert(parts, '"')
    return table.concat(parts)
end

local function encode_into(value, out)
    if value == nil or value == json.null then
        table.insert(out, "null")
    elseif value == true then
        table.insert(out, "true")
    elseif value == false then
        table.insert(out, "false")
    elseif type(value) == "number" then
        if math.type(value) == "integer" or value == math.floor(value) then
            table.insert(out, string.format("%d", value))
        else
            table.insert(out, string.format("%.17g", value))
        end
    elseif type(value) == "string" then
        table.insert(out, string_text(value))
    elseif value[OBJECT] then
        table.insert(out, "{")
        for index, pair in ipairs(value[OBJECT]) do
            if index > 1 then
                table.insert(out, ", ")
            end
            table.insert(out, string_text(pair[1]))
            table.insert(out, ": ")
            encode_into(pair[2], out)
        end
        table.insert(out, "}")
    elseif value[ARRAY] then
        table.insert(out, "[")
        for index, item in ipairs(value[ARRAY]) do
            if index > 1 then
                table.insert(out, ", ")
            end
            encode_into(item, out)
        end
        table.insert(out, "]")
    else
        raise("ledger_json: a value that is neither an object nor an array was handed to the encoder")
    end
end

function encode(value)
    local out = {}
    encode_into(value, out)
    return table.concat(out)
end

function decode(text)
    return json.decode(text)
end

function is_array(value)
    return type(value) == "table" and (json.is_marked_as_array(value) or value[1] ~= nil) and true or false
end
