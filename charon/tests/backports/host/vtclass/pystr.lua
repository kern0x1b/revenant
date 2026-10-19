-- pystr.lua - the character rules and str helpers the vtclass ports of members.py, availability.py,
-- emit-registry.py and check-registered.py share, with Python 3's meanings for ASCII input.
--
-- Python's \s, str.strip() and str.split() treat as whitespace the bytes 9-13 (\t \n \v \f \r), 28-31
-- (\x1c-\x1f) and 32 (space). \w is [A-Za-z0-9_]. Lua's byte view matches Python's str view for every
-- byte below 128; bytes 128 and above are neither whitespace nor word characters here, which differs
-- from Python's Unicode rules. The vtclass inputs are ASCII (checked for the SDK and the repository).
--
-- Positions are Lua's 1-based byte indices unless a name says otherwise. A nil byte (past the end) is
-- neither space nor word, which is how a Python lookahead past the end of a string behaves.
--
-- string.byte(text, 0) returns the FIRST byte in Lua 5.4 (a zero index is read as 1), so a byte before
-- the start must go through byte_at, which returns nil for any index below 1.

-- The byte at index i, or nil when i is below 1 or past the end.
function byte_at(text, i)
    if i < 1 then
        return nil
    end
    return string.byte(text, i)
end

-- True for Python's whitespace bytes. b may be nil.
function is_space(b)
    return b ~= nil and ((b >= 9 and b <= 13) or (b >= 28 and b <= 32))
end

-- True for [A-Za-z0-9_]. b may be nil.
function is_word(b)
    return b ~= nil and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

-- True for [0-9]. b may be nil.
function is_digit(b)
    return b ~= nil and b >= 48 and b <= 57
end

-- True for [A-Z_]. b may be nil.
function is_upper_or_underscore(b)
    return b ~= nil and ((b >= 65 and b <= 90) or b == 95)
end

-- True for [A-Z_0-9]. b may be nil.
function is_upper_digit_or_underscore(b)
    return is_upper_or_underscore(b) or is_digit(b)
end

-- The first index at or after i holding a non-whitespace byte (or past the end): Python's \s* taken
-- greedily, which is the only way it can be followed by a non-space in the patterns used here.
function skip_space(text, i)
    while is_space(string.byte(text, i)) do
        i = i + 1
    end
    return i
end

-- The first index at or after i holding a non-word byte (or past the end): the end of a maximal \w+.
function skip_word(text, i)
    while is_word(string.byte(text, i)) do
        i = i + 1
    end
    return i
end

-- Python's str.split("\n") with an explicit separator: "" gives {""}, and "a\n" gives {"a", ""}.
function split_on(text, sep)
    local out = {}
    local start = 1
    while true do
        local stop = string.find(text, sep, start, true)
        if not stop then
            out[#out + 1] = string.sub(text, start)
            return out
        end
        out[#out + 1] = string.sub(text, start, stop - 1)
        start = stop + #sep
    end
end

-- Python's str.split("\n").
function split_newlines(text)
    return split_on(text, "\n")
end

-- Python's str.strip(): the whitespace at both ends removed.
function strip(text)
    local first = 1
    while first <= #text and is_space(string.byte(text, first)) do
        first = first + 1
    end
    local last = #text
    while last >= first and is_space(string.byte(text, last)) do
        last = last - 1
    end
    return string.sub(text, first, last)
end

-- Python's " ".join(text.split()): every run of whitespace becomes one space, and the ends are dropped.
function collapse(text)
    local out = {}
    local i = 1
    local n = #text
    while i <= n do
        if is_space(string.byte(text, i)) then
            i = skip_space(text, i)
        else
            local j = i
            while j <= n and not is_space(string.byte(text, j)) do
                j = j + 1
            end
            out[#out + 1] = string.sub(text, i, j - 1)
            i = j
        end
    end
    return table.concat(out, " ")
end

-- Python's s.startswith(prefix).
function starts_with(text, prefix)
    return string.sub(text, 1, #prefix) == prefix
end

-- Python's s.endswith(suffix).
function ends_with(text, suffix)
    return suffix == "" or string.sub(text, -#suffix) == suffix
end

-- Python's `needle in text`, for a plain needle.
function contains(text, needle)
    return string.find(text, needle, 1, true) ~= nil
end

-- Python's re.match(r'^\w+$', text) on a string without a newline: every byte a word byte, at least one.
function is_word_string(text)
    if text == "" then
        return false
    end
    return skip_word(text, 1) == #text + 1
end

-- The text after the last occurrence of sep, or the whole text when sep does not occur: the last item
-- of Python's text.split(sep).
function last_piece(text, sep)
    local start = 1
    local last = nil
    while true do
        local stop = string.find(text, sep, start, true)
        if not stop then
            break
        end
        last = stop
        start = stop + #sep
    end
    if last == nil then
        return text
    end
    return string.sub(text, last + #sep)
end

-- os.path.normpath(os.path.abspath(path)) for a path: made absolute from $PWD when relative, and with
-- "." and ".." components resolved lexically, as Python's abspath does.
function normpath(path)
    if string.sub(path, 1, 1) ~= "/" then
        path = (os.getenv("PWD") or ".") .. "/" .. path
    end
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        if part == ".." then
            parts[#parts] = nil
        elseif part ~= "." then
            parts[#parts + 1] = part
        end
    end
    return "/" .. table.concat(parts, "/")
end

-- The basename of a path, as os.path.basename: everything after the last "/".
function basename(path)
    return string.match(path, "([^/]*)$")
end

-- The number of "\n" bytes in text.
function count_newlines(text)
    local n = 0
    local start = 1
    while true do
        local stop = string.find(text, "\n", start, true)
        if not stop then
            return n
        end
        n = n + 1
        start = stop + 1
    end
end
