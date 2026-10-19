-- registry_json.lua - the JSON the registry files are made of, read and written the way Python's json
-- module does it: json.load on the text, and json.dump(value, handle, indent=1) with ensure_ascii.
--
-- Python dicts keep their insertion order and json.dump writes the keys in that order, so an object here
-- is a Lua table whose string keys are its fields, and whose key order is kept beside it in a table that
-- maps the object to its keys. An object is therefore made with new_object (or read with parse_tree), and
-- a table without a key order is an array. Values are strings, arrays, objects, booleans, numbers and
-- null (null() is a sentinel, because a Lua table cannot hold nil). The registry files hold strings,
-- arrays and objects only; the other kinds are here so a parse of any valid document does not fail.
--
-- A malformed document is a Python exception in json.load, so it fails with the exit status of an
-- uncaught exception (1), through vtlib's fail.

local V = import("vtlib", {rootdir = os.scriptdir()})

-- object table -> its keys, in order
local KEYS_OF = {}
-- the sentinel for JSON null
local NULL = {}

function null()
    return NULL
end

-- An object from { {key, value}, ... }, in that order.
function new_object(pairs_list)
    local obj = {}
    local keys = {}
    for _, pair in ipairs(pairs_list) do
        keys[#keys + 1] = pair[1]
        obj[pair[1]] = pair[2]
    end
    KEYS_OF[obj] = keys
    return obj
end

-- The keys of an object, in order.
function object_keys(obj)
    return KEYS_OF[obj]
end

-- Parses a JSON document. The positions are 1-based byte indices into text.

local function fail_at(text, i, what)
    V.fail("json.JSONDecodeError: " .. what .. " at char " .. (i - 1) .. " of document of " .. #text .. " bytes")
end

local function skip(text, i)
    while true do
        local b = string.byte(text, i)
        if b == 32 or b == 9 or b == 10 or b == 13 then
            i = i + 1
        else
            return i
        end
    end
end

local function hex4(text, i)
    local digits = string.sub(text, i, i + 3)
    if not string.match(digits, "^%x%x%x%x$") then
        fail_at(text, i, "Invalid \\uXXXX escape")
    end
    return tonumber(digits, 16)
end

-- The string beginning at the '"' at i: returns its bytes and the index after the closing quote.
local function parse_string(text, i)
    local out = {}
    local j = i + 1
    while true do
        local b = string.byte(text, j)
        if b == nil then
            fail_at(text, i, "Unterminated string starting at")
        elseif b == 34 then
            return table.concat(out), j + 1
        elseif b == 92 then
            local e = string.sub(text, j + 1, j + 1)
            if e == '"' or e == "\\" or e == "/" then
                out[#out + 1] = e
                j = j + 2
            elseif e == "b" then
                out[#out + 1] = "\b"
                j = j + 2
            elseif e == "f" then
                out[#out + 1] = "\f"
                j = j + 2
            elseif e == "n" then
                out[#out + 1] = "\n"
                j = j + 2
            elseif e == "r" then
                out[#out + 1] = "\r"
                j = j + 2
            elseif e == "t" then
                out[#out + 1] = "\t"
                j = j + 2
            elseif e == "u" then
                local cp = hex4(text, j + 2)
                j = j + 6
                if cp >= 0xD800 and cp <= 0xDBFF and string.sub(text, j, j + 1) == "\\u" then
                    local low = hex4(text, j + 2)
                    if low >= 0xDC00 and low <= 0xDFFF then
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                        j = j + 6
                    end
                end
                out[#out + 1] = utf8.char(cp)
            else
                fail_at(text, j, "Invalid \\escape")
            end
        else
            out[#out + 1] = string.char(b)
            j = j + 1
        end
    end
end

local parse_value

local function parse_object(text, i)
    local pairs_list = {}
    local j = skip(text, i + 1)
    if string.byte(text, j) == 125 then
        return new_object(pairs_list), j + 1
    end
    while true do
        if string.byte(text, j) ~= 34 then
            fail_at(text, j, "Expecting property name enclosed in double quotes")
        end
        local key
        key, j = parse_string(text, j)
        j = skip(text, j)
        if string.byte(text, j) ~= 58 then
            fail_at(text, j, "Expecting ':' delimiter")
        end
        local value
        value, j = parse_value(text, skip(text, j + 1))
        pairs_list[#pairs_list + 1] = {key, value}
        j = skip(text, j)
        local b = string.byte(text, j)
        if b == 44 then
            j = skip(text, j + 1)
        elseif b == 125 then
            return new_object(pairs_list), j + 1
        else
            fail_at(text, j, "Expecting ',' delimiter")
        end
    end
end

local function parse_array(text, i)
    local out = {}
    local j = skip(text, i + 1)
    if string.byte(text, j) == 93 then
        return out, j + 1
    end
    while true do
        local value
        value, j = parse_value(text, j)
        out[#out + 1] = value
        j = skip(text, j)
        local b = string.byte(text, j)
        if b == 44 then
            j = skip(text, j + 1)
        elseif b == 93 then
            return out, j + 1
        else
            fail_at(text, j, "Expecting ',' delimiter")
        end
    end
end

parse_value = function(text, i)
    local b = string.byte(text, i)
    if b == 123 then
        return parse_object(text, i)
    elseif b == 91 then
        return parse_array(text, i)
    elseif b == 34 then
        return parse_string(text, i)
    end
    local word = string.match(text, "^true", i)
    if word then
        return true, i + 4
    end
    word = string.match(text, "^false", i)
    if word then
        return false, i + 5
    end
    word = string.match(text, "^null", i)
    if word then
        return NULL, i + 4
    end
    local number = string.match(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    if number and number ~= "" then
        return tonumber(number), i + #number
    end
    fail_at(text, i, "Expecting value")
end

-- The value of a JSON document held in text, as json.loads gives it.
function parse_tree(text)
    local value, j = parse_value(text, skip(text, 1))
    j = skip(text, j)
    if j <= #text then
        fail_at(text, j, "Extra data")
    end
    return value
end

-- Writes: json.dump(value, handle, indent=1), without the newline the caller adds.

-- A string as json.dumps writes it with ensure_ascii: escapes, and \uXXXX for every byte outside
-- space to tilde, with a surrogate pair for a code point above 0xFFFF.
local SIMPLE_ESCAPE = {
    [34] = '\\"', [92] = "\\\\", [8] = "\\b", [12] = "\\f", [10] = "\\n", [13] = "\\r", [9] = "\\t",
}

local function encode_codepoint(cp, out)
    if cp >= 0x10000 then
        local v = cp - 0x10000
        out[#out + 1] = string.format("\\u%04x\\u%04x", 0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF))
    else
        out[#out + 1] = string.format("\\u%04x", cp)
    end
end

local function encode_string(s)
    local out = {'"'}
    local i = 1
    local n = #s
    while i <= n do
        local b = string.byte(s, i)
        if b < 128 then
            if SIMPLE_ESCAPE[b] then
                out[#out + 1] = SIMPLE_ESCAPE[b]
            elseif b >= 32 and b <= 126 then
                out[#out + 1] = string.char(b)
            else
                out[#out + 1] = string.format("\\u%04x", b)
            end
            i = i + 1
        else
            local length, cp
            if b >= 0xF0 then
                length, cp = 4, b & 0x07
            elseif b >= 0xE0 then
                length, cp = 3, b & 0x0F
            else
                length, cp = 2, b & 0x1F
            end
            for k = 1, length - 1 do
                cp = (cp << 6) | (string.byte(s, i + k) & 0x3F)
            end
            encode_codepoint(cp, out)
            i = i + length
        end
    end
    out[#out + 1] = '"'
    return table.concat(out)
end

local function encode_number(x)
    if math.type(x) == "integer" then
        return string.format("%d", x)
    end
    return string.format("%.17g", x)
end

local encode_value

-- The text of a value at nesting level `level`, with the indent Python's indent=1 uses.
encode_value = function(value, level)
    if value == NULL then
        return "null"
    elseif value == true then
        return "true"
    elseif value == false then
        return "false"
    elseif type(value) == "number" then
        return encode_number(value)
    elseif type(value) == "string" then
        return encode_string(value)
    end
    local inner = string.rep(" ", level + 1)
    local outer = string.rep(" ", level)
    local keys = KEYS_OF[value]
    if keys then
        if #keys == 0 then
            return "{}"
        end
        local parts = {}
        for _, key in ipairs(keys) do
            parts[#parts + 1] = inner .. encode_string(key) .. ": " .. encode_value(value[key], level + 1)
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. outer .. "}"
    end
    if #value == 0 then
        return "[]"
    end
    local parts = {}
    for _, item in ipairs(value) do
        parts[#parts + 1] = inner .. encode_value(item, level + 1)
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. outer .. "]"
end

-- The document text json.dump(value, handle, indent=1) writes.
function write_tree(value)
    return encode_value(value, 0)
end
