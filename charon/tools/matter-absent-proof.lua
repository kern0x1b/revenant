-- The proof behind the removal of the generated Matter classes (v-matter11).
--
-- Every row of the apple-backports Matter registry whose owner is one of the generated classes (class-overlap.tsv
-- says yes), and that the SDK 26.2 corpus does not carry at all, is classified against the SDK 26.2 Matter headers.
-- The owner's own @interface blocks and its categories are read, the block only: a member is looked for in those
-- blocks, then in the superclass chain, and never in another block of the same name.
--
--   a            unavailable: the declaration, or the @interface or category that encloses it, carries one of
--                UNAVAILABLE_MARKS. MTR_PROVISIONALLY_AVAILABLE and MTR_UNSTABLE_API expand to _MTR_UNAVAILABLE
--                unless the client opts in (MTRDefines.h:94-102); NS_UNAVAILABLE and API_UNAVAILABLE are explicit.
--                A superclass that declares the member unavailable makes it unavailable for the owner too.
--   b            inherited: the owner's blocks do not declare the member, a superclass declares it available. The
--                row belongs to that superclass; it is homed when the superclass's own row is in the real registry.
--   b-homeless   inherited and available, but the superclass's row is not in the real registry: the removal stops.
--   p            the accessor (-[Class name], -[Class setName:]) of a property the owner's blocks declare available; the
--                corpus spells that surface as the property row Class.name, which is available and in the real registry.
--   c            declared nowhere: no owner or superclass block in the Matter headers declares it.
--   x            declared available in the owner's own blocks and absent from the corpus: not a brief category, and
--                the removal stops on it.
--
-- Usage: xmake l tools/matter-absent-proof.lua <registry.json> <class-overlap.tsv> <corpus.tsv> <Headers dir>
--        <real registry dir> <out.tsv>
-- The output is one row per absent row: category, kind, api, owner, where (header:line of the declaration), detail.
import("core.base.json")

local UNAVAILABLE_MARKS = {"MTR_PROVISIONALLY_AVAILABLE", "MTR_UNSTABLE_API", "NS_UNAVAILABLE", "API_UNAVAILABLE"}
local UNAVAILABLE = {}
for _, mark in ipairs(UNAVAILABLE_MARKS) do
    UNAVAILABLE[mark] = true
end

-- Block comments become spaces (line numbers survive), line comments and preprocessor lines go.
local function strip(text)
    text = text:gsub("/%*.-%*/", function(comment)
        return (comment:gsub("[^\n]", " "))
    end)
    text = text:gsub("//[^\n]*", "")
    text = text:gsub("\n[ \t]*#[^\n]*", "\n")
    return text
end

-- Tokens with their line numbers: identifiers, @keywords, numbers, and single punctuation characters.
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

-- The index of the ')' that closes the '(' at st[j].
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

-- A member declaration's kind, key and unavailable mark, read from its tokens: a method gives sign and selector
-- (the return type group and the parameter types and names are skipped), a property gives its name, which is the
-- last identifier before the trailing availability macros.
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

-- The @interface blocks of one header: the name, the superclass or the category, the unavailable mark on the
-- @interface line (the tokens since the last ';', '@end' or '}'), and the members by key.
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
                    -- a custom getter, getter=name in the attributes, is the property's own accessor method
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

-- The declarations of one member in one block, each with the block's own mark applied.
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

-- The property a method row names, when the row is its accessor: the getter -[Class name] or the setter
-- -[Class setName:], which is how the generator spells a property the SDK declares.
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

-- The declarations of a row's member on one class: a method as a method, and failing that as the accessor of a
-- property of the same name.
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
    -- the 1188 generated classes
    local generated = {}
    for index, line in ipairs(read_lines(overlap_path)) do
        local name, verdict = line:match("^([^\t]+)\t([^\t]+)")
        if index > 1 and verdict == "yes" then
            generated[name] = true
        end
    end

    -- the corpus: every Matter row by kind and api, with its unavailable column (the value is "yes" for an
    -- unavailable row, and "" otherwise)
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

    -- the real registry: every api it carries, any kind
    local real = {}
    for _, file in ipairs(os.files(path.join(realdir, "*.json"))) do
        for _, entry in ipairs(json.decode(io.readfile(file)).entries) do
            real[entry.api] = true
        end
    end

    local index = load_headers(headers)

    -- every member any block of the headers declares, by its key, to tell a member declared on another class
    -- (a selector the generator copied to the wrong owner) from one no block declares at all
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
                            -- the accessor of a property the SDK declares available is the property's own surface:
                            -- the corpus spells it as Class.name, and the real registry must carry that row
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
