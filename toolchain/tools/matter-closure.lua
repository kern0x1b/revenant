import("byteorder", {rootdir = path.join(os.scriptdir(), "..", "modules")})
local matter_text = import("matter-text", {rootdir = os.scriptdir(), anonymous = true})

local UNAVAILABLE_MARKS = {"MTR_PROVISIONALLY_AVAILABLE", "MTR_UNSTABLE_API", "NS_UNAVAILABLE", "API_UNAVAILABLE"}
local UNAVAILABLE = {}
for _, mark in ipairs(UNAVAILABLE_MARKS) do
    UNAVAILABLE[mark] = true
end

local function strip(text)
    text = text:gsub("/%*.-%*/", function(comment)
        return (comment:gsub("[^\n]", " "))
    end)
    text = text:gsub("//[^\n]*", "")
    text = text:gsub("\n[ \t]*#[^\n]*", "\n")
    return text
end

local function tokenize(text)
    local toks, lines = {}, {}
    local line, i, n = 1, 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c == "\n" then
            line = line + 1
            i = i + 1
        elseif c:match("%s") then
            i = i + 1
        elseif c == '"' then
            local close = text:find('"', i + 1, true) or n
            for _ in text:sub(i, close):gmatch("\n") do
                line = line + 1
            end
            i = close + 1
        else
            local word = text:match("^@[%a_][%w_]*", i) or text:match("^[%a_][%w_]*", i) or text:match("^%d[%w%.]*", i)
            if word then
                toks[#toks + 1] = word
                lines[#lines + 1] = line
                i = i + #word
            else
                toks[#toks + 1] = c
                lines[#lines + 1] = line
                i = i + 1
            end
        end
    end
    return toks, lines
end

local function is_ident(token)
    return token ~= nil and token:match("^[%a_][%w_]*$") ~= nil
end

local function skip_group(st, j)
    local depth = 0
    for k = j, #st do
        if st[k] == "(" then
            depth = depth + 1
        elseif st[k] == ")" then
            depth = depth - 1
            if depth == 0 then
                return k
            end
        end
    end
    return #st
end

local function read_member(st)
    local mark
    for _, t in ipairs(st) do
        if UNAVAILABLE[t] then
            mark = mark or t
        end
    end
    if st[1] == "@property" then
        local j = 2
        if st[j] == "(" then
            j = skip_group(st, j) + 1
        end
        local name, depth = nil, 0
        for k = j, #st do
            local t = st[k]
            if t == "(" then
                depth = depth + 1
            elseif t == ")" then
                depth = depth - 1
            elseif depth == 0 and (t:match("^MTR_") or t:match("^NS_") or t:match("^API_")) then
                break
            elseif depth == 0 and is_ident(t) then
                name = t
            end
        end
        return "property", name, mark
    end
    local sign, j = st[1], 2
    if st[j] ~= "(" then
        return nil
    end
    j = skip_group(st, j) + 1
    local sel = ""
    while j <= #st do
        local t = st[j]
        if is_ident(t) and st[j + 1] == ":" then
            sel = sel .. t .. ":"
            j = j + 2
            if st[j] == "(" then
                j = skip_group(st, j) + 1
            end
            if is_ident(st[j]) then
                j = j + 1
            end
        elseif sel == "" and is_ident(t) then
            sel = t
            break
        else
            break
        end
    end
    if sel == "" then
        return nil
    end
    return "method", sign .. " " .. sel, mark
end

local function typedef_name(td)
    for k = 1, #td - 2 do
        if td[k] == "^" and is_ident(td[k + 1]) and td[k + 2] == ")" then
            return td[k + 1]
        end
    end
    local name, depth = nil, 0
    for k = 1, #td do
        local t = td[k]
        if t == "(" or t == "{" then
            depth = depth + 1
        elseif t == ")" or t == "}" then
            depth = depth - 1
        elseif depth == 0 and is_ident(t) then
            name = t
        end
    end
    return name
end

local function parse(file, text)
    local toks, lines = tokenize(strip(text))
    local blocks, typedefs = {}, {}
    local block, since = nil, {}
    local st, depth, braces = nil, 0, 0
    local td, tbraces, tparens = nil, 0, 0
    local i, n = 1, #toks
    while i <= n do
        local t = toks[i]
        if st then
            if t == "(" or t == "[" then
                depth = depth + 1
            elseif t == ")" or t == "]" then
                depth = depth - 1
            end
            if t == ";" and depth <= 0 then
                local kind, key, mark = read_member(st)
                if kind and key then
                    table.insert(block.members, {kind = kind, key = key, mark = mark, toks = st})
                end
                st = nil
            else
                st[#st + 1] = t
            end
        elseif td then
            td[#td + 1] = t
            if t == "{" then
                tbraces = tbraces + 1
            elseif t == "}" then
                tbraces = tbraces - 1
            elseif t == "(" then
                tparens = tparens + 1
            elseif t == ")" then
                tparens = tparens - 1
            elseif t == ";" and tbraces == 0 and tparens == 0 then
                local name = typedef_name(td)
                if name then
                    typedefs[name] = typedefs[name] or td
                end
                td = nil
            end
        elseif block == nil then
            if t == "typedef" then
                td, tbraces, tparens = {t}, 0, 0
            elseif t == "@interface" then
                block = {file = file, line = lines[i], name = toks[i + 1], members = {}}
                if toks[i + 2] == "(" then
                    block.category = toks[i + 3]
                elseif toks[i + 2] == ":" then
                    block.super = toks[i + 3]
                end
                for _, s in ipairs(since) do
                    if UNAVAILABLE[s] then
                        block.mark = block.mark or s
                    end
                end
                since, braces = {}, 0
            elseif t == "@end" or t == ";" or t == "}" then
                since = {}
            else
                since[#since + 1] = t
            end
        elseif t == "@end" then
            blocks[#blocks + 1] = block
            block, since = nil, {}
        elseif t == "{" then
            braces = braces + 1
        elseif t == "}" then
            braces = braces - 1
        elseif braces == 0 and (t == "-" or t == "+" or t == "@property") then
            st, depth = {t}, 0
        end
        i = i + 1
    end
    return blocks, typedefs
end

local function read_lines(file)
    local out = {}
    for line in io.lines(file) do
        out[#out + 1] = line
    end
    return out
end

local function load_headers(dir)
    local classes, typedefs = {}, {}
    for _, file in ipairs(os.files(path.join(dir, "*.h"))) do
        local blocks, tds = parse(path.filename(file), io.readfile(file))
        local names = {}
        for name in pairs(tds) do
            names[#names + 1] = name
        end
        table.sort(names, byteorder.less)
        for _, name in ipairs(names) do
            typedefs[name] = typedefs[name] or tds[name]
        end
        for _, block in ipairs(blocks) do
            local entry = classes[block.name]
            if not entry then
                entry = {members = {}, defined = false}
                classes[block.name] = entry
            end
            if not block.category then
                if not entry.defined then
                    entry.defined = true
                    entry.super = block.super
                    entry.mark = block.mark
                    entry.file = block.file
                    entry.line = block.line
                end
            end
            for _, m in ipairs(block.members) do
                m.blockmark = block.mark
                table.insert(entry.members, m)
            end
        end
    end
    return classes, typedefs
end

local function classes_in(toks, classes, typedefs, out, seen)
    for _, t in ipairs(toks) do
        if classes[t] and classes[t].defined then
            out[t] = true
        elseif typedefs[t] and not seen[t] then
            seen[t] = true
            classes_in(typedefs[t], classes, typedefs, out, seen)
        end
    end
    return out
end

local function member_api(owner, m)
    if m.kind == "property" then
        return owner .. "." .. m.key
    end
    return m.key:sub(1, 1) .. "[" .. owner .. " " .. m.key:sub(3) .. "]"
end

function main(headers, overlap_path, corpus_path, outfile)
    local classes, typedefs = load_headers(headers)

    local overlap_text = io.readfile(overlap_path)
    local input, real = {}, {}
    local first = true
    for line in overlap_text:gmatch("[^\n]+") do
        if first then
            first = false
        else
            local cells = matter_text.cells_of(line)
            input[#input + 1] = cells[1]
            real[cells[1]] = cells[2]
        end
    end
    table.sort(input, byteorder.less)

    local roots, corpus_rows, not_in_headers, provisional = {}, 0, 0, 0
    for index, line in ipairs(read_lines(corpus_path)) do
        local cells = matter_text.cells_of(line)
        if index > 1 and cells[1] == "Matter" and cells[2] == "class" then
            corpus_rows = corpus_rows + 1
            local name = cells[4]
            local entry = classes[name]
            if not entry or not entry.defined then
                not_in_headers = not_in_headers + 1
            elseif entry.mark then
                provisional = provisional + 1
            else
                roots[#roots + 1] = name
            end
        end
    end
    table.sort(roots, byteorder.less)

    local reason = {}
    local queue, head = {}, 1
    for _, name in ipairs(roots) do
        if not reason[name] then
            reason[name] = "root: corpus class row, not provisional"
            queue[#queue + 1] = name
        end
    end
    local edges = 0
    while head <= #queue do
        local owner = queue[head]
        head = head + 1
        local entry = classes[owner]
        if entry.super and classes[entry.super] and classes[entry.super].defined and not reason[entry.super] then
            reason[entry.super] = owner .. " -> superclass -> " .. entry.super
            queue[#queue + 1] = entry.super
            edges = edges + 1
        end
        local members = {}
        for _, m in ipairs(entry.members) do
            m.api = member_api(owner, m)
            table.insert(members, m)
        end
        table.sort(members, function(a, b) return byteorder.less(a.api, b.api) end)
        for _, m in ipairs(members) do
            if not (m.mark or m.blockmark) then
                local targets = classes_in(m.toks, classes, typedefs, {}, {})
                local names = {}
                for name in pairs(targets) do
                    if name ~= owner then
                        names[#names + 1] = name
                    end
                end
                table.sort(names, byteorder.less)
                for _, name in ipairs(names) do
                    if not reason[name] then
                        reason[name] = owner .. " -> " .. m.api .. " -> " .. name
                        queue[#queue + 1] = name
                        edges = edges + 1
                    end
                end
            end
        end
    end

    local texts = {}
    for _, file in ipairs(os.files(path.join(headers, "*.h"))) do
        texts[#texts + 1] = path.filename(file) .. "\0" .. io.readfile(file)
    end
    table.sort(texts, byteorder.less)
    local corpus_text = io.readfile(corpus_path)
    local stamp = "# inputs: class-overlap.tsv " .. matter_text.digest(overlap_text) .. "; corpus " .. matter_text.digest(corpus_text)
        .. "; headers " .. matter_text.digest(table.concat(texts))

    local rows = {stamp, "class\treal-stack\tin-closure\treason\temit"}
    local counts = {emit = 0, closure = 0, real_no = 0}
    for _, name in ipairs(input) do
        local in_closure = reason[name] and "yes" or "no"
        local emit = (real[name] == "no" and in_closure == "yes") and "yes" or "no"
        if in_closure == "yes" then counts.closure = counts.closure + 1 end
        if real[name] == "no" then counts.real_no = counts.real_no + 1 end
        if emit == "yes" then counts.emit = counts.emit + 1 end
        rows[#rows + 1] = table.concat({name, real[name], in_closure, reason[name] or "none", emit}, "\t")
    end

    local file = assert(io.open(outfile, "w"))
    file:write(table.concat(rows, "\n") .. "\n")
    file:close()

    local header_classes, reached = 0, 0
    for _, entry in pairs(classes) do
        if entry.defined then header_classes = header_classes + 1 end
    end
    for _ in pairs(reason) do
        reached = reached + 1
    end
    print(string.format("header classes %d; corpus class rows %d: roots %d, provisional %d, not in headers %d",
        header_classes, corpus_rows, #roots, provisional, not_in_headers))
    print(string.format("closure %d classes (%d edges); generator input %d: real-stack no %d, in closure %d, emit %d",
        reached, edges, #input, counts.real_no, counts.closure, counts.emit))
end
