-- vtlib.lua - the helpers the vtclass Lua scripts share: byte-order sorting, whole-file reads and
-- writes, text read with the Python text-mode newline rule, and the failure exit. It is a module, so a
-- script reaches it as import("vtlib", {rootdir = os.scriptdir()}) and calls its functions by name.
--
-- Sorting: Lua's own string comparison follows the process locale (strcoll), and Python's sorted() on
-- str is by code point, which for UTF-8 is byte order. byte_less compares bytes and so does not depend
-- on the locale.

-- True when string a sorts before string b, comparing bytes, as Python's str order does for ASCII and
-- UTF-8 alike.
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

-- Sorts a list of strings in place by byte order.
function sort_bytes(list)
    table.sort(list, byte_less)
    return list
end

-- The keys of a table with string keys, sorted by byte order. Counted with pairs, never with #.
function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    return sort_bytes(keys)
end

-- The number of entries of a table with arbitrary keys. Lua has no len for a map.
function count_entries(map)
    local n = 0
    for _ in pairs(map) do
        n = n + 1
    end
    return n
end

-- The whole file, bytes as they are. Raises when the file cannot be read.
function read_file(path)
    local handle, err = io.open(path, "rb")
    if not handle then
        raise("cannot read " .. path .. ": " .. tostring(err))
    end
    local text = handle:read("a")
    handle:close()
    return text
end

-- The whole file as Python's text mode reads it: "\r\n" and a lone "\r" both become "\n".
function read_text(path)
    local text = read_file(path)
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    return text
end

-- The lines of a file in Python's text mode, without their line ends, as Python's read().split("\n")
-- would give them: a file ending in "\n" has no empty last element, and an empty file has none.
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

-- Writes text to a file, replacing it. Raises when the file cannot be written.
function write_file(path, text)
    local handle, err = io.open(path, "wb")
    if not handle then
        raise("cannot write " .. path .. ": " .. tostring(err))
    end
    handle:write(text)
    handle:close()
end

-- Python's sys.exit("message"): the message on stderr and exit status 1.
function fail(message)
    io.stderr:write(message, "\n")
    os.exit(1)
end

-- os.path.join(a, b) for a relative b: a and b with one "/" between them.
function join_path(a, b)
    if string.sub(a, -1) == "/" then
        return a .. b
    end
    return a .. "/" .. b
end

-- The *.h files directly in dir, as glob.glob(os.path.join(dir, "*.h")) finds them: names that start with
-- a dot are left out, as glob leaves them out, and the paths are sorted by byte order. A directory that is
-- not there has none.
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

-- The text of the *.h files in dir, each read as Python's text mode reads it, joined with "\n", which is
-- "\n".join(open(f).read() for f in sorted(glob.glob(os.path.join(dir, "*.h")))). Raises when a file
-- cannot be read.
function header_text(dir)
    local texts = {}
    for _, path in ipairs(header_paths(dir)) do
        texts[#texts + 1] = read_text(path)
    end
    return table.concat(texts, "\n")
end

-- Python's repr() of a str, which the %r in the messages prints. Quotes are single unless the text has a
-- single quote and no double quote; backslash, the quote, tab, LF, CR and the other control bytes are
-- escaped. Bytes of 0x80 and up are kept as they are, which is what Python prints for printable UTF-8.
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
