-- declared-check.lua <checkout> [--registry <file>...] - does every PDFKit registry row name a member the 26.2 header of its
-- own class declares? Ported from declared-check.py, whose docstring is the usage text below. The matchers are the same
-- as count-missing.lua's: the regular expressions are written out as functions, with their backtracking, and each says
-- which pattern it stands for.

import("core.base.json")

local DOC = [==[
Does every PDFKit registry row name a member the 26.2 header of ITS OWN class declares?

    declared-check.lua <checkout> [--registry <file>...]

It exists because this series put three rows on the registry for methods the 26.2 PDFView.h does not
declare, and the header in the same series said so in as many words.  A row for a member that is not
the API is found by anything that treats the registry as the package's surface, and one of the three
collided BY NAME with a member another class owns and the same file already describes.

For each row:
  * a class row must match an @interface of that name in the framework's headers;
  * a method row's selector - the one after the brackets - must appear in that class's @interface;
  * a property row's name must be declared @property in that class's @interface.

The port's OWN members - the ones it adds, like -[PDFPage initWithCGPDFPage:document:index:] and
-charon_CGPDFDocument - are declared in the PORT's header, not the SDK's, and a row for one of those is
not a finding.  So the port's own header is consulted too, and a row that names a member of the port's
own making is reported separately rather than mixed in.

Exit 0 when every row names a declared member.  Exit 1, naming each row that does not.
]==]

-- NSObject's own members, which every class inherits and no PDFKit header declares (see the Python).
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

-- Every name of a set, sorted by bytes.
local function sorted_names(set)
    local names = {}
    for name in pairs(set) do
        names[#names + 1] = name
    end
    table.sort(names, byte_less)
    return names
end

-- Python's repr of sorted(set) for class names: ['A', 'B'].
local function py_list(set)
    local quoted = {}
    for i, name in ipairs(sorted_names(set)) do
        quoted[i] = "'" .. name .. "'"
    end
    return "[" .. table.concat(quoted, ", ") .. "]"
end

-- re.match(r"[-+]\[[\w]+ ([^:\]]+)", api): the text after the owner and its one space, or nil.
local function bare_group(api)
    local b1, b2 = api:byte(1), api:byte(2)
    if (b1 ~= 45 and b1 ~= 43) or b2 ~= 91 then
        return nil
    end
    local j = 3
    while is_word(api:byte(j)) do
        j = j + 1
    end
    if j == 3 or api:byte(j) ~= 32 then
        return nil
    end
    local k = j + 1
    local e = k
    while true do
        local b = api:byte(e)
        if b == nil or b == 58 or b == 93 then -- : or ]
            break
        end
        e = e + 1
    end
    if e == k then
        return nil
    end
    return api:sub(k, e - 1)
end

-- declarations(headers): selector -> the set of classes that declare it (DECL_METHOD, by first keyword), the same for
-- property names (DECL_PROPERTY), and the set of class names. The sets are sets of class names, as in the Python.
-- True when one of the EXTERN lines names `name` as a whole word.
local function extern_names(lines, name)
    local pattern = "%f[%w_]" .. name .. "%f[^%w_]"
    for _, line in ipairs(lines) do
        if line:find(pattern) then
            return true
        end
    end
    return false
end

local function declarations(paths)
    local d = { methods = {}, properties = {}, classes = {}, externs = {} }
    for _, path in ipairs(paths) do
        local source = read_text(path)
        for line in source:gmatch("[^\n]+") do
            if line:find("EXTERN", 1, true) then
                d.externs[#d.externs + 1] = line
            end
        end
        for _, block in ipairs(class_blocks(source)) do
            local name, body = block[1], block[2]
            d.classes[name] = true
            for _, sel in ipairs(method_selectors(body)) do
                local set = d.methods[sel] or {}
                d.methods[sel] = set
                set[name] = true
            end
            for _, prop in ipairs(property_names(body)) do
                local set = d.properties[prop] or {}
                d.properties[prop] = set
                set[name] = true
            end
        end
    end
    return d
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

    local sdk_decl = declarations(glob_files(headers, ".h"))
    local own_decl = { methods = {}, properties = {}, classes = {}, externs = {} }
    local own_header = path.join(checkout, OWN_REL)
    if os.isfile(own_header) then
        own_decl = declarations({ own_header })
    end
    if count_keys(sdk_decl.classes) == 0 then
        print("  the headers under " .. headers .. " yielded no @interface at all - the path is wrong")
        os.exit(2)
    end

    local sm, sp, sc = sdk_decl.methods, sdk_decl.properties, sdk_decl.classes
    local om, op, oc = own_decl.methods, own_decl.properties, own_decl.classes

    local checked, found, ours = 0, 0, 0
    local problems = {}
    local function problem(api, why)
        problems[#problems + 1] = { api, why }
    end

    -- One row. A method row is -[Owner selector...], and its selector is the text before the first colon; a property
    -- row is Owner.name; a class row is the bare name. Each is checked against the declarations of its own class.
    local function check(api, kind)
        if kind == "constant" then
            -- A CONSTANT row names an extern value, not a class: the header declares it as PDFKIT_EXTERN ... const NAME
            -- on one line. The Python gave every bare name the class rule, which flagged all 126 constant rows.
            if extern_names(sdk_decl.externs, api) then
                return
            end
            if extern_names(own_decl.externs, api) then
                ours = ours + 1
                return
            end
            problem(api, "no PDFKIT_EXTERN constant " .. api .. " in the 26.2 headers")
            return
        end
        local bare = bare_group(api)
        if bare and (bare == "dealloc" or bare == "init" or bare == "copyWithZone") then
            ours = ours + 1
            return
        end
        local prefix = api:sub(1, 2)
        if prefix == "-[" or prefix == "+[" then
            local owner, selector = bracket_form(api)
            if not owner then
                problem(api, "the row's own name could not be read")
                found = found + 1
                return
            end
            selector = selector:match("^[^:]*")
            local sel_sdk, sel_own = sm[selector], om[selector]
            local sel_prop, sel_oprop = sp[selector], op[selector]
            if not sc[owner] and not oc[owner] then
                problem(api, "no @interface " .. owner .. " in the 26.2 headers")
            elseif sel_sdk and not sel_sdk[owner] and not (sel_own and sel_own[selector]) then
                problem(api, "-[" .. owner .. " " .. selector .. "...] is declared, but on " .. py_list(sel_sdk)
                    .. " and not on " .. owner)
            elseif not sel_sdk and not sel_own and not (sel_prop and sel_prop[owner])
                and not (sel_oprop and sel_oprop[owner]) then
                problem(api, "-[" .. owner .. " " .. selector
                    .. "...] is declared by no @interface, as a method or a property")
            elseif sel_own and not (sel_sdk and sel_sdk[owner]) then
                ours = ours + 1
            end
        elseif api:find(".", 1, true) then
            local dot = api:find(".", 1, true)
            local owner, prop = api:sub(1, dot - 1), api:sub(dot + 1)
            local ps, po = sp[prop], op[prop]
            local ms, mo = sm[prop], om[prop]
            if not sc[owner] and not oc[owner] then
                problem(api, "no @interface " .. owner .. " in the 26.2 headers")
            elseif ps and not ps[owner] and not (po and po[owner]) then
                problem(api, owner .. "." .. prop .. " is declared, but on " .. py_list(ps) .. " and not on " .. owner)
            elseif INHERITED[prop] then
                return
            elseif not ps and not (po and po[owner]) and not (ms and ms[owner]) and not (mo and mo[owner]) then
                problem(api, owner .. "." .. prop .. " is declared by no @interface, as a property or a method")
            elseif not (ps and ps[owner]) and po and po[owner] then
                ours = ours + 1
            end
        else
            if not sc[api] and not oc[api] then
                problem(api, "no @interface " .. api .. " in the 26.2 headers")
            elseif oc[api] and not sc[api] then
                ours = ours + 1
            end
        end
    end

    for _, file in ipairs(registry) do
        for _, entry in ipairs(entries_of(decode_json(file), file)) do
            local api = entry.api or raise("%s", file .. ": a row has no api")
            checked = checked + 1
            check(api, entry.kind)
        end
    end

    print(string.format("  the 26.2 headers: %d @interfaces, %d selectors, %d properties",
        count_keys(sc), count_keys(sm), count_keys(sp)))
    print(string.format("  %d PDFKit registry rows checked, %d name a member no header of their own class declares, "
        .. "%d name a member of the PORT's own making", checked, found, ours))
    for _, p in ipairs(problems) do
        print("  NOT DECLARED  " .. p[1] .. "  " .. p[2])
    end
    if #problems > 0 then
        os.exit(1)
    end
end
