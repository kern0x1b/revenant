local tsv = import("tsv", {anonymous = true})

function set(list)
    local out = {}
    for _, item in ipairs(list) do
        out[item] = true
    end
    return out
end

function strip(text)
    return (string.gsub((string.gsub(text, "^%s+", "")), "%s+$", ""))
end

function collapse(text)
    return strip((string.gsub(text, "%s+", " ")))
end

function rstrip(text, class)
    return (string.gsub(text, class .. "+$", ""))
end

function before(text, sep)
    local at = string.find(text, sep, 1, true)
    if at == nil then
        return text
    end
    return string.sub(text, 1, at - 1)
end

function last_index(text, sub)
    local found, pos = nil, 1
    while true do
        local at = string.find(text, sub, pos, true)
        if at == nil then
            return found
        end
        found = at
        pos = at + 1
    end
end

function universal(text)
    return (string.gsub(text, "\r\n?", "\n"))
end

function lines(text)
    local marked = string.gsub(universal(text), "[\11\12\28-\30]", "\n")
    marked = string.gsub(marked, "\194\133", "\n")
    marked = string.gsub(marked, "\226\128[\168\169]", "\n")
    return tsv.lines(marked)
end

function backslash_replace(text)
    if not string.find(text, "[\128-\255]") then
        return text
    end
    local out = {}
    local pos = 1
    while pos <= #text do
        local c = string.byte(text, pos)
        local size = c < 0x80 and 1 or c >= 0xF0 and 4 or c >= 0xE0 and 3 or c >= 0xC0 and 2 or nil
        assert(size, "not UTF-8 text")
        if size == 1 then
            table.insert(out, string.char(c))
        else
            local code = c & (0xFF >> (size + 1))
            for i = 1, size - 1 do
                local continuation = string.byte(text, pos + i)
                assert(continuation and continuation >= 0x80 and continuation < 0xC0, "not UTF-8 text")
                code = (code << 6) | (continuation & 0x3F)
            end
            if code < 0x100 then
                table.insert(out, string.format("\\x%02x", code))
            elseif code < 0x10000 then
                table.insert(out, string.format("\\u%04x", code))
            else
                table.insert(out, string.format("\\U%08x", code))
            end
            pos = pos + size - 1
        end
        pos = pos + 1
    end
    return table.concat(out)
end
