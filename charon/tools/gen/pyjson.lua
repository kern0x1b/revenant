local function string_text(text)
    assert(not string.find(text, "[\128-\255]"), "a JSON string holds a non-ASCII byte, which this writer does not escape")
    local escaped = string.gsub(text, "[%z\1-\31\"\\]", function (c)
        local named = {['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f"}
        return named[c] or string.format("\\u%04x", string.byte(c))
    end)
    return '"' .. escaped .. '"'
end

local function text_of(value, depth, unit)
    if value == nil then
        return "null"
    end
    if type(value) == "number" then
        return string.format("%d", value)
    end
    if type(value) == "string" then
        return string_text(value)
    end
    local pad, inner = string.rep(unit, depth), string.rep(unit, depth + 1)
    local items = {}
    if value.object then
        for _, pair in ipairs(value.object) do
            table.insert(items, inner .. string_text(pair[1]) .. ": " .. text_of(pair[2], depth + 1, unit))
        end
        if #items == 0 then
            return "{}"
        end
        return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
    end
    for _, item in ipairs(value.array) do
        table.insert(items, inner .. text_of(item, depth + 1, unit))
    end
    if #items == 0 then
        return "[]"
    end
    return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
end

function encode(value, unit)
    return text_of(value, 0, unit)
end
