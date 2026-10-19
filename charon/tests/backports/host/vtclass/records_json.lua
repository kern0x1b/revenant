-- records_json.lua - reads the records file record.m writes: an NSJSON pretty-printed object whose values
-- are strings or null, with its keys sorted. It is a module (no return value): a script reaches it as
--
--     local R = import("records_json", {rootdir = os.scriptdir()})
--     local map = R.read_object(path)
--
-- read_object(path) returns a Lua table from key to value, where a value is the string, or false for a
-- JSON null. A Lua table cannot hold nil as a value, so null is false, and a missing key is nil: a caller
-- tells them apart by a comparison, as compare.lua does with the Python's None. read_object raises when the
-- file cannot be read or is not JSON, so a caller that must end the run catches the error and fails.
--
-- The grammar is the whole of JSON for the values NSJSON writes: an object, keys and string values in
-- double quotes with the escapes \" \\ \/ \b \f \n \r \t and \uXXXX (a surrogate pair is joined into one
-- code point, as Python's json does), null, and the whitespace NSJSON writes (space, tab, LF, CR). A
-- value that is a number, true, false, an array or an object is valid JSON that record.m never writes,
-- so it is refused rather than stored: the map promises strings and nulls and nothing else. A repeated
-- key keeps its last value, as Python's dict does. A raw control character inside a string is refused,
-- as Python's json refuses it (strict mode), and so is a UTF-8 byte order mark, which Python refuses too.

local V = import("vtlib", {rootdir = os.scriptdir()})

-- Advances past JSON whitespace (space, tab, LF, CR) from byte i and returns the next position.
local function skip_ws(text, i)
    if i > #text then
        return i
    end
    local _, last = string.find(text, "^[ \t\n\r]*", i)
    return last + 1
end

-- The four hex digits at byte i as a number, or nil when they are not four hex digits.
local function hex4(text, i)
    local digits = string.sub(text, i, i + 3)
    if string.match(digits, "^%x%x%x%x$") then
        return tonumber(digits, 16)
    end
    return nil
end

-- Reads the string whose opening quote is at byte i. Returns the decoded string and the position after
-- its closing quote.
local function parse_string(text, i)
    local parts = {}
    local j = i + 1
    while true do
        -- the next byte that ends a run of plain characters: a quote, a backslash, or a control character
        local s = string.find(text, "[\0-\31\"\\]", j)
        if not s then
            raise("unterminated string")
        end
        if s > j then
            parts[#parts + 1] = string.sub(text, j, s - 1)
        end
        local c = string.sub(text, s, s)
        if c == "\"" then
            return table.concat(parts), s + 1
        end
        if c ~= "\\" then
            raise("control character in a string")
        end
        local e = string.sub(text, s + 1, s + 1)
        if e == "\"" or e == "\\" or e == "/" then
            parts[#parts + 1] = e
            j = s + 2
        elseif e == "b" then
            parts[#parts + 1] = "\8"
            j = s + 2
        elseif e == "f" then
            parts[#parts + 1] = "\12"
            j = s + 2
        elseif e == "n" then
            parts[#parts + 1] = "\10"
            j = s + 2
        elseif e == "r" then
            parts[#parts + 1] = "\13"
            j = s + 2
        elseif e == "t" then
            parts[#parts + 1] = "\9"
            j = s + 2
        elseif e == "u" then
            local code = hex4(text, s + 2)
            if not code then
                raise("bad \\u escape")
            end
            local after = s + 6
            -- a high surrogate followed by a low one is one code point
            if code >= 0xD800 and code <= 0xDBFF and string.sub(text, after, after + 1) == "\\u" then
                local low = hex4(text, after + 2)
                if low and low >= 0xDC00 and low <= 0xDFFF then
                    code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                    after = after + 6
                end
            end
            -- a lone surrogate is kept as its three-byte form, as Python keeps it in the string
            parts[#parts + 1] = utf8.char(code)
            j = after
        else
            raise("bad escape in a string")
        end
    end
end

-- Reads the value at byte i: a string, or null (false). Anything else is refused, as the header says.
local function parse_value(text, i)
    local c = string.sub(text, i, i)
    if c == "\"" then
        return parse_string(text, i)
    end
    if string.sub(text, i, i + 3) == "null" then
        return false, i + 4
    end
    raise("a value that is not a string or null at byte " .. i)
end

-- Reads the whole document: one object, then nothing but whitespace.
local function parse_document(text)
    if string.sub(text, 1, 3) == "\239\187\191" then
        raise("a UTF-8 byte order mark")
    end
    if utf8.len(text) == nil then
        raise("not UTF-8")
    end
    local map = {}
    local i = skip_ws(text, 1)
    if string.sub(text, i, i) ~= "{" then
        raise("the document is not an object")
    end
    i = skip_ws(text, i + 1)
    if string.sub(text, i, i) == "}" then
        i = i + 1
    else
        while true do
            if string.sub(text, i, i) ~= "\"" then
                raise("an object key is not a string at byte " .. i)
            end
            local key
            key, i = parse_string(text, i)
            i = skip_ws(text, i)
            if string.sub(text, i, i) ~= ":" then
                raise("expected ':' at byte " .. i)
            end
            i = skip_ws(text, i + 1)
            local value
            value, i = parse_value(text, i)
            map[key] = value
            i = skip_ws(text, i)
            local c = string.sub(text, i, i)
            if c == "}" then
                i = i + 1
                break
            end
            if c ~= "," then
                raise("expected ',' or '}' at byte " .. i)
            end
            i = skip_ws(text, i + 1)
        end
    end
    i = skip_ws(text, i)
    if i <= #text then
        raise("extra data after the object at byte " .. i)
    end
    return map
end

-- The records in the file at path: a table from key to string, with false for a JSON null. Raises when
-- the file cannot be read or does not hold such an object.
function read_object(path)
    local text = V.read_file(path)
    return parse_document(text)
end
