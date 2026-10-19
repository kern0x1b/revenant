function read_text(path)
    if not os.isfile(path) then
        io.stderr:write(path .. ": cannot be read\n")
        os.exit(1)
    end
    local handle = io.open(path, "rb")
    local text = handle:read("a")
    handle:close()
    return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

function text_lines(text)
    local out = {}
    local pos = 1
    while pos <= #text do
        local nl = text:find("\n", pos, true)
        if nl then
            out[#out + 1] = text:sub(pos, nl - 1)
            pos = nl + 1
        else
            out[#out + 1] = text:sub(pos)
            break
        end
    end
    return out
end

function split_on(s, sep, maxsplit)
    local out, pos, splits = {}, 1, 0
    while true do
        if maxsplit and splits >= maxsplit then
            out[#out + 1] = s:sub(pos)
            return out
        end
        local at = s:find(sep, pos, true)
        if not at then
            out[#out + 1] = s:sub(pos)
            return out
        end
        out[#out + 1] = s:sub(pos, at - 1)
        pos = at + #sep
        splits = splits + 1
    end
end

function starts_with(s, prefix)
    return s:sub(1, #prefix) == prefix
end

function strip(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function byte_less(a, b)
    local n = math.min(#a, #b)
    for i = 1, n do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

function count_of(text, needle)
    local n, pos = 0, 1
    while true do
        local _, e = text:find(needle, pos, true)
        if not e then
            return n
        end
        n = n + 1
        pos = e + 1
    end
end

function py_repr(s)
    local quote = "'"
    if s:find("'", 1, true) and not s:find('"', 1, true) then
        quote = '"'
    end
    local out = s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    if quote == "'" then
        out = out:gsub("'", "\\'")
    end
    return quote .. out .. quote
end

function py_list(items)
    local shown = {}
    for _, item in ipairs(items) do
        shown[#shown + 1] = py_repr(item)
    end
    return "[" .. table.concat(shown, ", ") .. "]"
end

function py_int(s)
    local digits = s:match("^%s*([+-]?%d+)%s*$")
    if digits == nil then
        return nil
    end
    return math.tointeger(tonumber(digits))
end

function same_list(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

function case_rows(path)
    local rows, wrong = {}, {}
    for _, line in ipairs(text_lines(read_text(path))) do
        if starts_with(line, "WRONG\t") then
            wrong[#wrong + 1] = split_on(line, "\t", 1)[2]
        elseif line:find("\t", 1, true) then
            local p = split_on(line, "\t")
            rows[p[1]] = {table.unpack(p, 2)}
        end
    end
    return wrong, rows
end

function first_field(rows, label)
    local r = rows[label]
    if r == nil then
        return nil
    end
    return r[1]
end
