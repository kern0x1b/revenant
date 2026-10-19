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

function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    return sort_bytes(keys)
end

function count_entries(map)
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

function read_file(path)
    local handle, err = io.open(path, "rb")
    if not handle then
        raise("cannot read " .. path .. ": " .. tostring(err))
    end
    local text = handle:read("a")
    handle:close()
    return text
end

function read_text(path)
    local text = read_file(path)
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    return text
end

function read_lines(path)
    local text = read_text(path)
    local lines = {}
    local start = 1
    while start <= #text do
        local stop = text:find("\n", start, true)
        if not stop then
            lines[#lines + 1] = text:sub(start)
            break
        end
        lines[#lines + 1] = text:sub(start, stop - 1)
        start = stop + 1
    end
    return lines
end

function write_file(path, text)
    local handle, err = io.open(path, "wb")
    if not handle then
        raise("cannot write " .. path .. ": " .. tostring(err))
    end
    handle:write(text)
    handle:close()
end

function fail(message)
    io.stderr:write(message, "\n")
    os.exit(1)
end

function join_path(a, b)
    if string.sub(a, -1) == "/" then
        return a .. b
    end
    return a .. "/" .. b
end

function header_paths(dir)
    local found = {}
    for _, path in ipairs(os.files(dir .. "/*.h")) do
        local name = string.match(path, "([^/]*)$")
        if string.sub(name, 1, 1) ~= "." then
            found[#found + 1] = path
        end
    end
    return sort_bytes(found)
end

function header_text(dir)
    local texts = {}
    for _, path in ipairs(header_paths(dir)) do
        texts[#texts + 1] = read_text(path)
    end
    return table.concat(texts, "\n")
end

function py_repr(s)
    local quote = "'"
    if string.find(s, "'", 1, true) and not string.find(s, "\"", 1, true) then
        quote = "\""
    end
    local out = {quote}
    for i = 1, #s do
        local b = string.byte(s, i)
        local c = string.sub(s, i, i)
        if c == "\\" then
            out[#out + 1] = "\\\\"
        elseif c == quote then
            out[#out + 1] = "\\" .. quote
        elseif b == 9 then
            out[#out + 1] = "\\t"
        elseif b == 10 then
            out[#out + 1] = "\\n"
        elseif b == 13 then
            out[#out + 1] = "\\r"
        elseif b < 32 or b == 127 then
            out[#out + 1] = string.format("\\x%02x", b)
        else
            out[#out + 1] = c
        end
    end
    out[#out + 1] = quote
    return table.concat(out)
end
