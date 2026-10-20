local languages = {
    c = {kind = "c", clang = "c"},
    h = {kind = "c", cpp = true, clang = "objective-c++"},
    m = {kind = "c", clang = "objective-c"},
    mm = {kind = "c", cpp = true, clang = "objective-c++"},
    cc = {kind = "c", cpp = true, clang = "c++"},
    cpp = {kind = "c", cpp = true, clang = "c++"},
    cxx = {kind = "c", cpp = true, clang = "c++"},
    hpp = {kind = "c", cpp = true, clang = "c++"},
    hh = {kind = "c", cpp = true, clang = "c++"},
    inc = {kind = "c", cpp = true, clang = "c++"},
    swift = {kind = "swift"},
    lua = {kind = "lua"},
    sh = {kind = "sh"},
    yml = {kind = "yaml"},
    yaml = {kind = "yaml"}
}

local legal = {"[Ll]icen[cs]e", "SPDX%-License%-Identifier", "[Cc]opyright"}

local markers = {
    c = {"//", "/*"},
    swift = {"//", "/*"},
    lua = {"--"},
    sh = {"#"},
    yaml = {"#"}
}

function language(file)
    return languages[path.extension(file):sub(2):lower()]
end

local function isident(b)
    return b and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95)
end

local function c_comments(text, cpp)
    local spans = {}
    local n = #text
    local i = 1
    while i <= n do
        i = text:find("[/\"']", i)
        if not i then
            break
        end
        local b = text:byte(i)
        if b == 47 and text:byte(i + 1) == 47 then
            local j = i + 2
            while j <= n do
                local nl = text:find("\n", j, true)
                if not nl then
                    j = n + 1
                    break
                end
                local k = nl - 1
                if text:byte(k) == 13 then
                    k = k - 1
                end
                if text:byte(k) == 92 then
                    j = nl + 1
                else
                    j = nl
                    break
                end
            end
            table.insert(spans, {i, j - 1})
            i = j
        elseif b == 47 and text:byte(i + 1) == 42 then
            local e = text:find("*/", i + 2, true)
            local j = e and e + 1 or n
            table.insert(spans, {i, j})
            i = j + 1
        elseif b == 34 then
            local s = i - 1
            while isident(text:byte(s)) do
                s = s - 1
            end
            local prefix = text:sub(s + 1, i - 1)
            if cpp and (prefix == "R" or prefix == "u8R" or prefix == "uR" or prefix == "UR" or prefix == "LR") then
                local open = text:find("(", i + 1, true)
                local delim = text:sub(i + 1, open - 1)
                local close = text:find(")" .. delim .. "\"", open + 1, true)
                i = close and close + #delim + 2 or n + 1
            else
                local j = i + 1
                while j <= n do
                    local c = text:byte(j)
                    if c == 92 then
                        j = j + 2
                    elseif c == 34 or c == 10 then
                        break
                    else
                        j = j + 1
                    end
                end
                i = j + 1
            end
        elseif b == 39 then
            local s = i - 1
            while isident(text:byte(s)) or text:byte(s) == 39 or text:byte(s) == 46 do
                s = s - 1
            end
            local first = text:byte(s + 1)
            if cpp and s + 1 < i and first and first >= 48 and first <= 57 then
                i = i + 1
            else
                local j = i + 1
                while j <= n do
                    local c = text:byte(j)
                    if c == 92 then
                        j = j + 2
                    elseif c == 39 or c == 10 then
                        break
                    else
                        j = j + 1
                    end
                end
                i = j + 1
            end
        else
            i = i + 1
        end
    end
    return spans
end

local swift_code

local function swift_string(text, i, spans)
    local n = #text
    local hashes = 0
    while text:byte(i) == 35 do
        hashes = hashes + 1
        i = i + 1
    end
    local multiline = text:sub(i, i + 2) == "\"\"\""
    local j = multiline and i + 3 or i + 1
    local close = (multiline and "\"\"\"" or "\"") .. string.rep("#", hashes)
    local escape = "\\" .. string.rep("#", hashes)
    while j <= n do
        if text:sub(j, j + #close - 1) == close then
            return j + #close
        elseif text:sub(j, j + #escape - 1) == escape then
            local k = j + #escape
            if text:byte(k) == 40 then
                j = swift_code(text, k + 1, spans, true)
            else
                j = k + 1
            end
        elseif not multiline and text:byte(j) == 10 then
            return j
        else
            j = j + 1
        end
    end
    return n + 1
end

function swift_code(text, i, spans, interpolation)
    local n = #text
    local depth = 0
    local stops = interpolation and "[/\"#()]" or "[/\"#]"
    while i <= n do
        i = text:find(stops, i)
        if not i then
            break
        end
        local b = text:byte(i)
        if b == 47 and text:byte(i + 1) == 47 then
            local nl = text:find("\n", i + 2, true) or n + 1
            table.insert(spans, {i, nl - 1})
            i = nl
        elseif b == 47 and text:byte(i + 1) == 42 then
            local level = 1
            local j = i + 2
            while j <= n and level > 0 do
                if text:byte(j) == 47 and text:byte(j + 1) == 42 then
                    level = level + 1
                    j = j + 2
                elseif text:byte(j) == 42 and text:byte(j + 1) == 47 then
                    level = level - 1
                    j = j + 2
                else
                    j = j + 1
                end
            end
            table.insert(spans, {i, math.min(j - 1, n)})
            i = j
        elseif b == 34 then
            i = swift_string(text, i, spans)
        elseif b == 35 and text:match("^#+\"", i) then
            i = swift_string(text, i, spans)
        elseif interpolation and b == 40 then
            depth = depth + 1
            i = i + 1
        elseif interpolation and b == 41 then
            if depth == 0 then
                return i + 1
            end
            depth = depth - 1
            i = i + 1
        else
            i = i + 1
        end
    end
    return n + 1
end

local function swift_comments(text)
    local spans = {}
    swift_code(text, 1, spans, false)
    return spans
end

local function lua_long(text, i)
    local eq = text:match("^%[(=*)%[", i)
    if not eq then
        return nil
    end
    local close = text:find("]" .. eq .. "]", i + #eq + 2, true)
    return close and close + #eq + 1 or #text
end

local function lua_comments(text)
    local spans = {}
    local n = #text
    local i = 1
    if text:byte(1) == 35 then
        i = (text:find("\n", 1, true) or n) + 1
    end
    while i <= n do
        i = text:find("[%-\"'%[]", i)
        if not i then
            break
        end
        local b = text:byte(i)
        if b == 45 and text:byte(i + 1) == 45 then
            local e = lua_long(text, i + 2)
            if not e then
                e = (text:find("\n", i + 2, true) or n + 1) - 1
            end
            table.insert(spans, {i, e})
            i = e + 1
        elseif b == 34 or b == 39 then
            local j = i + 1
            while j <= n do
                local c = text:byte(j)
                if c == 92 then
                    j = j + 2
                elseif c == b or c == 10 then
                    break
                else
                    j = j + 1
                end
            end
            i = j + 1
        elseif b == 91 then
            local e = lua_long(text, i)
            i = e and e + 1 or i + 1
        else
            i = i + 1
        end
    end
    return spans
end

local sh_boundary = {[9] = true, [10] = true, [32] = true, [38] = true, [59] = true, [124] = true}

local function sh_heredocs(text, pos, pending)
    while #pending > 0 do
        local hd = table.remove(pending, 1)
        while pos <= #text do
            local nl = text:find("\n", pos, true) or #text + 1
            local line = text:sub(pos, nl - 1):gsub("\r$", "")
            pos = nl + 1
            if hd.strip then
                line = line:gsub("^\t+", "")
            end
            if line == hd.delim then
                break
            end
        end
    end
    return pos
end

local function sh_spans(text, i)
    local spans, pending = {}, {}
    local stack = {{kind = "code", depth = 0}}
    local n = #text
    local function push(kind)
        table.insert(stack, {kind = kind, depth = 0})
    end
    while i <= n do
        i = text:find("[\\\n\"'`$()<}#]", i)
        if not i then
            break
        end
        local top = stack[#stack]
        local kind = top.kind
        local c, nxt = text:byte(i), text:byte(i + 1)
        local step = 1
        if c == 92 then
            step = 2
        elseif c == 10 then
            i = sh_heredocs(text, i + 1, pending)
            step = 0
        elseif (c == 34 and kind == "dq") or (c == 96 and kind == "bt") or (c == 125 and kind == "param") then
            table.remove(stack)
        elseif c == 41 and nxt == 41 and kind == "arith" and top.depth == 0 then
            table.remove(stack)
            step = 2
        elseif c == 36 and nxt == 40 then
            local arith = text:byte(i + 2) == 40
            push(arith and "arith" or "sub")
            step = arith and 3 or 2
        elseif c == 36 and nxt == 123 then
            push("param")
            step = 2
        elseif c == 96 then
            push("bt")
        elseif c == 39 and kind ~= "dq" then
            local j = i + 1
            local ansi = text:byte(i - 1) == 36
            while j <= n and text:byte(j) ~= 39 do
                j = j + ((ansi and text:byte(j) == 92) and 2 or 1)
            end
            step = j + 1 - i
        elseif c == 34 then
            push("dq")
        elseif kind == "arith" then
            if c == 40 then
                top.depth = top.depth + 1
            elseif c == 41 and top.depth > 0 then
                top.depth = top.depth - 1
            end
        elseif kind == "code" or kind == "sub" or kind == "bt" then
            if c == 40 then
                if nxt == 40 then
                    push("arith")
                    step = 2
                else
                    top.depth = top.depth + 1
                end
            elseif c == 41 then
                if top.depth > 0 then
                    top.depth = top.depth - 1
                elseif kind == "sub" then
                    table.remove(stack)
                end
            elseif c == 60 and nxt == 60 and text:byte(i + 2) ~= 60 then
                local p = i + 2
                local strip = text:byte(p) == 45
                if strip then
                    p = p + 1
                end
                p = p + #(text:match("^[ \t]*", p) or "")
                local full, delim = text:match("^(\\?['\"]?([^%s;&|<>()'\"\\]+)['\"]?)", p)
                if full then
                    table.insert(pending, {delim = delim, strip = strip})
                    step = p + #full - i
                end
            elseif c == 35 and (i == 1 or sh_boundary[text:byte(i - 1)]) then
                local e = (text:find("\n", i, true) or n + 1) - 1
                if text:byte(e) == 13 then
                    e = e - 1
                end
                table.insert(spans, {i, e})
                step = e - i + 1
            end
        end
        i = i + step
    end
    return spans
end

local function sh_comments(text)
    local i = 1
    if text:sub(1, 2) == "#!" then
        i = (text:find("\n", 1, true) or #text) + 1
    end
    return sh_spans(text, i)
end

local yaml_opens = {[44] = true, [45] = true, [58] = true, [63] = true, [91] = true, [123] = true}

local function yaml_hash(text, from, to)
    local last
    local i = from
    while i <= to do
        local c = text:byte(i)
        if c == 35 and (i == from or text:byte(i - 1) == 32 or text:byte(i - 1) == 9) then
            return i
        elseif (c == 39 or c == 34) and (not last or yaml_opens[last]) then
            local j = i + 1
            while j <= to do
                local d = text:byte(j)
                if c == 39 and d == 39 and text:byte(j + 1) == 39 then
                    j = j + 2
                elseif c == 34 and d == 92 then
                    j = j + 2
                elseif d == c then
                    break
                else
                    j = j + 1
                end
            end
            i = j + 1
            last = 0
        else
            if c ~= 32 and c ~= 9 then
                last = c
            end
            i = i + 1
        end
    end
end

local function yaml_comments(text)
    local spans = {}
    local n = #text
    local pos = 1
    while pos <= n do
        local nl = text:find("\n", pos, true) or n + 1
        local hash = yaml_hash(text, pos, nl - 1)
        local code = text:sub(pos, (hash or nl) - 1)
        if hash then
            local e = nl - 1
            if text:byte(e) == 13 then
                e = e - 1
            end
            table.insert(spans, {hash, e})
        end
        pos = nl + 1
        if code:match("[:%-]%s*[|>][-+%d]*%s*$") or code:match("^%s*[|>][-+%d]*%s*$") then
            local indent = #code:match("^ *")
            local first, last = pos, pos - 1
            while pos <= n do
                local e = text:find("\n", pos, true) or n + 1
                local line = text:sub(pos, e - 1)
                if line:match("%S") and #line:match("^ *") <= indent then
                    break
                end
                last = e - 1
                pos = e + 1
            end
            if code:match("^%s*%-?%s*run%s*:") then
                for _, span in ipairs(sh_spans(text:sub(first, last), 1)) do
                    table.insert(spans, {first - 1 + span[1], first - 1 + span[2]})
                end
            end
        end
    end
    return spans
end

function comments(text, lang)
    local marked = false
    for _, marker in ipairs(markers[lang.kind]) do
        marked = marked or text:find(marker, 1, true) ~= nil
    end
    if not marked then
        return {}
    end
    local spans
    if lang.kind == "c" then
        spans = c_comments(text, lang.cpp)
    elseif lang.kind == "swift" then
        spans = swift_comments(text)
    elseif lang.kind == "sh" then
        spans = sh_comments(text)
    elseif lang.kind == "yaml" then
        spans = yaml_comments(text)
    else
        spans = lua_comments(text)
    end
    local header = 0
    local last = 0
    if (lang.kind == "lua" and text:byte(1) == 35) or (lang.kind == "sh" and text:sub(1, 2) == "#!") then
        last = text:find("\n", 1, true) or 0
    end
    for index, span in ipairs(spans) do
        if text:sub(last + 1, span[1] - 1):match("^%s*$") then
            header = index
            last = span[2]
        else
            break
        end
    end
    if header > 0 then
        local block = text:sub(spans[1][1], spans[header][2])
        local islegal = false
        for _, pattern in ipairs(legal) do
            if block:find(pattern) then
                islegal = true
            end
        end
        if islegal then
            spans = table.slice(spans, header + 1)
        end
    end
    return spans
end
