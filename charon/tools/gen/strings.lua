-- The string operations the oracle's code runs on text (strip, collapse, the part before a separator, the last occurrence of a
-- plain substring, Python's splitlines), spelled once for the commands. Lua patterns only: nothing here is a regular expression.

local tsv = import("tsv", {anonymous = true})

-- A set: a table keyed by each string of the list.
function set(list)
    local out = {}
    for _, item in ipairs(list) do
        out[item] = true
    end
    return out
end

-- The text without leading and trailing whitespace (Python's strip()).
function strip(text)
    return (string.gsub((string.gsub(text, "^%s+", "")), "%s+$", ""))
end

-- The text with each run of whitespace as one space, and none at either end (Python's " ".join(text.split())).
function collapse(text)
    return strip((string.gsub(text, "%s+", " ")))
end

-- The text without the characters of a pattern class at its end (Python's rstrip(chars)); class is e.g. "[ ;]".
function rstrip(text, class)
    return (string.gsub(text, class .. "+$", ""))
end

-- The text before the first occurrence of a plain separator (Python's split(sep)[0]); the whole text when there is none.
function before(text, sep)
    local at = string.find(text, sep, 1, true)
    if at == nil then
        return text
    end
    return string.sub(text, 1, at - 1)
end

-- The index of the last occurrence of a plain substring (Python's rfind), or nil when there is none.
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

-- The text with the universal newlines of a text read in Python's text mode: \r\n and \r become \n.
function universal(text)
    return (string.gsub(text, "\r\n?", "\n"))
end

-- The lines of a text as Python's str.splitlines() gives them: the line breaks are \n, \r\n, \r, \v, \f, \x1c, \x1d, \x1e, NEL
-- (U+0085), LS (U+2028) and PS (U+2029) as UTF-8, and a final break ends the last line rather than starting an empty one. The one
-- definition of a line of a text in the generator (the program output, the hand sources, the markup of ipsw).
function lines(text)
    local marked = string.gsub(universal(text), "[\11\12\28-\30]", "\n")
    marked = string.gsub(marked, "\194\133", "\n")
    marked = string.gsub(marked, "\226\128[\168\169]", "\n")
    return tsv.lines(marked)
end

-- The text with each character that is not ASCII written as an escape, as Python's encode("ascii", "backslashreplace") writes it: \xhh
-- for a code point below 0x100, \uhhhh below 0x10000 and \Uhhhhhhhh above. The text is UTF-8, read as code points.
-- A text that is not UTF-8 is refused: a stray continuation byte or a truncated sequence has no code point to escape.
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
