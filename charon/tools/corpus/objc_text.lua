-- Text matchers for Objective-C sources: the regular expressions verify.lua and crash-demand.lua apply
-- to the tree, each written out as a literal search (string.find, plain) and a local scan around it.
-- Lua patterns have no alternation, no \b and no bounded lazy repeat, and a multi-megabyte tree is read
-- once per list, so each function here names the expression it replaces in its comment and checks the
-- same characters. Every position is a 1-based index into the text.

-- \w: a letter, a digit or an underscore. \s: the ASCII white space characters.
local function is_word(c)
    return c ~= "" and c:match("^[%w_]$") ~= nil
end

local function is_space(c)
    return c == " " or c == "\t" or c == "\n" or c == "\r" or c == "\f" or c == "\v"
end

-- The first index at or after i that is not white space.
local function skip_forward(text, i)
    while i <= #text and is_space(text:sub(i, i)) do
        i = i + 1
    end
    return i
end

-- The last index at or before i that is not white space (0 when there is none).
local function skip_back(text, i)
    while i >= 1 and is_space(text:sub(i, i)) do
        i = i - 1
    end
    return i
end

-- \b between index p-1 and index p.
local function boundary(text, p)
    return is_word(text:sub(p - 1, p - 1)) ~= is_word(text:sub(p, p))
end

-- Whether `word` occurs in text[from..to] with a word boundary on both sides: \bWORD\b. The search is
-- over the segment alone, so a directive near the top of a 16 MB tree does not scan to the next match.
-- The boundary still reads the characters on either side of the segment.
function whole_word(text, word, from, to)
    from, to = from or 1, to or #text
    local segment = text:sub(from, to)
    local at = 1
    while word ~= "" do
        local p = segment:find(word, at, true)
        if not p then
            return false
        end
        local s = from + p - 1
        local e = s + #word - 1
        if boundary(text, s) and boundary(text, e + 1) then
            return true
        end
        at = p + 1
    end
    return false
end

-- Whether `[-+]\s*\([^)]*\)\s*` ends right before index `at`: a method's return type in parentheses,
-- preceded by its - or + sign. Every "(" that can open the parentheses is tried, since [^)]* may hold one.
local function declared_before(body, at)
    local close = skip_back(body, at - 1)
    if body:sub(close, close) ~= ")" then
        return false
    end
    for i = close - 1, 1, -1 do
        local c = body:sub(i, i)
        if c == ")" then
            return false
        end
        if c == "(" then
            local k = skip_back(body, i - 1)
            local sign = body:sub(k, k)
            if sign == "-" or sign == "+" then
                return true
            end
        end
    end
    return false
end

-- Whether the text after index `after` ends a declaration: \s*(?:\{|;|$), multiline. `$` also holds
-- before a line break inside the white space, because \s* gives that break back.
local function ends_declaration(body, after)
    local j = skip_forward(body, after)
    local c = body:sub(j, j)
    if c == "{" or c == ";" or c == "" then
        return true
    end
    return body:sub(after, j - 1):find("\n", 1, true) ~= nil
end

-- `[-+]\s*\([^)]*\)\s*SEL\s*(?:\{|;|$)`: the method SEL is declared or defined in the text.
function declares(body, sel)
    local from = 1
    while true do
        local at = body:find(sel, from, true)
        if not at then
            return false
        end
        if declared_before(body, at) and ends_declaration(body, at + #sel) then
            return true
        end
        from = at + 1
    end
end

-- `[-+]\s*\([^)]*\)\s*PREFIX\s*:`: a setter (or any keyword method) whose first keyword is PREFIX.
function declares_keyword(body, prefix)
    local from = 1
    while true do
        local at = body:find(prefix, from, true)
        if not at then
            return false
        end
        if declared_before(body, at) then
            local colon = skip_forward(body, at + #prefix)
            if body:sub(colon, colon) == ":" then
                return true
            end
        end
        from = at + 1
    end
end

-- `[-+]\s*\([^)]*\)\s*P1\s*:` then `[^;{]{0,300}?\bPi\s*:` for each further part, in order: a method
-- whose keywords are the parts of a selector with colons.
local function chain_from(body, start, parts, index)
    if index > #parts then
        return true
    end
    local word = parts[index]
    local last = math.min(start + 300, #body + 1)
    for p = start, last do
        if p > start then
            local c = body:sub(p - 1, p - 1)
            if c == ";" or c == "{" then
                break
            end
        end
        if body:sub(p, p + #word - 1) == word and boundary(body, p) then
            local colon = skip_forward(body, p + #word)
            if body:sub(colon, colon) == ":" and chain_from(body, colon + 1, parts, index + 1) then
                return true
            end
        end
    end
    return false
end

function declares_selector(body, parts)
    local from = 1
    while true do
        local at = body:find(parts[1], from, true)
        if not at then
            return false
        end
        if declared_before(body, at) then
            local colon = skip_forward(body, at + #parts[1])
            if body:sub(colon, colon) == ":" and chain_from(body, colon + 1, parts, 2) then
                return true
            end
        end
        from = at + 1
    end
end

-- `KEYWORD\b[^;\n]*\bSEL\b`: a property directive such as @dynamic or @synthesize that names SEL before
-- the statement ends. Evidence of an implementation or of its absence, depending on the keyword.
function directive_names(body, keyword, sel)
    local from = 1
    while true do
        local at = body:find(keyword, from, true)
        if not at then
            return false
        end
        local after = at + #keyword
        if not is_word(body:sub(after, after)) then
            local stop = body:find("[;\n]", after) or (#body + 1)
            if whole_word(body, sel, after, stop - 1) then
                return true
            end
        end
        from = at + 1
    end
end

-- The bodies of every @implementation, keyed by class name, as
-- `@implementation\s+(\w+)([^\n]*)\n(.*?)(?=^@end)` reads them: the body runs from the line after the
-- @implementation line up to the start of the next line that begins with @end. Categories share the key.
function implementations(text)
    local out = {}
    local pos = 1
    while true do
        local s = text:find("@implementation", pos, true)
        if not s then
            return out
        end
        local name, after = text:match("^@implementation%s+([%w_]+)()", s)
        local newline = name and text:find("\n", after, true)
        local found = false
        if newline then
            local bodystart = newline + 1
            -- endpos is where the next search resumes (the @end line); bodyend is the body's last index
            local endpos, bodyend
            if text:sub(bodystart, bodystart + 3) == "@end" then
                endpos, bodyend = bodystart, bodystart - 1
            else
                local lineend = text:find("\n@end", newline, true)
                if lineend then
                    endpos, bodyend = lineend + 1, lineend   -- the body keeps the line break before @end
                end
            end
            if endpos then
                out[name] = out[name] or {}
                table.insert(out[name], text:sub(bodystart, bodyend))
                pos = endpos
                found = true
            end
        end
        if not found then
            pos = s + 1
        end
    end
end

-- `^[A-Za-z_][\w \t\*]*\bSEL\s*(=|\()`, multiline: SEL is declared or defined as a C name, one line
-- starting with a type.
function c_declares(text, sel)
    local at = 1
    while true do
        local p = text:find(sel, at, true)
        if not p then
            return false
        end
        local line = p
        while line > 1 and text:sub(line - 1, line - 1) ~= "\n" do
            line = line - 1
        end
        local prefix = text:sub(line, p - 1)
        if prefix:match("^[A-Za-z_][%w _\t*]*$") and not is_word(text:sub(p - 1, p - 1)) then
            local after = skip_forward(text, p + #sel)
            local c = text:sub(after, after)
            if c == "=" or c == "(" then
                return true
            end
        end
        at = p + 1
    end
end
