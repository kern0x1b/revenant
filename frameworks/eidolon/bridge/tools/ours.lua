-- ours.lua: the members our module declares, per type, from eidolon/Sources/SwiftUI/*.swift.
--
--     xmake l ours.lua > ours.tsv
--
-- One line per declaration: owner, kind, name, file. A source-level stand-in for the digester dump, used while the
-- module is still building.
--
-- Two things it gets right that it did not before, and both cost a review:
--   * an enum's `case` is a member in every reading - it is written under the enum's name, and Apple declares it as a
--     `case` or a `static`, so it is recorded as all three;
--   * a `typealias` is a declaration of the name it binds, and the thing it binds counts as declared too, so a type we
--     only alias is not reported as one we lack.
--
-- Every regular expression of the Python this replaces is kept above its Lua in a comment; the search is written out
-- as the loop that finds the same match.

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})
local braces = import("lib.braces", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

-- the modules a name may be written with, and which the owner keeps no part of
local MODULES = {Swift = true, SwiftUI = true, SwiftUICore = true, Foundation = true, UIKit = true, Combine = true}

local KINDS = {"struct", "class", "enum", "protocol", "typealias", "actor"}

-- (?:public |internal |private |fileprivate |open |final |@frozen |indirect )*
local PREFIXES = {"public ", "internal ", "private ", "fileprivate ", "open ", "final ", "@frozen ", "indirect "}

-- the lines a member walk does not read: a brace, an accessor, and the words a body is written in
local SKIP = {["{"] = true, ["}"] = true, get = true, set = true, ["get set"] = true, willSet = true, didSet = true}

-- re.match(r'(?:PREFIXES)*KIND\s+(\w+)', s): the kind and the name a line declares at its start, or nil
local function type_head(s)
    local pos = 1
    local moved = true
    while moved do
        moved = false
        for _, prefix in ipairs(PREFIXES) do
            if text.startswith(s, prefix, pos) then
                pos = pos + #prefix
                moved = true
                break
            end
        end
    end
    for _, kind in ipairs(KINDS) do
        if text.startswith(s, kind, pos) then
            local _, space = string.find(s, "^%s+", pos + #kind)
            local name = space and string.match(s, "^[%w_]+", space + 1)
            if name then
                return kind, name
            end
            return nil
        end
    end
    return nil
end

-- re.match(r'extension\s+([\w.]+)', s): the whole extended name, or nil
local function extension_name(s)
    local _, space = string.find(s, "^extension%s+")
    return space and string.match(s, "^[%w_%.]+", space + 1) or nil
end

-- the owner an extension of `extended` is filed under: the whole name, without a module in front of it
local function owner_of(extended)
    local head, rest = string.match(extended, "^([^%.]+)%.(.*)$")
    if head and MODULES[head] then
        return rest
    end
    return extended
end

-- re.findall(r'\bcase ([CLASS]+)$', s), CLASS given as the body of a Lua set: the run after the keyword. The first
-- "case " at a word boundary whose rest is all in the class is the only match, since the rest runs to the end.
local function case_runs(s, class)
    for _, at in ipairs(text.positions(s, "case ")) do
        if text.boundary(s, at) then
            local run = string.sub(s, at + 5)
            if run ~= "" and not string.find(run, "[^" .. class .. "]") then
                return {run}
            end
        end
    end
    return {}
end

-- re.findall(r'\bstatic (?:let|var|func)\s+(\w+)', s): every name, left to right, no match overlapping another
local function static_members(s)
    local names = {}
    local from = 1
    while true do
        local at = string.find(s, "static ", from, true)
        if not at then
            return names
        end
        local matched = false
        if text.boundary(s, at) then
            for _, keyword in ipairs({"let", "var", "func"}) do
                local _, e = string.find(s, "^" .. keyword .. "%s+", at + 7)
                local name = e and string.match(s, "^[%w_]+", e + 1)
                if name then
                    names[#names + 1] = name
                    from = e + #name + 1
                    matched = true
                    break
                end
            end
        end
        if not matched then
            from = at + 1
        end
    end
end

-- re.search(KIND + r'\s+(\w+)', s): the first name a kind keyword is followed by, with no word boundary before it
local function kind_name(s)
    for at = 1, #s do
        for _, kind in ipairs(KINDS) do
            if text.startswith(s, kind, at) then
                local _, space = string.find(s, "^%s+", at + #kind)
                local name = space and string.match(s, "^[%w_]+", space + 1)
                if name then
                    return name
                end
            end
        end
    end
    return nil
end

-- re.search(KIND + r'\s+(\w+)\s*=\s*(\w+)', s): the name the alias binds, which is the second name
local function alias_target(s)
    for at = 1, #s do
        for _, kind in ipairs(KINDS) do
            if text.startswith(s, kind, at) then
                local _, space = string.find(s, "^%s+", at + #kind)
                local name = space and string.match(s, "^[%w_]+", space + 1)
                if name then
                    local _, equals = string.find(s, "^%s*=%s*", space + #name + 1)
                    local target = equals and string.match(s, "^[%w_]+", equals + 1)
                    if target then
                        return target
                    end
                end
            end
        end
    end
    return nil
end

-- re.search(r'\bextension\s+([\w.]+)\s*:\s*(\w+)', s), with the protocol list of the second pattern: the extended name
-- and the list after the colon, or nil. The first pattern needs a word character after the colon and the spaces.
local function conformance(s)
    for _, at in ipairs(text.positions(s, "extension")) do
        if text.boundary(s, at) then
            local _, space = string.find(s, "^%s+", at + 9)
            local extended = space and string.match(s, "^[%w_%.]+", space + 1)
            local colon = nil
            if extended then
                local _, found = string.find(s, "^%s*:", space + #extended + 1)
                colon = found
            end
            if colon then
                local _, spaces = string.find(s, "^%s*", colon + 1)
                if string.find(string.sub(s, spaces + 1, spaces + 1), "^[%w_]") then
                    return extended, string.match(s, "^[%w_, ]+", spaces + 1)
                end
            end
        end
    end
    return nil
end

-- the declarations of one interface-free file, appended to out as {owner, kind, name, file}
local function scan(file, out)
    local base = path.filename(file)
    local add = function(owner, kind, name)
        out[#out + 1] = {owner = owner, kind = kind, name = name, file = base}
    end
    local depth = 0
    local owner = nil
    local in_block, in_multiline, hashes = false, false, 0
    for _, line in ipairs(text.split(io.readfile(file), "\n")) do
        local s = text.strip(line)
        if depth == 0 then
            local kind, name = type_head(s)
            if kind then
                owner = name
                add(owner, "type", name)
                -- a one-line type body - `enum X { case a, b }` - is all on this line, so its members are read here
                -- and not at depth one, which it never reaches
                local open = string.find(s, "{", 1, true)
                if open and string.find(string.sub(s, open + 1), "}", 1, true) then
                    local close = nil
                    local from = 1
                    while true do
                        local at = string.find(s, "}", from, true)
                        if not at then
                            break
                        end
                        close = at
                        from = at + 1
                    end
                    local inline = string.sub(s, open + 1, close - 1)
                    -- re.findall(r'\bcase ([\w,` ]+)$', inline.strip())
                    for _, run in ipairs(case_runs(text.strip(inline), "%w_,` ")) do
                        for _, part in ipairs(text.split(run, ",")) do
                            if text.strip(part) ~= "" then
                                local name_in_case = string.gsub(text.strip(part), "^`+", "")
                                name_in_case = string.gsub(name_in_case, "`+$", "")
                                add(owner, "const", name_in_case)
                                add(owner, "var", name_in_case)
                                add(owner, "func", name_in_case)
                            end
                        end
                    end
                    for _, name_in_static in ipairs(static_members(inline)) do
                        add(owner, "var", name_in_static)
                    end
                    local target = alias_target(inline)
                    if target then
                        add(owner, "type", target)
                    end
                end
            else
                local extended = extension_name(s)
                if extended then
                    owner = owner_of(extended)
                else
                    owner = nil
                end
            end
        elseif extension_name(s) then
            -- An `extension` line opens a new section wherever it stands, and the walk reaches it at whatever depth
            -- the file has drifted to - TextModifiers.swift:168 is one.
            owner = owner_of(extension_name(s))
        elseif owner and owner ~= "" and s ~= "" and not text.startswith(s, "//") and not SKIP[s] then
            local body = s
            local brace = string.find(s, "{", 1, true)
            if brace then
                body = string.sub(s, 1, brace - 1)
            end
            local conformed, protocols = conformance(s)
            local func_name = text.name_after(body, "func ")
            if func_name then
                add(owner, "func", func_name)
            elseif text.has_word(body, "init") then
                add(owner, "init", "init")
            elseif text.name_after(body, "var ") then
                add(owner, "var", text.name_after(body, "var "))
            elseif text.name_after(body, "let ") then
                add(owner, "var", text.name_after(body, "let "))
            elseif text.name_after(body, "case ") then
                -- Apple's declares a case as a `case` or as a `static`, so it counts as either, and a case list on
                -- one line is every name in it, not only the first
                for _, run in ipairs(case_runs(text.strip(body), "%w_, ")) do
                    for _, part in ipairs(text.split(run, ",")) do
                        local name_in_case = text.strip(part)
                        if name_in_case ~= "" then
                            add(owner, "const", name_in_case)
                            add(owner, "var", name_in_case)
                            add(owner, "func", name_in_case)
                        end
                    end
                end
            elseif conformed then
                -- a conformance declares what the compiler synthesises from it, and no line of ours shows those
                -- members: Hashable is hash(into:) and hashValue, Equatable is ==
                -- the whole extended name without its module: a member of `Anchor.Source` belongs to `Anchor.Source`
                owner = owner_of(conformed)
                if string.find(protocols, "Hashable", 1, true) then
                    add(owner, "func", "hash")
                    add(owner, "var", "hashValue")
                end
                if string.find(protocols, "Equatable", 1, true) then
                    add(owner, "func", "==")
                end
            elseif text.has_word(body, "subscript") then
                add(owner, "subscript", "subscript")
            else
                local type_name = kind_name(body)
                if type_name then
                    add(owner, "type", type_name)
                end
            end
        end
        local opened, closed
        opened, closed, in_block, in_multiline, hashes = braces.braces(s, in_block, in_multiline, hashes)
        depth = depth + opened - closed
        if depth == 0 then
            owner = nil
        end
    end
end

-- every declaration of the module's sources, in file order, each file in sorted order
function collect(root)
    local files = os.files(path.join(root, "eidolon", "Sources", "SwiftUI", "*.swift"))
    table.sort(files)
    local out = {}
    for _, file in ipairs(files) do
        scan(file, out)
    end
    return out
end

function main(...)
    local root = path.join(os.scriptdir(), "..", "..")
    for _, row in ipairs(collect(root)) do
        print(row.owner .. "\t" .. row.kind .. "\t" .. row.name .. "\t" .. row.file)
    end
end
