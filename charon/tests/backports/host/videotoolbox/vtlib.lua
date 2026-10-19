-- vtlib.lua - the helpers the VideoToolbox scripts share, each one doing what the Python it replaces did.
-- A module: the functions are top-level, and a script reaches them with
--     local lib = import("vtlib", {rootdir = os.scriptdir(), anonymous = true})
-- None of this is a regular expression: each Python pattern is written out by hand where a script needs it.

-- Python's text mode: "\r\n" and "\r" read as "\n". Every file the Python read in text mode is read here through this.
function read_text(path)
    local handle = assert(io.open(path, "rb"))
    local text = handle:read("a")
    handle:close()
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    return text
end

-- str.split(sep) for a plain separator: a trailing separator leaves a trailing "" as Python does.
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

-- `for line in open(path)`: the lines without their "\n", and no empty line after a final "\n".
function file_lines(text)
    local out = split_text(text, "\n")
    if out[#out] == "" then
        out[#out] = nil
    end
    return out
end

-- str.strip() for the blanks a line carries.
function strip(s)
    local out = s:gsub("^%s+", ""):gsub("%s+$", "")
    return out
end

-- Byte order. Lua's own < follows the locale (strcoll), and Python's sort of str is by code point.
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

-- The files matching a glob in one directory, as paths, sorted by bytes (Python's sorted(glob.glob(...))).
function files_matching(directory, pattern)
    return sort_bytes(os.files(path.join(directory, pattern)))
end

-- repr() of a str, as Python writes it: a single quote unless the text has one and no double quote, the escapes
-- \\ \n \r \t and \xNN for the other control characters. Non-ASCII bytes are kept as they are.
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

-- repr() of a list of strings: [] , ['a'] , ['a', 'b'].
function py_list(list)
    local items = {}
    for i, item in ipairs(list) do
        items[i] = py_repr(item)
    end
    return "[" .. table.concat(items, ", ") .. "]"
end

-- A value as "%s" writes it in Python: None for nothing.
function py_value(v)
    if v == nil then
        return "None"
    end
    return tostring(v)
end

-- tuple(int(part) for part in release.split(".")): a list of integers. A part that is not digits raises, as int() does.
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

-- Python's tuple < for two lists of integers.
function tuple_less(a, b)
    local n = math.min(#a, #b)
    for i = 1, n do
        if a[i] ~= b[i] then
            return a[i] < b[i]
        end
    end
    return #a < #b
end

-- The same-or-before order: a <= b for two tuples.
function tuple_le(a, b)
    return not tuple_less(b, a)
end

-- The ladder table, ladder.tsv: a comment line starts with "#", a blank line is skipped, and a line is name TAB release.
-- Returns the (name, release) pairs in file order, the release as the line gives it with the TAB removed and the
-- end of line taken off, so a caller decides what "-" and "" mean.
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

-- str.count(needle) for a plain needle: the occurrences that do not overlap.
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

-- The bytes of a file, written as Python's open(path, "w").write(text) writes them.
function write_text(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end

-- s starts with prefix (plain text).
function starts_with(s, prefix)
    return string.sub(s, 1, #prefix) == prefix
end

-- The number of keys a table holds (len() of a Python dict).
function count_keys(map)
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

-- The keys of a table, sorted by bytes (sorted(dict)).
function keys_sorted(map)
    local out = {}
    for k in pairs(map) do
        out[#out + 1] = k
    end
    return sort_bytes(out)
end
