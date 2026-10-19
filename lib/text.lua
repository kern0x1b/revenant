-- Python-style string helpers for the tools that were ported from Python. Each one does what the
-- Python method it is named for does: split keeps empty fields, strip removes the whitespace of
-- str.strip(), startswith and endswith compare at a position, and truthy follows Python's rule for a
-- value read from JSON (nil, false, "", 0 and an empty table are false).

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

-- str.partition: the text before the first sep, sep, and the text after it (sep is "" when it is absent)
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

-- str.join over a Lua sequence
function join(sep, list)
    return table.concat(list, sep)
end

-- Python's format spec `{s:N}`: left-justified and padded to N characters (never truncated), counted
-- in code points as Python counts them
function ljust(s, width)
    local length = utf8.len(s) or #s
    if length >= width then
        return s
    end
    return s .. string.rep(" ", width - length)
end
