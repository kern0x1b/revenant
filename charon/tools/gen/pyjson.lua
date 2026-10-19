-- JSON text laid out as Python's json.dump(value, indent=N) lays it out, so a generator's registry and manifest files are byte-equal
-- to the Python they replace. A value is a string, an integer, nil (null), a list {array = {...}}, or an object {object = {{key, value},
-- ...}} whose keys keep the order they are given in. Strings are escaped as ensure_ascii does. json.dump writes no newline after the
-- value, and so does this: a caller that wants one adds it.
--
--     encode(value, unit)   unit is one level of indentation: "  " for indent=2, " " for indent=1

-- A JSON string, quoted and escaped. A non-ASCII byte would be written as \uXXXX by Python, and this writer does not do that, so it
-- refuses one rather than write a different file.
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
