local OPERATORS = {
    "**=", "//=", ">>=", "<<=", "...", "->", ":=", "**", "//", ">>", "<<", "<=", ">=", "==", "!=",
    "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "@="
}

local SINGLE = {}
for c in ("+-*/%&|^~<>=.,:;@()[]{}"):gmatch(".") do
    SINGLE[c] = true
end

local PREFIXES = {[""] = true, r = true, u = true, f = true, b = true, fr = true, rf = true, br = true, rb = true}

local TABSIZE = 8

function tokenerror(message, line, col)
    raise({tokenerror = true, message = message, line = line, col = col})
end

local function string_prefix(line, pos)
    local prefix = line:match("^[rRbBuUfF]?[rRbBuUfF]?", pos)
    for len = #prefix, 0, -1 do
        local p = prefix:sub(1, len)
        local q = line:sub(pos + len, pos + len)
        if (q == "'" or q == '"') and PREFIXES[p:lower()] then
            return len, q
        end
    end
end

local function digits(line, pos, class)
    local s, e = line:find("^[" .. class .. "]", pos)
    if not s then
        return nil
    end
    local last = e
    while true do
        local s2, e2 = line:find("^_?[" .. class .. "]", last + 1)
        if not s2 then
            break
        end
        last = e2
    end
    return last
end

local function exponent(line, pos)
    if line:find("^[eE]", pos) then
        local p = pos + 1
        if line:find("^[-+]", p) then
            p = p + 1
        end
        local e = digits(line, p, "0-9")
        if e then
            return e
        end
    end
    return nil
end

local function scan_number(line, pos)
    local c2 = line:sub(pos, pos + 1):lower()
    if c2 == "0x" or c2 == "0o" or c2 == "0b" then
        local class = c2 == "0x" and "0-9a-fA-F" or (c2 == "0o" and "0-7" or "01")
        local last = pos + 1
        local any = false
        while true do
            local s, e = line:find("^_?[" .. class .. "]", last + 1)
            if not s then
                break
            end
            last = e
            any = true
        end
        if any then
            return last
        end
    end
    local finish
    local int_end = digits(line, pos, "0-9")
    if int_end then
        finish = int_end
        local is_float = false
        if line:sub(finish + 1, finish + 1) == "." then
            is_float = true
            finish = digits(line, finish + 2, "0-9") or finish + 1
        end
        local e = exponent(line, finish + 1)
        if e then
            finish = e
            is_float = true
        end
        if line:find("^[jJ]", finish + 1) then
            finish = finish + 1
        end
        return finish
    end
    if line:sub(pos, pos) == "." then
        local frac = digits(line, pos + 1, "0-9")
        if frac then
            finish = frac
            local e = exponent(line, finish + 1)
            if e then
                finish = e
            end
            if line:find("^[jJ]", finish + 1) then
                finish = finish + 1
            end
            return finish
        end
    end
    return nil
end

local function find_single_end(line, pos, quote)
    local i = pos
    while i <= #line do
        local c = line:sub(i, i)
        if c == "\\" then
            if i + 1 <= #line then
                local n = line:sub(i + 1, i + 1)
                if n == "\n" or (n == "\r" and line:sub(i + 2, i + 2) == "\n") then
                    return nil, true
                end
                i = i + 2
            else
                return nil, false
            end
        elseif c == quote then
            return i
        elseif c == "\n" then
            return nil, false
        else
            i = i + 1
        end
    end
    return nil, false
end

local function find_triple_end(text, pos, quote)
    local i = pos
    local triple = quote:rep(3)
    while i <= #text do
        local c = text:sub(i, i)
        if c == "\\" then
            i = i + 2
        elseif text:sub(i, i + 2) == triple then
            return i + 2
        else
            i = i + 1
        end
    end
    return nil
end

local function is_identifier_start(c)
    return c:find("^[%a_\128-\255]") ~= nil
end

function generate_tokens(readline, emit)
    local lnum, parenlev, continued = 0, 0, false
    local indents = {0}
    local contstr, needcont, contline, strstart, contquote, contkind = nil, false, nil, nil, nil, nil
    local last_line = ""
    local line
    local function out(kind, text, sl, sc, el, ec, l)
        return emit({type = kind, string = text, start = {sl, sc}, finish = {el, ec}, line = l})
    end
    while true do
        line = readline() or ""
        lnum = lnum + 1
        local pos, max = 1, #line
        if line ~= "" then
            last_line = line
        end
        local skip_rest = false
        if contstr then
            if line == "" then
                tokenerror("EOF in multi-line string", strstart[1], strstart[2])
            end
            local endpos
            if contkind == "triple" then
                endpos = find_triple_end(line, 1, contquote)
            else
                endpos = find_single_end(line, 1, contquote)
            end
            if endpos then
                pos = endpos + 1
                if out("STRING", contstr .. line:sub(1, endpos), strstart[1], strstart[2], lnum, endpos, contline .. line) then
                    return
                end
                contstr, needcont, contline = nil, false, nil
            elseif needcont and line:sub(-2) ~= "\\\n" and line:sub(-3) ~= "\\\r\n" then
                if out("ERRORTOKEN", contstr .. line, strstart[1], strstart[2], lnum, #line, contline) then
                    return
                end
                contstr, contline = nil, nil
                skip_rest = true
            else
                contstr = contstr .. line
                contline = contline .. line
                skip_rest = true
            end
        elseif parenlev == 0 and not continued then
            if line == "" then
                break
            end
            local column = 0
            while pos <= max do
                local c = line:sub(pos, pos)
                if c == " " then
                    column = column + 1
                elseif c == "\t" then
                    column = (column // TABSIZE + 1) * TABSIZE
                elseif c == "\f" then
                    column = 0
                else
                    break
                end
                pos = pos + 1
            end
            if pos > max then
                break
            end
            local c = line:sub(pos, pos)
            if c == "#" or c == "\r" or c == "\n" then
                if c == "#" then
                    local comment = line:sub(pos):gsub("[\r\n]+$", "")
                    if out("COMMENT", comment, lnum, pos - 1, lnum, pos - 1 + #comment, line) then
                        return
                    end
                    pos = pos + #comment
                end
                if out("NL", line:sub(pos), lnum, pos - 1, lnum, #line, line) then
                    return
                end
                skip_rest = true
            else
                if column > indents[#indents] then
                    indents[#indents + 1] = column
                    if out("INDENT", line:sub(1, pos - 1), lnum, 0, lnum, pos - 1, line) then
                        return
                    end
                end
                while column < indents[#indents] do
                    local found = false
                    for _, v in ipairs(indents) do
                        if v == column then
                            found = true
                        end
                    end
                    if not found then
                        raise({indentationerror = true, message = "unindent does not match any outer indentation level", line = lnum, col = pos - 1})
                    end
                    indents[#indents] = nil
                    if out("DEDENT", "", lnum, pos - 1, lnum, pos - 1, line) then
                        return
                    end
                end
            end
        else
            if line == "" then
                tokenerror("EOF in multi-line statement", lnum, 0)
            end
            continued = false
        end
        while not skip_rest and pos <= max do
            local ws = line:match("^[ \f\t]*", pos)
            local start = pos + #ws
            local c = line:sub(start, start)
            if start > max then
                pos = start
                break
            end
            local stop = false
            if c == "\\" and (line:sub(start + 1, start + 1) == "\n" or line:sub(start + 1, start + 2) == "\r\n") then
                continued = true
                pos = start + (line:sub(start + 1, start + 1) == "\n" and 2 or 3)
            elseif c == "#" then
                local comment = line:sub(start):gsub("[\r\n]+$", "")
                pos = start + #comment
                stop = out("COMMENT", comment, lnum, start - 1, lnum, pos - 1, line)
            else
                local plen, quote = string_prefix(line, start)
                local number_end = (c:find("[0-9]") or (c == "." and line:sub(start + 1, start + 1):find("[0-9]"))) and scan_number(line, start)
                if plen and line:sub(start + plen, start + plen + 2) == quote:rep(3) then
                    local endpos = find_triple_end(line, start + plen + 3, quote)
                    if endpos then
                        pos = endpos + 1
                        stop = out("STRING", line:sub(start, endpos), lnum, start - 1, lnum, endpos, line)
                    else
                        strstart = {lnum, start - 1}
                        contstr = line:sub(start)
                        contline = line
                        contquote = quote
                        contkind = "triple"
                        needcont = false
                        pos = max + 1
                        break
                    end
                elseif number_end then
                    pos = number_end + 1
                    stop = out("NUMBER", line:sub(start, number_end), lnum, start - 1, lnum, number_end, line)
                elseif c == "\n" or (c == "\r" and line:sub(start + 1, start + 1) == "\n") then
                    local text = c == "\n" and "\n" or "\r\n"
                    pos = start + #text
                    stop = out(parenlev > 0 and "NL" or "NEWLINE", text, lnum, start - 1, lnum, pos - 1, line)
                elseif plen then
                    local endpos, continues = find_single_end(line, start + plen + 1, quote)
                    if endpos then
                        pos = endpos + 1
                        stop = out("STRING", line:sub(start, endpos), lnum, start - 1, lnum, endpos, line)
                    elseif continues then
                        strstart = {lnum, start - 1}
                        contstr = line:sub(start)
                        contline = line
                        contquote = quote
                        contkind = "single"
                        needcont = true
                        pos = max + 1
                        break
                    else
                        pos = start + 1
                        stop = out("ERRORTOKEN", c, lnum, start - 1, lnum, start, line)
                    end
                elseif is_identifier_start(c) then
                    local name = line:match("^[%w_\128-\255]+", start)
                    pos = start + #name
                    stop = out("NAME", name, lnum, start - 1, lnum, pos - 1, line)
                else
                    local op
                    for _, candidate in ipairs(OPERATORS) do
                        if line:sub(start, start + #candidate - 1) == candidate then
                            op = candidate
                            break
                        end
                    end
                    if not op and SINGLE[c] then
                        op = c
                    end
                    if op then
                        if op == "(" or op == "[" or op == "{" then
                            parenlev = parenlev + 1
                        elseif op == ")" or op == "]" or op == "}" then
                            parenlev = parenlev - 1
                        end
                        pos = start + #op
                        stop = out("OP", op, lnum, start - 1, lnum, pos - 1, line)
                    else
                        pos = start + 1
                        stop = out("ERRORTOKEN", c, lnum, start - 1, lnum, start, line)
                    end
                end
            end
            if stop then
                return
            end
        end
    end
    if last_line ~= "" and not last_line:find("[\r\n]$") and not last_line:match("^%s*(.-)$"):find("^#") then
        if out("NEWLINE", "", lnum - 1, #last_line, lnum - 1, #last_line + 1, "") then
            return
        end
    end
    for _ = 2, #indents do
        if out("DEDENT", "", lnum, 0, lnum, 0, "") then
            return
        end
    end
    out("ENDMARKER", "", lnum, 0, lnum, 0, "")
end

function lines_reader(lines)
    local i = 0
    return function()
        i = i + 1
        return lines[i]
    end
end

function split_keepends(text)
    local lines = {}
    local pos = 1
    while pos <= #text do
        local e = text:find("\n", pos, true)
        if not e then
            lines[#lines + 1] = text:sub(pos)
            break
        end
        lines[#lines + 1] = text:sub(pos, e)
        pos = e + 1
    end
    return lines
end

function tokenize_all(text)
    local tokens = {}
    generate_tokens(lines_reader(split_keepends(text)), function(tok)
        tokens[#tokens + 1] = tok
    end)
    return tokens
end
