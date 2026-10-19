-- `functions`: the C-function snapshot of each framework, spec/<F>/functions.tsv: one row per function the surface lists as missing at
-- 6.1.3, read from the iOS view of the framework's headers (the port of cmd_functions in tools/gen.py@52253c0650). A function no header of the
-- framework declares, or whose declaration does not read as a C function, is a row with its reason. --all: every surface framework.
-- Returns 0.
--
-- The oracle's regular expressions are written out here by hand: Lua patterns have no alternation, lookahead or lookbehind. Each
-- matcher names the pattern it is, and the offsets of the statement readers are the oracle's (0-based), so the two read the same text.
-- The proof is the committed snapshots (32 frameworks, cmp), run through the same command.

local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})
local surface = import("surface", {anonymous = true})
local emit = import("emit", {anonymous = true})
local tbd = import("tbd", {anonymous = true})
local sdk_modules = import("sdk_modules", {anonymous = true})
local sdk_info = import("sdk", {anonymous = true})
local snapshot_pins = import("snapshot_pins", {anonymous = true})
local targets = import("targets", {anonymous = true})
local headers = import("headers", {anonymous = true})

local FUNCTION_COLUMNS = {"api", "introduced", "status", "reasons", "returns", "params", "decl"}
local C_BASE_WORDS = {void = true, char = true, short = true, int = true, long = true, float = true, double = true, signed = true,
                      unsigned = true, bool = true, _Bool = true, const = true, volatile = true, struct = true, enum = true,
                      union = true, id = true, SEL = true, Class = true, BOOL = true, IMP = true, CGFloat = true, NSInteger = true,
                      NSUInteger = true, size_t = true, instancetype = true}
-- The platform values of the TARGET_OS_ macros an #if can name, as the iOS build sees them (gen.py@52253c0650 PLATFORM_VALUES).
local PLATFORM_VALUES = {TARGET_OS_IPHONE = 1, TARGET_OS_IOS = 1, TARGET_OS_EMBEDDED = 1, TARGET_OS_MAC = 0, TARGET_OS_OSX = 0,
                         TARGET_OS_VISION = 0, TARGET_OS_WATCH = 0, TARGET_OS_TV = 0, TARGET_OS_SIMULATOR = 0,
                         TARGET_OS_MACCATALYST = 0, TARGET_OS_DRIVERKIT = 0, TARGET_OS_BRIDGE = 0, TARGET_OS_UIKITFORMAC = 0,
                         TARGET_IPHONE_SIMULATOR = 0}
-- The nullability and platform words the declaration drops (strip_nullability).
local NULLABILITY = {_Nullable = true, _Nonnull = true, __nullable = true, __nonnull = true, _Null_unspecified = true,
                     nullable = true, nonnull = true, null_resettable = true, null_unspecified = true}
local AVAIL_WORDS = {"AVAILABLE", "DEPRECATED", "OBSOLETED"}
local PREFIXES = {"API", "NS", "OS", "CF", "__"}

-- Whether byte i of text is a word character (\w).
local function is_word_at(text, i)
    return i >= 1 and i <= #text and string.find(string.sub(text, i, i), "^[%w_]$") ~= nil
end

-- Whether byte i starts a word: a word character after a non-word one (\b before it).
local function is_word_start(text, i)
    return is_word_at(text, i) and not is_word_at(text, i - 1)
end

-- The last byte (1-based) of the word run that starts at i.
local function run_end(text, i)
    local _, last = string.find(text, "^[%w_]*", i)
    return last
end

-- The first byte (1-based) after the whitespace that starts at i.
local function skip_space(text, i)
    local _, last = string.find(text, "^%s*", i)
    return last + 1
end

-- The 1-based index of the ")" that closes the "(" at open, for \((?:[^()]|\([^()]*\))*\): one level of inner parentheses, no
-- deeper. nil when the group does not close that way.
local function group_end(text, open)
    local i = open + 1
    while true do
        local c = string.sub(text, i, i)
        if c == ")" then
            return i
        end
        if c == "" then
            return nil
        end
        if c == "(" then
            local close = string.find(text, "[()]", i + 1)
            if close == nil or string.sub(text, close, close) ~= ")" then
                return nil
            end
            i = close + 1
        else
            i = i + 1
        end
    end
end

-- re.sub with a matcher: match(text, i) returns the last byte of a match that starts at i, or nil. Each match is replaced by rep;
-- returns the text and the matched texts (the oracle's findall).
local function substitute(text, match, rep)
    local out, found = {}, {}
    local pos, i = 1, 1
    while i <= #text do
        local stop = match(text, i)
        if stop then
            table.insert(out, string.sub(text, pos, i - 1))
            table.insert(out, rep)
            table.insert(found, string.sub(text, i, stop))
            pos = stop + 1
            i = stop + 1
        else
            i = i + 1
        end
    end
    table.insert(out, string.sub(text, pos))
    return table.concat(out), found
end

-- AVAILABLE, DEPRECATED or OBSOLETED inside a word, then a parenthesised argument: \b\w*(?:AVAILABLE|DEPRECATED|OBSOLETED)\w*\s*\(...\)
local function availability_match(text, i)
    if not is_word_start(text, i) then
        return nil
    end
    local last = run_end(text, i)
    local word = string.sub(text, i, last)
    local keyword = false
    for _, k in ipairs(AVAIL_WORDS) do
        if string.find(word, k, 1, true) then
            keyword = true
        end
    end
    if not keyword then
        return nil
    end
    local open = skip_space(text, last + 1)
    if string.sub(text, open, open) ~= "(" then
        return nil
    end
    return group_end(text, open)
end

-- A prefixed macro call: \b(?:API|NS|OS|CF|__)_?[A-Z][A-Z0-9_]*\s*\(...\)
local function prefixed_call_match(text, i)
    if not is_word_start(text, i) then
        return nil
    end
    for _, prefix in ipairs(PREFIXES) do
        if string.sub(text, i, i + #prefix - 1) == prefix then
            local k = i + #prefix
            if string.sub(text, k, k) == "_" then
                k = k + 1
            end
            if string.find(string.sub(text, k, k), "^%u$") then
                local _, last = string.find(text, "^[%u%d_]*", k + 1)
                local open = skip_space(text, last + 1)
                if string.sub(text, open, open) == "(" then
                    return group_end(text, open)
                end
            end
            return nil
        end
    end
    return nil
end

-- A whole macro word: \b(?:API|NS|OS|CF)_[A-Z][A-Z0-9_]*\b or \b__[A-Z][A-Z0-9_]*\b
local function macro_word_match(text, i)
    if not is_word_start(text, i) then
        return nil
    end
    local last = run_end(text, i)
    local word = string.sub(text, i, last)
    for _, prefix in ipairs({"API_", "NS_", "OS_", "CF_", "__"}) do
        if string.sub(word, 1, #prefix) == prefix and string.find(string.sub(word, #prefix + 1), "^%u[%u%d_]*$") then
            return last
        end
    end
    return nil
end

-- __attribute__((...)): \b__attribute__\s*\(\((?:[^()]|\([^()]*\))*\)\)
local function attribute_match(text, i)
    if not is_word_start(text, i) or string.sub(text, i, i + 12) ~= "__attribute__" then
        return nil
    end
    local open = skip_space(text, i + 13)
    if string.sub(text, open, open + 1) ~= "((" then
        return nil
    end
    local close = group_end(text, open + 1)
    if close == nil or string.sub(text, close + 1, close + 1) ~= ")" then
        return nil
    end
    return close + 1
end

-- An NS_ macro word with an optional argument: \bNS_[A-Z_]+\b(?:\s*\(...\))?
local function ns_macro_match(text, i)
    if not is_word_start(text, i) or string.sub(text, i, i + 2) ~= "NS_" then
        return nil
    end
    local last = run_end(text, i)
    if not string.find(string.sub(text, i + 3, last), "^[%u_]+$") then
        return nil
    end
    local open = skip_space(text, last + 1)
    if string.sub(text, open, open) == "(" then
        local close = group_end(text, open)
        if close then
            return close
        end
    end
    return last
end

-- A __ macro with an optional argument right after it, no space: \b__[A-Z][A-Z0-9_]*(?:\([^()]*\))?, no \b at its end.
local function platform_macro_match(text, i)
    if not is_word_start(text, i) or string.sub(text, i, i + 2) ~= "__" or not string.find(string.sub(text, i + 2, i + 2), "^%u$") then
        return nil
    end
    local _, last = string.find(text, "^[%u%d_]*", i + 3)
    if string.sub(text, last + 1, last + 1) == "(" then
        local close = string.find(text, "[()]", last + 2)
        if close and string.sub(text, close, close) == ")" then
            return close
        end
    end
    return last
end

-- The declaration's availability macros: the text without them, and the availability text they carried (strip_macros).
local function strip_macros(text)
    local avail
    text, avail = substitute(text, availability_match, " ")
    text = substitute(text, prefixed_call_match, " ")
    text = substitute(text, macro_word_match, " ")
    text = substitute(text, attribute_match, " ")
    text = substitute(text, ns_macro_match, " ")
    return (string.gsub(string.gsub(text, "%s+", " "), "^ ", "")):gsub(" $", ""), table.concat(avail, " ")
end

-- The declaration without its nullability words and platform macros (strip_nullability).
local function strip_nullability(decl)
    local text = string.gsub(decl, "[%w_]+", function(word)
        if NULLABILITY[word] then
            return " "
        end
    end)
    text = substitute(text, platform_macro_match, " ")
    return (string.gsub(string.gsub(text, "%s+", " "), "^ ", "")):gsub(" $", "")
end

-- The linkage words a framework puts before a function (CT_EXPORT, CF_EXTERN, extern, static, inline) are not part of its type.
local LINKAGE_SUFFIXES = {"_EXPORT", "_EXTERN", "_EXPORTED", "_INLINE"}
local function strip_linkage(text)
    local out = string.gsub(text, "[%w_]+", function(word)
        if word == "extern" or word == "static" or word == "inline" then
            return " "
        end
        for _, suffix in ipairs(LINKAGE_SUFFIXES) do
            if #word > #suffix and string.sub(word, -#suffix) == suffix and string.find(string.sub(word, 1, -#suffix - 1), "^%u[%u%d]*$") then
                return " "
            end
        end
    end)
    return (string.gsub(string.gsub(out, "%s+", " "), "^ ", "")):gsub(" $", "")
end

-- The text with its comments taken out. Each comment is one "//" to the end of its line, or one "/*" to the next "*/": the
-- replacement of each is filler(comment).
local function strip_comments(text, filler)
    local out, pos = {}, 1
    while true do
        local line = string.find(text, "//", pos, true)
        local block = string.find(text, "/*", pos, true)
        local start = line
        if block and (start == nil or block < start) then
            start = block
        end
        if start == nil then
            break
        end
        local stop
        if start == line then
            stop = (string.find(text, "\n", start, true) or (#text + 1)) - 1
        else
            local close = string.find(text, "*/", start + 2, true)
            stop = close and close + 1
        end
        if stop then
            table.insert(out, string.sub(text, pos, start - 1))
            table.insert(out, filler(string.sub(text, start, stop)))
            pos = stop + 1
        else
            table.insert(out, string.sub(text, pos, start + 1))
            pos = start + 2
        end
    end
    table.insert(out, string.sub(text, pos))
    return table.concat(out)
end

-- The lines of a text as Python's split("\n") gives them: a final line feed leaves an empty last line.
local function split_lines(text)
    local out, pos = {}, 1
    while true do
        local newline = string.find(text, "\n", pos, true)
        if newline == nil then
            table.insert(out, string.sub(text, pos))
            return out
        end
        table.insert(out, string.sub(text, pos, newline - 1))
        pos = newline + 1
    end
end

-- Runs f: returns true and its value, or false when it raises (the xmake sandbox has no pcall: try and catch).
local function guarded(f)
    local ok, value = true, nil
    try {
        function()
            value = f()
        end,
        catch {
            function()
                ok = false
            end
        }
    }
    return ok, value
end

-- The end of a defined(NAME) at i (the oracle's \bdefined\s*\(\s*(\w+)\s*\)), or nil.
local function defined_end(text, i)
    if not is_word_start(text, i) then
        return nil
    end
    local _, stop = string.find(text, "^defined%s*%(%s*[%w_]+%s*%)", i)
    return stop
end

-- The Python expression of an #if condition over the TARGET_OS_ values (gen.py@52253c0650 platform_value up to eval): defined(NAME) is 1 for a
-- platform name, every other name is its value. nil when the condition names anything else or has a character Python would not read here.
local function platform_value_of(expr)
    for name in string.gmatch(expr, "defined%s*%(%s*([%w_]+)%s*%)") do
        if PLATFORM_VALUES[name] == nil then
            return nil
        end
    end
    local rest = substitute(expr, defined_end, " ")
    for name in string.gmatch(rest, "[%a_][%w_]*") do
        if PLATFORM_VALUES[name] == nil then
            return nil
        end
    end
    local py = substitute(expr, defined_end, " 1 ")
    py = string.gsub(py, "[%a_][%w_]*", function(name)
        if PLATFORM_VALUES[name] ~= nil then
            return tostring(PLATFORM_VALUES[name])
        end
    end)
    py = string.gsub(string.gsub(py, "&&", " and "), "||", " or ")
    py = string.gsub(py, "!(=?)", function(eq)
        if eq == "=" then
            return nil
        end
        return " not "
    end)
    if string.find(py, "[^%d%s()a-z=!<>]") then
        return nil
    end
    return py
end

-- Evaluates the Python expression platform_value_of makes (integers, comparisons, not, and, or, parentheses) the way Python does:
-- true or false, or nil where Python would raise (a syntax error).
local function evaluate(py)
    local tokens = {}
    local i = 1
    while i <= #py do
        local c = string.sub(py, i, i)
        local two = string.sub(py, i, i + 1)
        if string.find(c, "%s") then
            i = i + 1
        elseif string.find(c, "%d") then
            local digits = string.match(py, "^%d+", i)
            table.insert(tokens, {kind = "int", value = tonumber(digits)})
            i = i + #digits
        elseif string.find(c, "%a") then
            local word = string.match(py, "^%a+", i)
            if word ~= "and" and word ~= "or" and word ~= "not" then
                return nil
            end
            table.insert(tokens, {kind = word})
            i = i + #word
        elseif c == "(" or c == ")" then
            table.insert(tokens, {kind = c})
            i = i + 1
        elseif two == "==" or two == "!=" or two == "<=" or two == ">=" then
            table.insert(tokens, {kind = "cmp", op = two})
            i = i + 2
        elseif c == "<" or c == ">" then
            table.insert(tokens, {kind = "cmp", op = c})
            i = i + 1
        else
            return nil
        end
    end
    local pos = 1
    local parse_or
    local function peek()
        return tokens[pos]
    end
    -- an operand: an integer, or a parenthesised condition (a truth value, 1 or 0, as Python compares it)
    local function atom()
        local token = peek()
        if token == nil then
            error("syntax")
        end
        if token.kind == "int" then
            pos = pos + 1
            return token.value
        end
        if token.kind == "(" then
            pos = pos + 1
            local value = parse_or()
            if peek() == nil or peek().kind ~= ")" then
                error("syntax")
            end
            pos = pos + 1
            return value and 1 or 0
        end
        error("syntax")
    end
    -- a comparison chain (a < b < c is a < b and b < c); a single operand is its truth value
    local function comparison()
        local left = atom()
        if not (peek() and peek().kind == "cmp") then
            return left ~= 0
        end
        local result = true
        while peek() and peek().kind == "cmp" do
            local op = peek().op
            pos = pos + 1
            local right = atom()
            local holds
            if op == "==" then holds = left == right
            elseif op == "!=" then holds = left ~= right
            elseif op == "<" then holds = left < right
            elseif op == ">" then holds = left > right
            elseif op == "<=" then holds = left <= right
            else holds = left >= right end
            result = result and holds
            left = right
        end
        return result
    end
    local function negation()
        if peek() and peek().kind == "not" then
            pos = pos + 1
            return not negation()
        end
        return comparison()
    end
    local function conjunction()
        local value = negation()
        while peek() and peek().kind == "and" do
            pos = pos + 1
            local other = negation()
            value = value and other
        end
        return value
    end
    parse_or = function()
        local value = conjunction()
        while peek() and peek().kind == "or" do
            pos = pos + 1
            local other = conjunction()
            value = value or other
        end
        return value
    end
    local ok, value = guarded(function()
        local result = parse_or()
        if pos <= #tokens then
            error("syntax")
        end
        return result
    end)
    if not ok then
        return nil
    end
    return value
end

-- The value of an #if expression for iOS: true or false, or nil when the condition is not decided (gen.py@52253c0650 platform_value).
local function platform_value(expr)
    local py = platform_value_of(expr)
    if py == nil then
        return nil
    end
    return evaluate(py)
end

-- The header text as the iOS build reads it: each #if over TARGET_OS_ values keeps the branch that holds for iOS and drops the rest; a
-- condition this cannot decide keeps every branch. Returns the text and the count of undecided conditions (gen.py@52253c0650 ios_text).
local function ios_text(text)
    local out, stack, undecided = {}, {}, 0
    local function active()
        for _, frame in ipairs(stack) do
            if not frame.active then
                return false
            end
        end
        return true
    end
    text = strip_comments(text, function(comment)
        return (string.gsub(comment, "[^\n]", " "))
    end)
    for _, line in ipairs(split_lines(text)) do
        local stripped = string.gsub(string.gsub(line, "^%s+", ""), "%s+$", "")
        local found = false
        local directive, rest
        if string.sub(stripped, 1, 1) == "#" then
            local start = skip_space(stripped, 2)
            local word = string.match(stripped, "^[%w_]*", start)
            for _, keyword in ipairs({"if", "ifdef", "ifndef", "elif", "else", "endif"}) do
                if word == keyword then
                    found = true
                    directive = keyword
                    rest = string.sub(stripped, skip_space(stripped, start + #word))
                end
            end
        end
        if not found then
            if active() then
                table.insert(out, line)
            end
        else
            local parent = active()
            if directive == "if" or directive == "ifdef" or directive == "ifndef" then
                local expr = rest
                if directive == "ifdef" then
                    expr = "defined(" .. (string.gsub(rest, "^%s+", ""):gsub("%s+$", "")) .. ")"
                elseif directive == "ifndef" then
                    expr = "!defined(" .. (string.gsub(rest, "^%s+", ""):gsub("%s+$", "")) .. ")"
                end
                local value = platform_value(expr)
                if value == nil then
                    undecided = undecided + 1
                    table.insert(stack, {parent = parent, known = false, taken = false, active = parent})
                else
                    table.insert(stack, {parent = parent, known = true, taken = value, active = parent and value})
                end
            elseif directive == "elif" then
                local frame = stack[#stack]
                if frame.known then
                    local value = false
                    if not frame.taken then
                        value = platform_value(rest)
                    end
                    if value == nil then
                        undecided = undecided + 1
                        frame.known = false
                        frame.active = frame.parent
                    else
                        frame.active = frame.parent and value and not frame.taken
                        frame.taken = frame.taken or value
                    end
                else
                    frame.active = frame.parent
                end
            elseif directive == "else" then
                local frame = stack[#stack]
                if frame.known then
                    frame.active = frame.parent and not frame.taken
                else
                    frame.active = frame.parent
                end
            elseif directive == "endif" and #stack > 0 then
                table.remove(stack)
            end
        end
    end
    return table.concat(out, "\n"), undecided
end

-- The statement text of a declaration match: preprocessor lines (with the blank lines before them) become one space each (the
-- oracle's re.sub "(?m)^\s*#.*$").
local function without_directive_lines(text)
    return substitute(text, function(s, i)
        if i ~= 1 and string.sub(s, i - 1, i - 1) ~= "\n" then
            return nil
        end
        local start = skip_space(s, i)
        if string.sub(s, start, start) ~= "#" then
            return nil
        end
        local newline = string.find(s, "\n", start, true)
        return newline and newline - 1 or #s
    end, " ")
end

-- The statements that call name at their top level, as gen.py@52253c0650 c_statements: from the ; or } or @end before the name to the ; or { that
-- ends it. Offsets are the oracle's: 0-based, so the reads below follow its arithmetic. A name on a preprocessor line is no declaration.
local function c_statements(text, name)
    local out = {}
    local n = #text
    local function at(k)
        return string.sub(text, k + 1, k + 1)
    end
    local pos = 1
    while true do
        local s = string.find(text, name, pos, true)
        if s == nil then
            break
        end
        pos = s + #name
        local before = string.sub(text, s - 1, s - 1)
        local open = skip_space(text, s + #name)
        if (before == "" or not string.find(before, "[%w_%.>]")) and string.sub(text, open, open) == "(" then
            pos = open + 1
            local ms = s - 1
            local line_start = 0
            for k = ms - 1, 0, -1 do
                if at(k) == "\n" then
                    line_start = k + 1
                    break
                end
            end
            local head = string.gsub(string.sub(text, line_start + 1, ms), "^%s+", "")
            if string.sub(head, 1, 1) ~= "#" then
                local best = -1
                for k = ms - 1, 0, -1 do
                    if at(k) == ";" or at(k) == "}" then
                        best = k
                        break
                    end
                end
                local end_at = -1
                for k = ms - 4, math.max(best - 2, 0), -1 do
                    if string.sub(text, k + 1, k + 4) == "@end" then
                        end_at = k
                        break
                    end
                end
                local start = math.max(best, end_at >= 0 and end_at + 3 or 2) + 1
                local depth, e = 1, open
                while e < n and depth > 0 do
                    local c = at(e)
                    if c == "(" then
                        depth = depth + 1
                    elseif c == ")" then
                        depth = depth - 1
                    end
                    e = e + 1
                end
                while e < n and at(e) ~= ";" and at(e) ~= "{" do
                    e = e + 1
                end
                table.insert(out, (without_directive_lines(string.sub(text, start + 1, e))))
            end
        end
    end
    return out
end

-- The arguments of a parameter list, split on the commas outside parentheses (gen.py@52253c0650 split_top_level).
local function split_top_level(body)
    local out, depth, current = {}, 0, ""
    for ch in string.gmatch(body, ".") do
        if ch == "," and depth == 0 then
            table.insert(out, (string.gsub(string.gsub(current, "^%s+", ""), "%s+$", "")))
            current = ""
        else
            if ch == "(" then
                depth = depth + 1
            elseif ch == ")" then
                depth = depth - 1
            end
            current = current .. ch
        end
    end
    local last = string.gsub(string.gsub(current, "^%s+", ""), "%s+$", "")
    if last ~= "" then
        table.insert(out, last)
    end
    return out
end

-- A parameter with its name: the header's own, or p<index> where the header leaves it unnamed (gen.py@52253c0650 named_param; index from 0).
local function named_param(text, index)
    if string.find(text, "(^)", 1, true) or string.find(text, "(*)", 1, true) then
        local out = text
        local s, e = string.find(out, "(^)", 1, true)
        if s then
            out = string.sub(out, 1, s - 1) .. "(^p" .. index .. ")" .. string.sub(out, e + 1)
        end
        s, e = string.find(out, "(*)", 1, true)
        if s then
            out = string.sub(out, 1, s - 1) .. "(*p" .. index .. ")" .. string.sub(out, e + 1)
        end
        return out
    end
    local words = {}
    for word in string.gmatch(text, "[%a_][%w_]*") do
        table.insert(words, word)
    end
    local ends_star = string.sub(text, -1) == "*"
    if #words >= 2 and not ends_star and not C_BASE_WORDS[words[#words]] then
        return text
    end
    return text .. (ends_star and ("p" .. index) or (" p" .. index))
end

-- The returns, params, introduced release and declaration text of a C function declared by a statement, or nil when it does not read as
-- one (gen.py@52253c0650 c_declaration).
local function c_declaration(statement, name)
    local clean, avail = strip_macros(statement)
    clean = strip_nullability(clean)
    clean = strip_linkage(clean)
    local idx = nil
    local search = 1
    while true do
        local s = string.find(clean, name, search, true)
        if s == nil then
            break
        end
        local before = string.sub(clean, s - 1, s - 1)
        local open = skip_space(clean, s + #name)
        if (before == "" or not string.find(before, "[%w_%.>]")) and string.sub(clean, open, open) == "(" then
            idx = s
            break
        end
        search = s + 1
    end
    if idx == nil or string.sub(clean, 1, 7) == "typedef" or string.sub(clean, 1, 6) == "return" or string.sub(clean, 1, 1) == "#" then
        return nil
    end
    local returns = (string.gsub(string.gsub(string.sub(clean, 1, idx - 1), "^%s+", ""), "%s+$", ""))
    if returns == "" or string.find(returns, "=", 1, true) then
        return nil
    end
    local open = skip_space(clean, idx + #name)
    local start = open
    local depth, e = 1, open + 1
    local n = #clean
    while e <= n and depth > 0 do
        local c = string.sub(clean, e, e)
        if c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
        end
        e = e + 1
    end
    if depth > 0 then
        return nil
    end
    local body = string.gsub(string.gsub(string.sub(clean, start + 1, e - 2), "^%s+", ""), "%s+$", "")
    local raw = {}
    if body ~= "" and body ~= "void" then
        raw = split_top_level(body)
    end
    local params = {}
    for i, p in ipairs(raw) do
        table.insert(params, named_param(p, i - 1))
    end
    local introduced = "-"
    local search = 1
    while true do
        local s, last = string.find(avail, "ios(", search, true)
        if s == nil then
            break
        end
        local digits = string.match(avail, "^%d+", last + 1)
        if digits then
            local release = digits
            local at = #digits + last
            while string.sub(avail, at + 1, at + 1) == "." and string.match(avail, "^%d", at + 2) do
                local part = string.match(avail, "^%d+", at + 2)
                release = release .. "." .. part
                at = at + 1 + #part
            end
            introduced = release
            break
        end
        search = s + 1
    end
    return returns, params, introduced, string.format("%s %s(%s)", returns, name, table.concat(params, ", "))
end

-- The objc C functions the 6.1.3 ledger lists as missing (not header-ok) and no registry row names: {api, introduced}, sorted
-- (gen.py@52253c0650 function_wanted).
local function function_wanted(tree, fw, corpus, sdk_release)
    local led6 = surface.ledger_status(corpus, fw, surface.ledger_6_1_3())
    local registry = surface.registry_entries(tree, fw)
    local out = {}
    -- a function is its symbol, so an api several declarations share (C overloads of one name) is one function, listed at its first
    -- declaration and with the introduction of its last one (the surface's order, as the readers had it before one row per declaration)
    local named = {}
    for _, row in ipairs(surface.surface_rows(tree, corpus, sdk_release, fw)) do
        local k = surface.key(row.kind, row.api)
        if row.kind == "function" and row.lang == "objc" and registry[row.api] == nil and led6[k] ~= nil and led6[k] ~= "header-ok" then
            if named[row.api] then
                named[row.api].introduced = row.introduced
            else
                named[row.api] = {api = row.api, introduced = row.introduced}
                table.insert(out, named[row.api])
            end
        end
    end
    table.sort(out, function(a, b)
        if a.api ~= b.api then
            return order.less(a.api, b.api)
        end
        return order.less(a.introduced, b.introduced)
    end)
    return out
end

-- The header text of a module's 26.2 headers, in path order (gen.py@52253c0650 header_text_recursive). A framework's are every header under
-- its Headers folder (subfolders included); a usr module's are the headers its map names (sdk_modules.headers_of); a Swift module has none.
local function header_text_recursive(sdk, fw)
    local parts = {}
    local record = sdk_modules.module_of(sdk, fw)
    assert(record ~= nil, "functions: the SDK holds no module " .. fw)
    if record.kind == "usr" then
        for _, file in ipairs(sdk_modules.headers_of(sdk, fw) or {}) do
            table.insert(parts, files.read_text(file) or "")
        end
        return table.concat(parts, "\n")
    end
    local base = path.join(record.root, "Headers")
    -- "**.h": every header at any depth. ("**/*.h" in xmake misses the headers of the folder itself.)
    for _, file in ipairs(files.glob(path.join(base, "**.h"))) do
        table.insert(parts, files.read_text(file) or "")
    end
    return table.concat(parts, "\n")
end

-- The nested targets of an umbrella (no-shard.tsv names them: Accelerate's vImage and vecLib), each with the text of its own headers and
-- the functions its shard declares. The umbrella's master header includes them, but a function's declaration is read from the target
-- whose shard declares it: the umbrella's header set alone reads 217 vImage functions as declared nowhere.
local function nested_targets(tree, sdk, fw)
    local out = {}
    local umbrella = targets.umbrellas(tree)[fw]
    for _, target in ipairs(umbrella and umbrella.targets or {}) do
        table.insert(out, {text = strip_comments(ios_text(header_text_recursive(sdk, target)), function(comment)
            return " "
        end), functions = headers.shard_facts(tree, target).functions})
    end
    return out
end

-- The text a function's declaration is read from: the first nested target whose shard declares it, else the umbrella's text.
function declaring_text(nested, umbrella_text, name)
    for _, target in ipairs(nested) do
        if target.functions[name] ~= nil then
            return target.text
        end
    end
    return umbrella_text
end

-- Writes one framework's snapshot. Returns nothing; prints the summary line.
local function one(args, fw, sdk, sdk_release)
    local snap = layout.snap_dir(args.tree, fw)
    local target = path.join(snap, "functions.tsv")
    local wanted = function_wanted(args.tree, fw, args.coordination, sdk_release)
    if #wanted == 0 then
        if os.isfile(target) then
            os.rm(target)
        end
        snapshot_pins.pin_record(args.tree, fw, "functions.tsv")
        return
    end
    local ios = ios_text(header_text_recursive(sdk, fw))
    local text = strip_comments(ios, function(comment)
        return " "
    end)
    local nested = nested_targets(args.tree, sdk, fw)
    local exported = tbd.exports(sdk, fw)
    local lines = {table.concat(FUNCTION_COLUMNS, "\t")}
    local counts = {}
    for _, item in ipairs(wanted) do
        local name = item.api
        if string.sub(name, -2) == "()" then
            name = string.sub(name, 1, -3)
        end
        local introduced = item.introduced
        local statements = c_statements(declaring_text(nested, text, name), name)
        local declarations = {}
        for _, statement in ipairs(statements) do
            local returns, params, found, decl = c_declaration(statement, name)
            if returns then
                table.insert(declarations, {returns = returns, params = params, found = found, decl = decl})
            end
        end
        local status, reasons, row
        if #statements == 0 then
            status = "missing"
            if exported[name] then
                reasons = "exported by the " .. sdk_release .. " .tbd, with no declaration in the framework's headers"
            else
                reasons = "not declared in the framework's " .. sdk_release .. " headers and not exported by it"
            end
            row = {"-", "-", "-"}
        elseif #declarations == 0 then
            status = "refused"
            reasons = "the declaration does not read as a C function"
            row = {"-", "-", "-"}
        else
            local first = declarations[1]
            status = "generable"
            reasons = ""
            row = {first.returns, table.concat(first.params, "; "), first.decl}
            if first.found ~= "-" then
                introduced = first.found
            end
        end
        counts[status] = (counts[status] or 0) + 1
        local cells = {name, introduced, status, reasons}
        for _, cell in ipairs(row) do
            table.insert(cells, cell)
        end
        table.insert(lines, (string.gsub(table.concat(cells, "\t"), "\n", " ")))
    end
    emit.file(target, table.concat(lines, "\n") .. "\n")
    snapshot_pins.pin_record(args.tree, fw, "functions.tsv")
    local statuses = {}
    for status in pairs(counts) do
        table.insert(statuses, status)
    end
    table.sort(statuses, order.less)
    local parts = {}
    for _, status in ipairs(statuses) do
        table.insert(parts, string.format("%s %d", status, counts[status]))
    end
    print(string.format("functions %s: %s", fw, table.concat(parts, ", ")))
end

-- Returns the exit status: 0 (every framework is written or has nothing to write).
function run(args)
    assert(args.coordination, "functions needs --coordination: the corpus folder (the surface table and the ledgers)")
    assert(args.sdk, "functions needs --sdk: the iPhoneOS SDK the declarations are read from")
    local sdk = args.sdk
    local sdk_release = sdk_info.discover(sdk).version
    local targets = args.all and surface.surface_frameworks(args.tree, args.coordination, sdk_release) or {args.framework}
    for _, fw in ipairs(targets) do
        one(args, fw, sdk, sdk_release)
    end
    return 0
end
