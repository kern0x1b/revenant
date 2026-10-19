-- The header facts of one framework, read from the committed declaration shards (design-foundation.md 5.7): no header is parsed
-- here and no other program is run. The shards are written by the extractor (tools/found/ir.lua), which is the one reader of SDK
-- headers. Output of shard_facts, grouped by kind:
--   members:      a list of {cls, kind, api, alias, decl, avail, ...}, the members of the framework's iOS view, with the typed fields
--   functions:    name -> {type, params}, the C functions
--   declared:     a set of the typedef, class and protocol names the iOS build sees
--   typedefs:     name -> the text the typedef is defined as
--   superclasses: class -> the superclass its @interface names
-- Tests inject their facts through use().

local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})

local injected = nil
-- The typedef index and the declared names of the tree, read once per tree (the shards are read once per process).
local typedef_memo = {}
local declared_memo = {}

-- Makes shard_facts(...), typedef_index(...) and declared_names(...) answer from source(fw, sdk) instead of the shards. For tests,
-- which must not read a tree. source returns the kinds of facts, and members may carry the typed fields (type, params, attrs) that
-- shard_facts reads; functions is name -> {type, params}.
function use(source)
    injected = source
end

-- The rows of a shard file (its columns come from its own header line, columns=...), each a record keyed by the column names, so a
-- column added to the shards is read by name. kinds (a set, or nil for all) keeps only the rows of those kinds, read before the
-- row is split. A missing file has no rows.
local function read_rows(file, kinds)
    local out = {}
    -- the whole file at once and the lines found in it: a shard is up to 8 MB, and a line at a time through the file object cost a
    -- Lua call each (290,000 for a `gen --all`)
    local text = files.read_text(file)
    if text == nil then
        return out
    end
    local find, sub = string.find, string.sub
    local columns, count = nil, 0
    for line in string.gmatch(text, "[^\n]+") do
        if sub(line, 1, 1) == "#" then
            local names = string.match(line, "columns=([^\t]*)")
            if names then
                columns, count = {}, 0
                for name in string.gmatch(names, "[^,]+") do
                    count = count + 1
                    columns[count] = name
                end
            end
        elseif columns and (kinds == nil or kinds[string.match(line, "^[^\t]*")]) then
            -- the cells, each under its column's name; a cell beyond the columns is ignored, a missing one is nil
            local row, index, position = {}, 1, 1
            while index <= count do
                local tab = find(line, "\t", position, true)
                if tab == nil then
                    row[columns[index]] = sub(line, position)
                    break
                end
                row[columns[index]] = sub(line, position, tab - 1)
                position = tab + 1
                index = index + 1
            end
            table.insert(out, row)
        end
    end
    return out
end

-- The declaration shard of a framework: tree/packages/a/apple-backports/spec/<F>/declarations.tsv (a nested framework's is
-- spec/<Outer>/<Inner>/declarations.tsv).
local function shard_path(tree, fw)
    return path.join(tree, layout.constants().SNAP_ROOT, fw, "declarations.tsv")
end

-- The rows of one framework's committed declaration shard (design-foundation.md 5.7), by the column names. A framework with no shard has
-- no rows.
function shard_records(tree, fw)
    return read_rows(shard_path(tree, fw), nil)
end

-- The rows of a shard that declare a value: a variable or an enum constant. Only these rows are split (read_rows takes the kind before
-- the row is split), which is what a constant's declaration hash and value are looked up from.
local VALUE_KINDS = {var = true, enumconst = true}

function shard_value_records(tree, fw)
    return read_rows(shard_path(tree, fw), VALUE_KINDS)
end

-- The name a shard row gives (the USR's, or the stored cell).
local function row_name(shard, r)
    return (shard.decode(r.kind, r.usr, r.name or "", r.side or ""))
end

-- The shards of every framework of the tree, in name order, nested frameworks included.
local function shard_files(tree)
    local found = {}
    for _, pattern in ipairs({"*", "*/*"}) do
        for _, filepath in ipairs(files.glob(path.join(tree, layout.constants().SNAP_ROOT, pattern, "declarations.tsv"))) do
            table.insert(found, filepath)
        end
    end
    table.sort(found, order.less)
    return found
end

-- The facts of one framework read from its committed declaration shard (design-foundation.md 5.7), beside the parser's facts
-- above: members (the class members, with the IR's availability fields, the availability text rendered by the foundation's
-- renderer, the declaration hash, and the typed fields type, params and attrs), functions (name -> {type, params}, the C functions),
-- declared names, typedef names, superclasses, conformances (class or protocol -> the protocols it conforms to, in the shard's order)
-- and protocol_members (Protocol.property -> true: a protocol's properties, which are not members of a class). Read through the foundation's shard reader and renderer under tree/tools/found.
function shard_facts(tree, fw)
    local out = {members = {}, declared = {}, typedefs = {}, superclasses = {}, functions = {}, conformances = {},
                 protocol_members = {}}
    if injected then
        local source = injected(fw, nil)
        for key, value in pairs(source) do
            out[key] = value
        end
        out.members = out.members or {}
        out.declared = out.declared or {}
        out.typedefs = out.typedefs or {}
        out.superclasses = out.superclasses or {}
        out.functions = out.functions or {}
        out.conformances = out.conformances or {}
        out.protocol_members = out.protocol_members or {}
        return out
    end
    local records = shard_records(tree, fw)
    if #records == 0 then
        return out
    end
    local shard = import("found.shard", {rootdir = path.join(tree, "tools"), anonymous = true})
    local avail = import("found.avail", {rootdir = path.join(tree, "tools"), anonymous = true})
    local entities = {var = true, ["function"] = true, enum = true, struct = true, union = true, enumconst = true,
                      interface = true, protocol = true}
    local rendered = {}
    for _, r in ipairs(records) do
        local name, side = shard.decode(r.kind, r.usr, r.name or "", r.side or "")
            -- a class property is "+" (design-foundation.md 3.5): its USR carries the class part (cpy); the shard stores no side for it
            if r.kind == "property" and string.find(r.usr, "(cpy)", 1, true) then
                side = "+"
            end
        -- a protocol's property is declared by the protocol, not by a class: its name is recorded for the classes that conform to it
        if r.kind == "property" then
            local protocol = string.match(r.usr, "^c:objc%(pl%)([^%(]+)")
            if protocol then
                out.protocol_members[protocol .. "." .. name] = true
            end
        end
        if r.kind == "method" or r.kind == "property" then
            local cls = string.match(r.usr, "^c:objc%(cs%)([^%(]+)")
            if cls then
                -- a class property takes the sign of a class method ("+"): the side the shard records (design-foundation.md 3.5)
                local api = side .. "[" .. cls .. " " .. name .. "]"
                local alias = r.kind == "method" and api or (cls .. "." .. name)
                -- most members of a framework share one availability: the text is rendered once for each distinct pair
                local rendered_key = r.availability .. "\31" .. (r.message or "")
                local text = rendered[rendered_key]
                if text == nil then
                    text = avail.render(r.availability, r.message)
                    rendered[rendered_key] = text
                end
                table.insert(out.members, {cls = cls, kind = r.kind, api = api, alias = alias, availability = r.availability,
                                           message = r.message, text = text,
                                           type = r.type, params = r.params, attrs = r.attrs, hash = r.declhash, usr = r.usr,
                                           key = r.container})
            end
        elseif r.kind == "typedef" then
            out.typedefs[name] = r.type
        elseif r.kind == "super" then
            out.superclasses[r.container] = name
        elseif r.kind == "conforms" then
            -- a conforms row names a protocol (its name column) that its container conforms to
            out.conformances[r.container] = out.conformances[r.container] or {}
            table.insert(out.conformances[r.container], r.name)
        elseif entities[r.kind] then
            out.declared[name] = true
            if r.kind == "function" then
                out.functions[name] = {type = r.type, params = r.params, usr = r.usr}
            end
        end
    end
    return out
end

-- The typedef index of the whole SDK: each typedef name -> the underlying type its shard row gives (a typedef of two frameworks keeps
-- the first, in name order). Read once per tree. With a source injected, the framework's own typedefs of the source.
function typedef_index(tree, fw)
    if injected then
        return injected(fw, nil).typedefs or {}
    end
    if typedef_memo[tree] == nil then
        local shard = import("found.shard", {rootdir = path.join(tree, "tools"), anonymous = true})
        local index = {}
        for _, filepath in ipairs(shard_files(tree)) do
            for _, r in ipairs(read_rows(filepath, {typedef = true})) do
                local name = row_name(shard, r)
                if r.type and r.type ~= "-" and index[name] == nil then
                    index[name] = r.type
                end
            end
        end
        typedef_memo[tree] = index
    end
    return typedef_memo[tree]
end

-- True when an availability text (the shard's column) has the platform unavailable: its ios entry's last field is 1.
local function ios_unavailable(availability)
    for entry in string.gmatch(availability or "", "[^,]+") do
        local value = string.match(entry, "^ios=(.*)$")
        if value and string.match(value, "[^/]*$") == "1" then
            return true
        end
    end
    return false
end

-- Adds the typedef, class and protocol names of one shard to names, and the classes the iOS SDK marks unavailable to unavailable.
local function add_type_names(tree, filepath, names, unavailable)
    local shard = import("found.shard", {rootdir = path.join(tree, "tools"), anonymous = true})
    for _, r in ipairs(read_rows(filepath, {typedef = true, interface = true, protocol = true})) do
        local name = row_name(shard, r)
        names[name] = true
        if r.kind == "interface" and ios_unavailable(r.availability) then
            unavailable[name] = true
        end
    end
end

-- The declared names of the tree: the typedef, class and protocol names of every shard (nested frameworks included), less the
-- classes the iOS SDK marks unavailable in any shard. Read once per tree.
local function declared_index(tree)
    if declared_memo[tree] == nil then
        local names, unavailable = {}, {}
        for _, filepath in ipairs(shard_files(tree)) do
            add_type_names(tree, filepath, names, unavailable)
        end
        for name in pairs(unavailable) do
            names[name] = nil
        end
        declared_memo[tree] = names
    end
    return declared_memo[tree]
end

-- The declared names the iOS build sees (gen.py@52253c0650 declared_names, read over every shard instead of a list of frameworks): a set, a copy of
-- the tree's declared names. fw is the framework asked for; its own shard is one of the tree's. With a source injected, its declared set.
function declared_names(tree, fw)
    if injected then
        return injected(fw, nil).declared or {}
    end
    local out = {}
    for name in pairs(declared_index(tree)) do
        out[name] = true
    end
    return out
end

-- The type of each extern variable of a framework, by its name: the constants' type column (design-foundation.md 5.7, the typed
-- shards). The type is the one the shard spells; the typedef it names is not resolved, because a typedef's own text carries the
-- qualifiers of its pointee (CFStringRef is "const struct __CFString *"), which are not the variable's. A name the shard holds no
-- variable for is absent.
function constant_types(tree, fw)
    local out = {}
    local shard = import("found.shard", {rootdir = path.join(tree, "tools"), anonymous = true})
    for _, r in ipairs(shard_records(tree, fw)) do
        if r.kind == "var" then
            out[shard.decode(r.kind, r.usr, r.name or "", r.side or "")] = r.type or "-"
        end
    end
    return out
end
