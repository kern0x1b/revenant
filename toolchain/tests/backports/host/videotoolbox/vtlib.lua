function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    return text
end

function split_text(text, sep)
    local out, from = {}, 1
    while true do
        local s, e = string.find(text, sep, from, true)
        if not s then
            out[#out + 1] = string.sub(text, from)
            return out
        end
        out[#out + 1] = string.sub(text, from, s - 1)
        from = e + 1
    end
end

function file_lines(text)
    local out = split_text(text, "\n")
    if out[#out] == "" then
        out[#out] = nil
    end
    return out
end

function strip(s)
    local out = s:gsub("^%s+", ""):gsub("%s+$", "")
    return out
end

function byte_less(a, b)
    local n = math.min(#a, #b)
    for i = 1, n do
        local x, y = string.byte(a, i), string.byte(b, i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

function sort_bytes(list)
    table.sort(list, byte_less)
    return list
end

function files_matching(directory, pattern)
    return sort_bytes(os.files(path.join(directory, pattern)))
end

function py_repr(s)
    local quote = "'"
    if s:find("'", 1, true) and not s:find('"', 1, true) then
        quote = '"'
    end
    local out = { quote }
    for i = 1, #s do
        local c = s:sub(i, i)
        local b = string.byte(c)
        if c == "\\" then
            out[#out + 1] = "\\\\"
        elseif c == quote then
            out[#out + 1] = "\\" .. c
        elseif c == "\n" then
            out[#out + 1] = "\\n"
        elseif c == "\r" then
            out[#out + 1] = "\\r"
        elseif c == "\t" then
            out[#out + 1] = "\\t"
        elseif b < 32 or b == 127 then
            out[#out + 1] = string.format("\\x%02x", b)
        else
            out[#out + 1] = c
        end
    end
    out[#out + 1] = quote
    return table.concat(out)
end

function py_list(list)
    local items = {}
    for i, item in ipairs(list) do
        items[i] = py_repr(item)
    end
    return "[" .. table.concat(items, ", ") .. "]"
end

function py_value(v)
    if v == nil then
        return "None"
    end
    return tostring(v)
end

function release_key(release)
    local out = {}
    for part in string.gmatch(release .. ".", "([^.]*)%.") do
        if not part:match("^%d+$") then
            raise(string.format("int() cannot read %s in the release %s", py_repr(part), py_repr(release)))
        end
        out[#out + 1] = math.tointeger(tonumber(part))
    end
    return out
end

function tuple_less(a, b)
    local n = math.min(#a, #b)
    for i = 1, n do
        if a[i] ~= b[i] then
            return a[i] < b[i]
        end
    end
    return #a < #b
end

function tuple_le(a, b)
    return not tuple_less(b, a)
end

function ladder_rows(text)
    local out = {}
    for _, line in ipairs(file_lines(text)) do
        if line:sub(1, 1) ~= "#" and strip(line) ~= "" then
            local stripped = line:gsub("\n$", "")
            local tab = stripped:find("\t", 1, true)
            local name, release
            if tab then
                name, release = stripped:sub(1, tab - 1), stripped:sub(tab + 1)
            else
                name, release = stripped, ""
            end
            if name ~= "" then
                out[#out + 1] = { name = name, release = release }
            end
        end
    end
    return out
end

function count_plain(text, needle)
    local n, from = 0, 1
    while true do
        local s, e = string.find(text, needle, from, true)
        if not s then
            return n
        end
        n = n + 1
        from = e + 1
    end
end

function write_text(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end

function starts_with(s, prefix)
    return string.sub(s, 1, #prefix) == prefix
end

function count_keys(map)
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

function keys_sorted(map)
    local out = {}
    for k in pairs(map) do
        out[#out + 1] = k
    end
    return sort_bytes(out)
end
