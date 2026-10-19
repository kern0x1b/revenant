-- count-missing.lua <checkout> [--registry <file>...] - the census of PDFKit members the 26.2 header declares and the
-- registry has no row for, by class. Ported from count-missing.py; its docstring is the usage text below.
--
-- The Python regular expressions are written out as functions here, with their backtracking. Each function says which
-- pattern it stands for and what it captures. Byte-level only: the headers are ASCII except one U+00A9 in a comment,
-- and an invalid UTF-8 byte is dropped on read as Python's errors="ignore" drops it (see utf8_ignore).

import("core.base.json")

local DOC = [==[
Which PDFKit members the 26.2 header declares and the registry has NO row for, by class.

    count-missing.lua <checkout> [--registry <file>...]

A row is what the registry calls a member, and this is the other direction of the same question
declared-check.lua asks.  That one asks "does every row name something a header declares?" and answers
for the rows.  This one asks "does every declared member have a row?" and answers for the headers, which
is the direction that finds work: a member Apple declares and the registry never mentions is a member
the package's surface does not describe, and nothing else in the tree would notice its absence.

It is also the only honest way to size a family.  Counting inert rows measures what a previous series
already looked at; counting declarations measures what is left, and the two are different numbers.

The port's own members are excluded, on the same reasoning as declared-check.lua: -charon_CGPDFDocument
and the rest are declared in the PORT's header, and a row for one of those is the port's business rather
than a gap in the package's surface.

    the 26.2 headers: 16 @interfaces, N selectors, M properties
    PDFSelection   11 declared,  0 rows, 11 missing
    ...
    TOTAL         180 declared, 66 rows, 114 missing

Exit 0 always: this is a census, not a check, and a package with gaps is the normal state.  Exit 2 when
the SDK or the checkout is wrong, which is a fault rather than a finding.
]==]

-- The members a class never counts as declared: NSObject's own, which every class inherits (see the Python).
local INHERITED = { dealloc = true, init = true, ["copyWithZone:"] = true }

local PROBE = "System/Library/Frameworks/PDFKit.framework/Headers/PDFDocument.h"
local HEADERS_REL = "System/Library/Frameworks/PDFKit.framework/Headers"
local OWN_REL = "packages/a/apple-backports/PDFKit/CharonPDFKit.h"
local REGISTRY_REL = "packages/a/apple-backports/registry/PDFKit"

-- Byte order, as Python sorts strings: the string comparison of Lua follows the locale's collation.
local function byte_less(a, b)
    for i = 1, math.min(#a, #b) do
        local x, y = a:byte(i), b:byte(i)
        if x ~= y then
            return x < y
        end
    end
    return #a < #b
end

-- Python's \s on the bytes these headers hold: space, \t \n \v \f \r, and \x1c-\x1f (str.isspace).
local function is_space(b)
    return b ~= nil and (b == 32 or (b >= 9 and b <= 13) or (b >= 28 and b <= 31))
end

-- Python's \w, for ASCII: [A-Za-z0-9_]. A byte above 127 is neither \w nor \s here, which is what Python says of the
-- one valid non-ASCII character the headers hold, U+00A9 in a comment. A valid non-ASCII letter would differ.
local function is_word(b)
    return b ~= nil and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

-- [A-Za-z_]
local function is_alpha(b)
    return b ~= nil and ((b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

-- [A-Z]
local function is_upper(b)
    return b ~= nil and b >= 65 and b <= 90
end

-- \s* from i: the index of the first byte that is not whitespace
local function skip_space(s, i)
    while is_space(s:byte(i)) do
        i = i + 1
    end
    return i
end

-- Python's open(path, errors="ignore").read(): UTF-8 is decoded and an invalid byte is dropped, with the valid bytes a
-- malformed sequence had taken, as the decoder's "ignore" handler does (it resumes at the byte that broke the sequence).
-- A valid multi-byte sequence is kept as its bytes.
local function utf8_ignore(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local start = s:find("[\128-\255]", i)
        if not start then
            out[#out + 1] = s:sub(i)
            break
        end
        out[#out + 1] = s:sub(i, start - 1)
        i = start
        local b = s:byte(i)
        local len, lo, hi = nil, 0x80, 0xBF
        if b >= 0xC2 and b <= 0xDF then
            len = 2
        elseif b == 0xE0 then
            len, lo = 3, 0xA0
        elseif (b >= 0xE1 and b <= 0xEC) or b == 0xEE or b == 0xEF then
            len = 3
        elseif b == 0xED then
            len, hi = 3, 0x9F
        elseif b == 0xF0 then
            len, lo = 4, 0x90
        elseif b >= 0xF1 and b <= 0xF3 then
            len = 4
        elseif b == 0xF4 then
            len, hi = 4, 0x8F
        end
        local took = 1
        if len then
            while took < len do
                local c = s:byte(i + took)
                local l, h = 0x80, 0xBF
                if took == 1 then
                    l, h = lo, hi
                end
                if c == nil or c < l or c > h then
                    break
                end
                took = took + 1
            end
        end
        if len and took == len then
            out[#out + 1] = s:sub(i, i + len - 1)
        end
        i = i + took
    end
    return table.concat(out)
end

-- The text a Python text-mode read gives: invalid bytes dropped, then universal newlines (\r\n and \r become \n).
local function read_text(file)
    local handle = io.open(file, "rb")
    if not handle then
        raise("%s", "cannot read " .. file)
    end
    local bytes = handle:read("a") or ""
    handle:close()
    local text = utf8_ignore(bytes)
    text = (text:gsub("\r\n", "\n"))
    text = (text:gsub("\r", "\n"))
    return text
end

-- CLASS_BLOCK = @interface\s+(\w+)[^\n]*\n(.*?)@end, with re.S, by findall: the non-overlapping matches, leftmost first.
-- Returns { { name, body }, ... } in the order the matches are found.
local function class_blocks(s)
    local found = {}
    local p = 1
    while true do
        local a = s:find("@interface", p, true)
        if not a then
            break
        end
        local stop = nil
        local i = a + #"@interface"
        local j = skip_space(s, i)
        if j > i then
            -- \w+ is taken whole: [^\n]*\n then needs a newline somewhere after it, and backtracking the name cannot
            -- find one that the whole name did not.
            local k = j
            while is_word(s:byte(k)) do
                k = k + 1
            end
            if k > j then
                local nl = s:find("\n", k, true)
                local e = nl and s:find("@end", nl + 1, true)
                if e then
                    found[#found + 1] = { s:sub(j, k - 1), s:sub(nl + 1, e - 1) }
                    stop = e + #"@end"
                end
            end
        end
        if stop then
            p = stop
        else
            p = a + 1
        end
    end
    return found
end

-- [A-Z][A-Z0-9_]*\([^)]*\) at i: the index after its ')', or nil. The run of [A-Z0-9_] must be followed by '(' (a
-- shorter run would leave one of those bytes where '(' is wanted), and [^)]* stops at the first ')' or it cannot match.
local function macro_end(s, i)
    if not is_upper(s:byte(i)) then
        return nil
    end
    local j = i + 1
    while true do
        local b = s:byte(j)
        if b == nil or not ((b >= 65 and b <= 90) or (b >= 48 and b <= 57) or b == 95) then
            break
        end
        j = j + 1
    end
    if s:byte(j) ~= 40 then
        return nil
    end
    local close = s:find(")", j + 1, true)
    if not close then
        return nil
    end
    return close + 1
end

-- (?:MACRO\s*)*; at i: the index after the ';', or nil. The group is greedy and deterministic: a macro is taken whenever
-- one starts, and the ';' must come where the macros stop.
local function macros_then_semicolon(s, i)
    while true do
        local e = macro_end(s, i)
        if not e then
            break
        end
        i = skip_space(s, e)
    end
    if s:byte(i) == 59 then
        return i + 1
    end
    return nil
end

-- \s*(?::|(?:MACRO\s*)*;) at e, as DECL_METHOD ends an identifier: the index after what it matched, or nil.
local function method_tail(s, e)
    local i = skip_space(s, e)
    if s:byte(i) == 58 then
        return i + 1
    end
    return macros_then_semicolon(s, i)
end

-- DECL_METHOD = ^\s*[-+]\s*\([^)]*\)\s*([A-Za-z_]\w*)\s*(?::|(?:MACRO\s*)*;) matched at p, a line start. Returns the
-- selector (group 1) and the index after the match, or nil. The identifier is tried longest first, as the regex does.
local function method_at(s, p)
    local i = skip_space(s, p)
    local b = s:byte(i)
    if b ~= 45 and b ~= 43 then -- - or +
        return nil
    end
    i = skip_space(s, i + 1)
    if s:byte(i) ~= 40 then -- (
        return nil
    end
    local close = s:find(")", i + 1, true)
    if not close then
        return nil
    end
    i = skip_space(s, close + 1)
    if not is_alpha(s:byte(i)) then
        return nil
    end
    local j = i + 1
    while is_word(s:byte(j)) do
        j = j + 1
    end
    for e = j, i + 1, -1 do
        local stop = method_tail(s, e)
        if stop then
            return s:sub(i, e - 1), stop
        end
    end
    return nil
end

-- findall of DECL_METHOD over a body: every selector, in order. ^ holds at the start of the body and after each \n.
local function method_selectors(s)
    local found = {}
    local p = 1
    while p <= #s do
        local sel, stop
        if p == 1 or s:byte(p - 1) == 10 then
            sel, stop = method_at(s, p)
        end
        if sel then
            found[#found + 1] = sel
            p = stop
        else
            p = p + 1
        end
    end
    return found
end

-- The name of DECL_PROPERTY after its prefix, from r: [^;\n]*? then ([A-Za-z_]\w*) then \s*(?:MACRO\s*)*;. The prefix is
-- lazy, so the leftmost name that completes the match wins, and within a name the longest identifier that does.
-- Returns the name and the index after the match, or nil.
local function property_name(s, r)
    local t = r
    while true do
        if is_alpha(s:byte(t)) then
            local j = t + 1
            while is_word(s:byte(j)) do
                j = j + 1
            end
            for e = j, t + 1, -1 do
                local stop = macros_then_semicolon(s, skip_space(s, e))
                if stop then
                    return s:sub(t, e - 1), stop
                end
            end
        end
        local b = s:byte(t)
        if b == nil or b == 59 or b == 10 then -- the prefix cannot pass a ';' or a newline
            return nil
        end
        t = t + 1
    end
end

-- DECL_PROPERTY = @property\s*(?:\([^)]*\))?[^;\n]*?(name)\s*(?:MACRO\s*)*; matched at a, the '@'. The optional (...) is
-- taken when it can be, and the match is tried without it only when the taken one fails.
local function property_at(s, a)
    local i = skip_space(s, a + #"@property")
    if s:byte(i) == 40 then -- (
        local close = s:find(")", i + 1, true)
        if close then
            local name, stop = property_name(s, close + 1)
            if name then
                return name, stop
            end
        end
    end
    return property_name(s, i)
end

-- findall of DECL_PROPERTY over a body: the names, in order.
local function property_names(s)
    local found = {}
    local p = 1
    while true do
        local a = s:find("@property", p, true)
        if not a then
            break
        end
        local name, stop = property_at(s, a)
        if name then
            found[#found + 1] = name
            p = stop
        else
            p = a + 1
        end
    end
    return found
end

-- The lines of a body as str.splitlines() has them: \n, \v, \f and \x1c-\x1e end a line (\r was made \n on read).
local function split_lines(body)
    local lines = {}
    local text = (body:gsub("[\n\11\12\28\29\30]", "\n"))
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

-- (\w+ ... ) by findall of ([A-Za-z_]\w*)\s*: over a text: the identifiers that are followed by a colon.
local function colon_names(text)
    local parts = {}
    local p = 1
    while p <= #text do
        if is_alpha(text:byte(p)) then
            local j = p + 1
            while is_word(text:byte(j)) do
                j = j + 1
            end
            local k = skip_space(text, j)
            if text:byte(k) == 58 then
                parts[#parts + 1] = text:sub(p, j - 1)
                p = k + 1
            else
                p = p + 1
            end
        else
            p = p + 1
        end
    end
    return parts
end

-- The member one declaration line gives the selector sel, as the Python builds it, or nil when the line does not declare
-- sel. The line must be ^\s*[-+]\s*\([^)]*\)\s*SEL followed by ':' or ';' or a macro chain then ';'. The member is the
-- selector, with the colon-words after its first keyword appended with their colons when there are any.
local function line_member(line, sel)
    local i = skip_space(line, 1)
    local b = line:byte(i)
    if b ~= 45 and b ~= 43 then
        return nil
    end
    i = skip_space(line, i + 1)
    if line:byte(i) ~= 40 then
        return nil
    end
    local close = line:find(")", i + 1, true)
    if not close then
        return nil
    end
    i = skip_space(line, close + 1)
    if line:sub(i, i + #sel - 1) ~= sel then
        return nil
    end
    if not method_tail(line, i + #sel) then
        return nil
    end
    -- the first occurrence of the selector in the line, as line.split(selector, 1)[1] has it
    local at = line:find(sel, 1, true)
    local parts = {}
    if line:find(sel .. ":", 1, true) then
        parts = colon_names(line:sub(at + #sel))
    end
    local member = sel
    if #parts > 0 then
        for _, part in ipairs(parts) do
            member = member .. part .. ":"
        end
    end
    return member
end

-- census(headers): class -> the set of its members, and the class names in the order they are first met.
-- paths is sorted by the caller. Returns { order = {...}, members = { [class] = { [member] = true } } }.
local function census(paths)
    local result = { order = {}, members = {} }
    for _, path in ipairs(paths) do
        for _, block in ipairs(class_blocks(read_text(path))) do
            local name, body = block[1], block[2]
            local set = result.members[name]
            if not set then
                set = {}
                result.members[name] = set
                result.order[#result.order + 1] = name
            end
            local lines = split_lines(body)
            for _, sel in ipairs(method_selectors(body)) do
                -- a selector is a member only when some line declares it; a multi-line declaration gives none
                for _, line in ipairs(lines) do
                    local member = line_member(line, sel)
                    if member then
                        set[member] = true
                        break
                    end
                end
            end
            for _, prop in ipairs(property_names(body)) do
                set[prop] = true
            end
        end
    end
    return result
end

-- re.match(r"[-+]\[(\w+)\s+([^\]]*)\]", api): the owner and the selector text, or nil.
local function bracket_form(api)
    local b1, b2 = api:byte(1), api:byte(2)
    if (b1 ~= 45 and b1 ~= 43) or b2 ~= 91 then
        return nil
    end
    local j = 3
    while is_word(api:byte(j)) do
        j = j + 1
    end
    if j == 3 then
        return nil
    end
    local k = skip_space(api, j)
    if k == j then
        return nil
    end
    local close = api:find("]", k, true)
    if not close then
        return nil
    end
    return api:sub(3, j - 1), api:sub(k, close - 1)
end

-- Every .<suffix> file directly in dir, as glob.glob gives them, sorted by bytes. Hidden names are not matched by a
-- glob, and os.files matches case-insensitively, so both are checked here.
local function glob_files(dir, suffix)
    local out = {}
    for _, file in ipairs(os.files(path.join(dir, "*" .. suffix))) do
        local base = file:match("([^/]*)$")
        if base:sub(1, 1) ~= "." and base:sub(-#suffix) == suffix and os.isfile(file) then
            out[#out + 1] = file
        end
    end
    table.sort(out, byte_less)
    return out
end

-- os.path.dirname of an absolute path, as Python gives it.
local function dirname(p)
    local d = p:match("^(.*)/[^/]*$")
    if d == nil then
        return "."
    end
    if d == "" then
        return "/"
    end
    return d
end

-- The 26.2 SDK: the first candidate that holds the probe header. The candidates are every ancestor of this tool's own
-- directory, then $HOME/charon and $HOME/charon/.agent-work/worktrees, each with .agent-work/sdk-26.2/iPhoneOS26.2.sdk.
-- Exits 2 with the candidates named when none does.
local function find_sdk()
    local roots = {}
    local here = path.absolute(os.scriptdir())
    while true do
        roots[#roots + 1] = here
        local parent = dirname(here)
        if parent == here then
            break
        end
        here = parent
    end
    local home = os.getenv("HOME")
    if home and home ~= "" then
        roots[#roots + 1] = path.join(home, "charon")
        roots[#roots + 1] = path.join(home, "charon", ".agent-work", "worktrees")
    end
    local candidates = {}
    for _, root in ipairs(roots) do
        candidates[#candidates + 1] = path.join(root, ".agent-work", "sdk-26.2", "iPhoneOS26.2.sdk")
    end
    for _, candidate in ipairs(candidates) do
        if os.isfile(path.join(candidate, PROBE)) then
            return path.normalize(candidate)
        end
    end
    print("  the 26.2 SDK was not found.  Looked for " .. PROBE .. " under:")
    for _, candidate in ipairs(candidates) do
        print("    " .. path.normalize(candidate))
    end
    os.exit(2)
end

local function decode_json(file)
    local handle = io.open(file, "rb")
    if not handle then
        raise("%s", file .. ": cannot be read")
    end
    local text = handle:read("a") or ""
    handle:close()
    local held = json.decode(text)
    if held == nil then
        raise("%s", file .. ": is not JSON")
    end
    return held
end

-- held["entries"] for the object form; the list itself for the array form. An object without "entries" is the KeyError
-- the Python raised.
local function entries_of(held, file)
    if held.entries ~= nil then
        return held.entries
    end
    if held[1] == nil then
        local keys = 0
        for _ in pairs(held) do
            keys = keys + 1
        end
        if keys > 0 then
            raise("%s", file .. ": no 'entries' key")
        end
    end
    return held
end

local function count_keys(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

function main(...)
    local args = { ... }
    local sdk = find_sdk()
    local headers = path.join(sdk, HEADERS_REL)
    if #args < 1 then
        io.stderr:write(DOC, "\n")
        os.exit(1)
    end

    local checkout = path.absolute(args[1])
    local registry = {}
    for i = 2, #args do
        if args[i]:sub(1, 2) ~= "--" then
            registry[#registry + 1] = args[i]
        end
    end
    if #registry == 0 then
        registry = glob_files(path.join(checkout, REGISTRY_REL), ".json")
    end

    local declared = census(glob_files(headers, ".h"))
    if #declared.order == 0 then
        print("  the headers under " .. headers .. " yielded no @interface at all - the path is wrong")
        -- The Python returns 2 here, and its `if __name__ == "__main__": main()` discards the value: the exit is 0.
        return
    end

    -- The port's own members, on the Python's reasoning. Its census takes the class named __port__ (if any) and then
    -- every selector and property of every @interface in the header, by first keyword and name, as the Python does.
    local own = {}
    local own_header = path.join(checkout, OWN_REL)
    if os.isfile(own_header) then
        local port = census({ own_header }).members["__port__"]
        if port then
            for member in pairs(port) do
                own[member] = true
            end
        end
        for _, block in ipairs(class_blocks(read_text(own_header))) do
            for _, sel in ipairs(method_selectors(block[2])) do
                own[sel] = true
            end
            for _, prop in ipairs(property_names(block[2])) do
                own[prop] = true
            end
        end
    end

    -- What the registry covers, per class, as sets. rows[owner] exists for every owner a row names, even with an
    -- empty set, and the presence of the key is what decides whether the port's own names count for the class.
    local rows = {}
    local function row_for(owner)
        local r = rows[owner]
        if not r then
            r = { n = 0, keys = {} }
            rows[owner] = r
        end
        return r
    end
    for _, file in ipairs(registry) do
        for _, entry in ipairs(entries_of(decode_json(file), file)) do
            local api = entry.api or raise("%s", file .. ": a row has no api")
            local owner, selector = bracket_form(api)
            if not owner and api:find(".", 1, true) then
                local dot = api:find(".", 1, true)
                owner, selector = api:sub(1, dot - 1), api:sub(dot + 1)
            end
            if owner then
                local r = row_for(owner)
                local key = selector:match("^[^:]*")
                if not r.keys[key] then
                    r.keys[key] = true
                    r.n = r.n + 1
                end
            else
                row_for(api)
            end
        end
    end

    local function covered(cls, member)
        local r = rows[cls]
        if r then
            return r.keys[member] == true
        end
        return own[member] == true
    end

    -- sorted(declared, key=-len): most members first, and a tie keeps the order the classes were first met.
    local ranked = {}
    for i, cls in ipairs(declared.order) do
        ranked[#ranked + 1] = { cls = cls, size = count_keys(declared.members[cls]), index = i }
    end
    table.sort(ranked, function(a, b)
        if a.size ~= b.size then
            return a.size > b.size
        end
        return a.index < b.index
    end)

    local total_d, total_r, total_m = 0, 0, 0
    print(string.format("  the 26.2 headers: %d @interfaces", #declared.order))
    for _, item in ipairs(ranked) do
        local cls = item.cls
        local members = {}
        for member in pairs(declared.members[cls]) do
            if not INHERITED[member] then
                members[#members + 1] = member
            end
        end
        local r = rows[cls]
        if #members > 0 or (r and r.n > 0) then
            local missing = 0
            for _, member in ipairs(members) do
                if not covered(cls, member) then
                    missing = missing + 1
                end
            end
            local covered_count = #members - missing
            total_d = total_d + #members
            total_r = total_r + covered_count
            total_m = total_m + missing
            print(string.format("  %-20s %3d declared, %3d covered, %3d missing", cls, #members, covered_count, missing))
        end
    end
    print(string.format("  %-20s %3d declared, %3d covered, %3d missing", "TOTAL", total_d, total_r, total_m))
end
