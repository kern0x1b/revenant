import("core.base.json")

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

local function parse(file, text)
    local toks, lines = tokenize(strip(text))
    local blocks, block, since = {}, nil, {}
    local st, st_line, depth, braces = nil, nil, 0, 0
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
                    local list = kind == "property" and block.props or block.methods
                    list[key] = list[key] or {}
                    table.insert(list[key], {line = st_line, mark = mark})
                    for k, tok in ipairs(st) do
                        if kind == "property" and tok == "getter" and st[k + 1] == "=" and is_ident(st[k + 2]) then
                            block.methods["- " .. st[k + 2]] = block.methods["- " .. st[k + 2]] or {}
                            table.insert(block.methods["- " .. st[k + 2]], {line = st_line, mark = mark, prop = key})
                        end
                    end
                end
                st = nil
            else
                st[#st + 1] = t
            end
        elseif block == nil then
            if t == "@interface" then
                block = {file = file, line = lines[i], name = toks[i + 1], methods = {}, props = {}}
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
            st, st_line, depth = {t}, lines[i], 0
        end
        i = i + 1
    end
    return blocks
end

local function load_headers(dir)
    local index = {byname = {}, classes = {}}
    for _, file in ipairs(os.files(path.join(dir, "*.h"))) do
        for _, block in ipairs(parse(path.filename(file), io.readfile(file))) do
            index.byname[block.name] = index.byname[block.name] or {}
            table.insert(index.byname[block.name], block)
            if not block.category and not index.classes[block.name] then
                index.classes[block.name] = block
            end
        end
    end
    return index
end

local function decls_in(block, key, props)
    local out = {}
    for _, d in ipairs((props and block.props or block.methods)[key] or {}) do
        out[#out + 1] = {file = block.file, line = d.line, mark = d.mark or block.mark, prop = d.prop}
    end
    return out
end

local function member_decls(index, owner, key, props)
    local out = {}
    for _, block in ipairs(index.byname[owner] or {}) do
        for _, d in ipairs(decls_in(block, key, props)) do
            out[#out + 1] = d
        end
    end
    return out
end

local function accessor_of(sign, sel)
    if sign ~= "-" then
        return nil
    end
    if sel:match("^[%a_][%w_]*$") then
        return sel
    end
    local rest = sel:match("^set(%u[%w_]*):$")
    if rest then
        return rest:sub(1, 1):lower() .. rest:sub(2)
    end
    return nil
end

local function class_decls(index, owner, sign, sel, name)
    if name then
        return member_decls(index, owner, name, true), name
    end
    local decls = member_decls(index, owner, sign .. " " .. sel, false)
    if #decls > 0 then
        return decls, decls[1].prop
    end
    local prop = accessor_of(sign, sel)
    if prop then
        return member_decls(index, owner, prop, true), prop
    end
    return decls, nil
end

local function read_lines(file)
    local out = {}
    for line in io.lines(file) do
        out[#out + 1] = line
    end
    return out
end

function main(registry_path, overlap_path, corpus_path, headers, realdir, outfile)
    local generated = {}
    for index, line in ipairs(read_lines(overlap_path)) do
        local name, verdict = line:match("^([^\t]+)\t([^\t]+)")
        if index > 1 and verdict == "yes" then
            generated[name] = true
        end
    end

    local corpus = {}
    for index, line in ipairs(read_lines(corpus_path)) do
        local cells = {}
        for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
            cells[#cells + 1] = cell
        end
        if index > 1 and cells[1] == "Matter" then
            corpus[cells[2] .. " " .. cells[4]] = cells[8]
        end
    end

    local real = {}
    for _, file in ipairs(os.files(path.join(realdir, "*.json"))) do
        for _, entry in ipairs(json.decode(io.readfile(file)).entries) do
            real[entry.api] = true
        end
    end

    local index = load_headers(headers)

    local everywhere = {}
    for _, blocks in pairs(index.byname) do
        for _, block in ipairs(blocks) do
            for key in pairs(block.methods) do
                everywhere["M " .. key] = true
            end
            for key in pairs(block.props) do
                everywhere["P " .. key] = true
            end
        end
    end

    local rows, counts = {}, {}
    local total, present = 0, 0
    local registry = json.decode(io.readfile(registry_path))
    for _, entry in ipairs(registry.entries) do
        local kind, api = entry.kind, entry.api
        local owner, sign, sel, name
        if kind == "class" then
            owner = api
        elseif kind == "method" then
            sign, owner, sel = api:match("^([-+])%[(%S+) (.+)%]$")
        elseif kind == "property" then
            owner, name = api:match("^([%w_]+)%.([%w_]+)$")
        end
        if owner and generated[owner] then
            total = total + 1
            if corpus[kind .. " " .. api] then
                present = present + 1
            else
                local category, mark, where, detail = "x", nil, "", ""
                if kind == "class" then
                    local block = index.classes[owner]
                    if not block then
                        category = "c"
                    else
                        where = block.file .. ":" .. block.line
                        category = block.mark and "a" or "x"
                        mark = block.mark
                    end
                else
                    local decls, prop = class_decls(index, owner, sign, sel, name)
                    local chain, walked = nil, {}
                    if #decls == 0 then
                        local seen = {[owner] = true}
                        local block = index.classes[owner]
                        local super = block and block.super
                        while super and not seen[super] and #decls == 0 do
                            seen[super] = true
                            walked[#walked + 1] = super
                            decls, prop = class_decls(index, super, sign, sel, name)
                            if #decls > 0 then
                                chain = super
                            end
                            block = index.classes[super]
                            super = block and block.super
                        end
                    end
                    if #decls == 0 then
                        category = "c"
                        local elsewhere = (everywhere["M " .. (sign or "") .. " " .. (sel or "")]
                            or everywhere["P " .. (name or accessor_of(sign, sel) or "")]) and "yes" or "no"
                        detail = "walked " .. (#walked > 0 and table.concat(walked, ">") or owner)
                            .. "; same member in another block=" .. elsewhere
                    else
                        local open, shut
                        for _, d in ipairs(decls) do
                            if d.mark then
                                shut = shut or d
                            else
                                open = open or d
                            end
                        end
                        local first = decls[1]
                        where = first.file .. ":" .. first.line
                        if chain then
                            detail = "inherited from " .. chain
                        end
                        if open and not chain then
                            category = "x"
                            local pname = prop and owner .. "." .. prop
                            local cell = pname and corpus["property " .. pname]
                            if cell and real[pname] and cell ~= "yes" then
                                category = "p"
                                detail = "accessor of " .. pname
                            end
                        elseif open then
                            local super_api
                            if kind == "property" then
                                super_api = chain .. "." .. name
                            else
                                super_api = sign .. "[" .. chain .. " " .. sel .. "]"
                            end
                            local homed = real[super_api] or (prop and real[chain .. "." .. prop])
                            category = homed and "b" or "b-homeless"
                            detail = detail .. " homed=" .. (homed and "yes" or "no")
                        else
                            category = "a"
                            mark = shut.mark
                            where = shut.file .. ":" .. shut.line
                        end
                    end
                end
                if mark then
                    detail = (mark) .. (detail ~= "" and "; " .. detail or "")
                end
                rows[#rows + 1] = {category, kind, api, owner, where, detail}
                counts[category] = (counts[category] or 0) + 1
                counts[category .. " " .. kind] = (counts[category .. " " .. kind] or 0) + 1
                if mark then
                    counts["mark " .. mark] = (counts["mark " .. mark] or 0) + 1
                end
            end
        end
    end

    local out = {"category\tkind\tapi\towner\twhere\tdetail"}
    for _, row in ipairs(rows) do
        out[#out + 1] = table.concat(row, "\t")
    end
    local file = assert(io.open(outfile, "w"))
    file:write(table.concat(out, "\n") .. "\n")
    file:close()

    print(string.format("generated-owned rows %d, in the corpus %d, absent %d", total, present, #rows))
    for _, key in ipairs({"a", "b", "b-homeless", "p", "c", "x"}) do
        print(string.format("%-12s %5d   class %4d  method %5d  property %5d", key, counts[key] or 0,
            counts[key .. " class"] or 0, counts[key .. " method"] or 0, counts[key .. " property"] or 0))
    end
    for key, value in pairs(counts) do
        if key:match("^mark ") then
            print(string.format("%-40s %5d", key, value))
        end
    end
end
