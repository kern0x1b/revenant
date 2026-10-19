local V = import("vtlib", {rootdir = os.scriptdir()})

local function skip_ws(text, i)
    if i > #text then
        return i
    end
    local _, last = string.find(text, "^[ \t\n\r]*", i)
    return last + 1
end

local function hex4(text, i)
    local digits = string.sub(text, i, i + 3)
    if string.match(digits, "^%x%x%x%x$") then
        return tonumber(digits, 16)
    end
    return nil
end

local function parse_string(text, i)
    local parts = {}
    local j = i + 1
    while true do
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
            if code >= 0xD800 and code <= 0xDBFF and string.sub(text, after, after + 1) == "\\u" then
                local low = hex4(text, after + 2)
                if low and low >= 0xDC00 and low <= 0xDFFF then
                    code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                    after = after + 6
                end
            end
            parts[#parts + 1] = utf8.char(code)
            j = after
        else
            raise("bad escape in a string")
        end
    end
end

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

function read_object(path)
    local text = V.read_file(path)
    return parse_document(text)
end
