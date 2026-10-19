-- tsv.lua - the reading every comparator and generator in this directory shares, so each one reads its file the way the Python did.
--
--    local tsv = import("tsv", {rootdir = os.scriptdir()})
--
-- read_text    a file as Python's text mode reads it: "\r\n" and a lone "\r" are line ends, and become "\n"
-- text_lines   the lines of a text as a for-loop over a Python file yields them: each ends at a "\n", and a last line with
--              no "\n" is a line too; the "\n" is NOT kept (a caller that did `.rstrip("\n")` gets the same line)
-- split_on     Python's str.split(sep), or str.split(sep, 1) when maxsplit is 1
-- starts_with  str.startswith
-- strip        str.strip() for the ASCII whitespace the names lists and the outputs carry
-- byte_less    the order str.sort gives for ASCII and UTF-8: by bytes. The string comparison in Lua follows the locale.
-- count_of     str.count: non-overlapping matches of a plain needle

function read_text(path)
    if not os.isfile(path) then
        io.stderr:write(path .. ": cannot be read\n")
        os.exit(1)
    end
    -- io.open raises on a missing file rather than returning nil, so the check is made first
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

-- Python's repr of a str, for a value in a DIFFERS line. The quote is ' unless the text has a ' and no ", and the escapes are the
-- ones repr makes for the characters a row can carry.
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

-- Python's repr of a list of strs, for a %r in a DIFFERS line: "[]", "['a']", "['a', 'b']".
function py_list(items)
    local shown = {}
    for _, item in ipairs(items) do
        shown[#shown + 1] = py_repr(item)
    end
    return "[" .. table.concat(shown, ", ") .. "]"
end

-- Python's int() of a str: optional blanks and sign and digits, or nil where Python raises ValueError.
function py_int(s)
    local digits = s:match("^%s*([+-]?%d+)%s*$")
    if digits == nil then
        return nil
    end
    return math.tointeger(tonumber(digits))
end

-- Python's list == list for lists of strs: the same length, and each item equal in order.
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

-- The rows of a case's output, read the way the protocol comparators read them: the WRONG lines, in order, and the rows keyed by
-- name, each holding the fields AFTER the name (Python's p[1:]). A later row for a name wins. Returns wrong, rows.
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

-- The first field after a row's name, or nil when there is no such row: Python's rows.get(label, [None])[0].
function first_field(rows, label)
    local r = rows[label]
    if r == nil then
        return nil
    end
    return r[1]
end
