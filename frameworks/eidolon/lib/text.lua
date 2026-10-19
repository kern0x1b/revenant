function split(s, sep)
    local out, start = {}, 1
    while true do
        local i, j = string.find(s, sep, start, true)
        if not i then
            out[#out + 1] = string.sub(s, start)
            return out
        end
        out[#out + 1] = string.sub(s, start, i - 1)
        start = j + 1
    end
end

function lstrip(s)
    return (string.gsub(s, "^%s+", ""))
end

function rstrip(s)
    return (string.gsub(s, "%s+$", ""))
end

function strip(s)
    return rstrip(lstrip(s))
end

function partition(s, sep)
    local i, j = string.find(s, sep, 1, true)
    if not i then
        return s, "", ""
    end
    return string.sub(s, 1, i - 1), sep, string.sub(s, j + 1)
end

function startswith(s, prefix, at)
    at = at or 1
    return string.sub(s, at, at + #prefix - 1) == prefix
end

function truthy(v)
    if v == nil or v == false or v == "" or v == 0 then
        return false
    end
    if type(v) == "table" then
        for _ in pairs(v) do
            return true
        end
        return false
    end
    return true
end

function contains(list, want)
    for _, item in ipairs(list) do
        if item == want then
            return true
        end
    end
    return false
end

function join(sep, list)
    return table.concat(list, sep)
end

function is_word(s, p)
    local c = string.sub(s, p, p)
    return c ~= "" and string.find(c, "^[%w_]") ~= nil
end

function boundary(s, p)
    return p == 1 or not is_word(s, p - 1)
end

function positions(s, needle)
    local out, from = {}, 1
    while true do
        local at = string.find(s, needle, from, true)
        if not at then
            return out
        end
        out[#out + 1] = at
        from = at + 1
    end
end

function has_word(s, word)
    for _, at in ipairs(positions(s, word)) do
        if boundary(s, at) and not is_word(s, at + #word) then
            return true
        end
    end
    return false
end

function name_after(s, keyword)
    for _, at in ipairs(positions(s, keyword)) do
        if boundary(s, at) then
            local name = string.match(s, "^[%w_]+", at + #keyword)
            if name then
                return name
            end
        end
    end
    return nil
end

function ljust(s, width)
    local length = utf8.len(s) or #s
    if length >= width then
        return s
    end
    return s .. string.rep(" ", width - length)
end
