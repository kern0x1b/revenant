local KEYWORDS = {["if"] = true, ["for"] = true, ["while"] = true, ["switch"] = true, ["return"] = true,
    ["sizeof"] = true, ["typeof"] = true, ["__typeof__"] = true}
local SKIP_FIRST = {typedef = true, struct = true, union = true, enum = true}
local MARKER = "BACKPORT_IMPL("

local function blank(text)
    return (string.gsub(text, "[^\n]", " "))
end

local function mask(text, directives)
    local out = {}
    local pos, n = 1, #text
    local code = false
    while pos <= n do
        local s = string.find(text, "[\n/\"'#]", pos)
        if s == nil then
            local rest = string.sub(text, pos)
            if string.find(rest, "%S") then
                code = true
            end
            table.insert(out, rest)
            break
        end
        local chunk = string.sub(text, pos, s - 1)
        if string.find(chunk, "%S") then
            code = true
        end
        table.insert(out, chunk)
        local c = string.sub(text, s, s)
        local nxt = string.sub(text, s + 1, s + 1)
        if c == "\n" then
            table.insert(out, "\n")
            code = false
            pos = s + 1
        elseif c == "/" and nxt == "/" then
            local e = string.find(text, "\n", s, true) or (n + 1)
            table.insert(out, blank(string.sub(text, s, e - 1)))
            pos = e
        elseif c == "/" and nxt == "*" then
            local _, close = string.find(text, "*/", s + 2, true)
            close = close or n
            table.insert(out, blank(string.sub(text, s, close)))
            pos = close + 1
        elseif c == '"' or c == "'" then
            local j = s + 1
            while j <= n do
                local d = string.sub(text, j, j)
                if d == "\\" then
                    j = j + 2
                elseif d == c or d == "\n" then
                    break
                else
                    j = j + 1
                end
            end
            local last = math.min(j, n)
            if string.sub(text, last, last) == "\n" then
                last = last - 1
            end
            table.insert(out, blank(string.sub(text, s, last)))
            code = true
            pos = last + 1
        elseif c == "#" and directives and not code then
            local e = s
            while true do
                local nl = string.find(text, "\n", e, true)
                if nl == nil then
                    e = n
                    break
                end
                if string.sub(text, nl - 1, nl - 1) == "\\" then
                    e = nl + 1
                else
                    e = nl - 1
                    break
                end
            end
            table.insert(out, blank(string.sub(text, s, e)))
            pos = e + 1
        else
            table.insert(out, c)
            code = true
            pos = s + 1
        end
    end
    return table.concat(out)
end

local function strip_attributes(masked)
    return (string.gsub(masked, "__attribute__%s*%b()", blank))
end

local function has_word(text, word)
    return string.find(" " .. text .. " ", "%W" .. word .. "%W") ~= nil
end

local function skip_back(m, i, from)
    while i >= from and string.find(string.sub(m, i, i), "%s") do
        i = i - 1
    end
    return i
end

local function word_back(m, i, from)
    local j = i
    while j >= from and string.find(string.sub(m, j, j), "[%w_]") do
        j = j - 1
    end
    if j == i then
        return nil
    end
    return j + 1, i
end

local function open_back(m, close, from)
    local depth = 0
    for i = close, from, -1 do
        local c = string.sub(m, i, i)
        if c == ")" then
            depth = depth + 1
        elseif c == "(" then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
    end
    return nil
end

local function match_brace(m, open)
    local depth, pos = 0, open
    while true do
        local s = string.find(m, "[{}]", pos)
        if s == nil then
            return #m
        end
        if string.sub(m, s, s) == "{" then
            depth = depth + 1
        else
            depth = depth - 1
        end
        if depth == 0 then
            return s
        end
        pos = s + 1
    end
end

local function top_equal(m, from, to)
    local depth = 0
    for i = from, to do
        local c = string.sub(m, i, i)
        if c == "(" or c == "[" then
            depth = depth + 1
        elseif c == ")" or c == "]" then
            depth = depth - 1
        elseif c == "=" and depth == 0 then
            local before, after = string.sub(m, i - 1, i - 1), string.sub(m, i + 1, i + 1)
            if after ~= "=" and before ~= "=" and before ~= "<" and before ~= ">" and before ~= "!" then
                return i
            end
        end
    end
    return nil
end

local function function_name(m, from, to)
    local text = string.sub(m, from, to)
    if has_word(text, "static") or has_word(text, "typedef") or string.find(text, "^%s*@") then
        return nil
    end
    local e = skip_back(m, to, from)
    while e >= from and string.sub(m, e, e) == ")" do
        local open = open_back(m, e, from)
        if open == nil then
            return nil
        end
        local wstart, wstop = word_back(m, skip_back(m, open - 1, from), from)
        if wstart == nil then
            return nil
        end
        local word = string.sub(m, wstart, wstop)
        if string.find(word, "^[A-Z][A-Z0-9_]*$") then
            e = skip_back(m, wstart - 1, from)
        elseif KEYWORDS[word] then
            return nil
        else
            return word, wstart, wstop
        end
    end
    return nil
end

local function global_names(m, from, to)
    local text = string.sub(m, from, to)
    local first = string.match(text, "^%s*([%w_@]+)") or ""
    if string.sub(first, 1, 1) == "@" or SKIP_FIRST[first] or has_word(text, "extern") or has_word(text, "static")
        or has_word(text, "typedef") then
        return {}
    end
    local dend, depth = to, 0
    for i = from, to do
        local c = string.sub(m, i, i)
        if c == "(" then
            depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
        elseif depth == 0 and (c == "=" or c == "[") then
            dend = i - 1
            break
        end
    end
    if string.find(string.sub(m, from, dend), "(", 1, true) then
        return {}
    end
    local names, piece, index = {}, from, 0
    for i = from, dend + 1 do
        local c = i <= dend and string.sub(m, i, i) or ","
        if c == "," then
            index = index + 1
            local ws, we = word_back(m, skip_back(m, i - 1, piece), piece)
            if ws and (index > 1 or string.find(string.sub(m, piece, ws - 1), "[%w_%*]")) then
                table.insert(names, {name = string.sub(m, ws, we), first = ws, last = we})
            end
            piece = i + 1
        end
    end
    return names
end

local function tidy(text)
    local out = string.gsub(text, "%s+", " ")
    out = string.gsub(out, "^ ", "")
    return (string.gsub(out, " $", ""))
end

local function scan_masked(m)
    local defs = {}
    local function add(name, first, last, kind, type, array)
        table.insert(defs, {name = name, first = first, last = last, kind = kind, type = type, array = array})
    end
    local paren, brace, transparent, init = 0, 0, 0, false
    local stmt, pos = 1, 1
    while true do
        local s = string.find(m, "[%(%){};@]", pos)
        if s == nil then
            break
        end
        local c = string.sub(m, s, s)
        local nextp = s + 1
        if c == "(" then
            paren = paren + 1
        elseif c == ")" then
            paren = paren - 1
        elseif c == "@" then
            local word = string.match(m, "^@(%a+)", s)
            if paren == 0 and brace == 0 and (word == "end" or word == "implementation" or word == "interface" or word == "protocol") then
                stmt = s + 1 + #word
            end
        elseif c == "{" then
            if paren == 0 and brace == 0 then
                if top_equal(m, stmt, s - 1) then
                    init = true
                    brace = 1
                elseif string.find(string.sub(m, stmt, s - 1), "^%s*extern%s*$") then
                    transparent = transparent + 1
                    stmt = s + 1
                else
                    local name, first, last = function_name(m, stmt, s - 1)
                    if name then
                        add(name, first, last, "function")
                    end
                    local close = match_brace(m, s)
                    stmt = close + 1
                    nextp = close + 1
                end
            else
                brace = brace + 1
            end
        elseif c == "}" then
            if brace > 0 then
                brace = brace - 1
                if brace == 0 then
                    init = false
                end
            elseif transparent > 0 then
                transparent = transparent - 1
                stmt = s + 1
            else
                stmt = s + 1
            end
        elseif c == ";" then
            if paren == 0 and brace == 0 then
                local head = string.sub(m, stmt, s - 1)
                local property = string.find(head, "@dynamic%f[^%w_]") ~= nil or string.find(head, "@synthesize%f[^%w_]") ~= nil
                for _, found in ipairs(not property and global_names(m, stmt, s - 1) or {}) do
                    local decl = string.sub(m, stmt, found.first - 1)
                    local after = string.match(m, "^%s*(.)", found.last + 1)
                    add(found.name, found.first, found.last, "global", (not string.find(decl, ",", 1, true)) and tidy(decl) or nil, after == "[")
                end
                stmt = s + 1
            end
        end
        pos = nextp
    end
    return defs
end

function scan(text)
    return scan_masked(strip_attributes(mask(text, true)))
end

local function macros(text)
    local found = {}
    local pos = 1
    while true do
        local s, e, name, params = string.find(text, "#[ \t]*define[ \t]+([%a_][%w_]*)%(([^%)]*)%)", pos)
        if s == nil then
            break
        end
        local line_start = string.match(string.sub(text, 1, s - 1), "([^\n]*)$")
        if string.find(line_start, "^%s*$") then
            local bend = e
            while true do
                local nl = string.find(text, "\n", bend + 1, true)
                if nl == nil then
                    bend = #text
                    break
                end
                if string.sub(text, nl - 1, nl - 1) == "\\" then
                    bend = nl
                else
                    bend = nl - 1
                    break
                end
            end
            local names = {}
            for param in string.gmatch(params, "[^,%s]+") do
                table.insert(names, param)
            end
            local body = string.sub(text, e + 1, bend)
            local defs = scan_masked(strip_attributes(mask(body, false)))
            table.insert(found, {name = name, params = names, first = e + 1, defs = defs})
        end
        pos = e + 1
    end
    return found
end

function marked(text)
    local names = {}
    for name in string.gmatch(text, "BACKPORT_IMPL%(%s*([%a_][%w_]*)%s*%)") do
        names[name] = true
    end
    return names
end

function marker_arguments(text)
    local bad = {}
    for argument in string.gmatch(text, "BACKPORT_IMPL%(([^%)]*)%)") do
        if not string.find(argument, "^%s*[%a_][%w_]*%s*$") then
            table.insert(bad, argument)
        end
    end
    return bad
end

local function line_of(text, index)
    local _, count = string.gsub(string.sub(text, 1, index), "\n", "")
    return count + 1
end

local function already_marked(text, first)
    return first > #MARKER and string.sub(text, first - #MARKER, first - 1) == MARKER
end

local function in_extern(code, first)
    local start = first
    while start > 1 and not string.find(string.sub(code, start - 1, start - 1), "[;{}]") do
        start = start - 1
    end
    return string.find(string.sub(code, start, first - 1), "extern%f[^%w_]") ~= nil
end

local function code_uses(text, names)
    local code = mask(text, true)
    local found = {}
    for name in pairs(names) do
        local pos = 1
        while true do
            local first, last = string.find(code, name, pos, true)
            if first == nil then
                break
            end
            local before = string.sub(code, first - 1, first - 1)
            local member = before == "." or string.sub(code, first - 2, first - 1) == "->"
            local after = string.sub(code, last + 1, last + 1)
            if not member and not string.find(before, "[%w_]") and not string.find(after, "[%w_]") and not already_marked(text, first) and not in_extern(code, first) then
                table.insert(found, {first = first, last = last, name = name})
            end
            pos = last + 1
        end
    end
    return found
end

local function apply_edits(text, edits)
    table.sort(edits, function (a, b) return a.first > b.first end)
    local out = text
    for _, edit in ipairs(edits) do
        out = string.sub(out, 1, edit.first - 1) .. MARKER .. edit.name .. ")" .. string.sub(out, edit.last + 1)
    end
    return out
end

function rename_uses(text, names)
    return apply_edits(text, code_uses(text, names))
end

function rewrite(text, renamable, sdk)
    local edits, renamed, kept, unhandled, globals = {}, {}, {}, {}, {}
    local function classify(name, kind, first, last)
        if renamable[name] then
            if not already_marked(text, first) then
                table.insert(edits, {first = first, last = last, name = name})
            end
            renamed[name] = true
            if kind == "global" then
                globals[name] = true
            end
        elseif sdk[name] then
            table.insert(kept, {name = name, line = line_of(text, first)})
        end
    end
    for _, def in ipairs(scan(text)) do
        classify(def.name, def.kind, def.first, def.last)
    end
    for _, macro in ipairs(macros(text)) do
        for _, def in ipairs(macro.defs) do
            local parameter = false
            for _, param in ipairs(macro.params) do
                parameter = parameter or param == def.name
            end
            if parameter then
                table.insert(unhandled, {name = def.name, macro = macro.name, line = line_of(text, macro.first + def.first - 1)})
            else
                classify(def.name, def.kind, macro.first + def.first - 1, macro.first + def.last - 1)
            end
        end
    end
    local seen = {}
    for _, edit in ipairs(edits) do
        seen[edit.first] = true
    end
    for _, use in ipairs(code_uses(text, globals)) do
        if not seen[use.first] then
            seen[use.first] = true
            table.insert(edits, use)
        end
    end
    local out = apply_edits(text, edits)
    local names = {}
    for name in pairs(renamed) do
        table.insert(names, name)
    end
    table.sort(names)
    return out, names, kept, unhandled
end

function marked_definitions(text)
    local names = marked(text)
    local unmarked = (string.gsub(text, "BACKPORT_IMPL%(%s*([%a_][%w_]*)%s*%)", "%1"))
    local found = {}
    local function take(defs)
        for _, def in ipairs(defs) do
            if names[def.name] and found[def.name] == nil then
                found[def.name] = {kind = def.kind, type = def.type, array = def.array}
            end
        end
    end
    take(scan(unmarked))
    for _, macro in ipairs(macros(unmarked)) do
        take(macro.defs)
    end
    return found
end
