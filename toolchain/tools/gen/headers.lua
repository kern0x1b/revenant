local layout = import("layout", {anonymous = true})
local files = import("files", {anonymous = true})
local order = import("order", {anonymous = true})

local injected = nil
local typedef_memo = {}
local declared_memo = {}

function use(source)
    injected = source
end

local function read_rows(file, kinds)
    local out = {}
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

local function shard_path(tree, fw)
    return path.join(tree, "..", layout.constants().SNAP_ROOT, fw, "declarations.tsv")
end

function shard_records(tree, fw)
    return read_rows(shard_path(tree, fw), nil)
end

local VALUE_KINDS = {var = true, enumconst = true}

function shard_value_records(tree, fw)
    return read_rows(shard_path(tree, fw), VALUE_KINDS)
end

local function row_name(shard, r)
    return (shard.decode(r.kind, r.usr, r.name or "", r.side or ""))
end

local function shard_files(tree)
    local found = {}
    for _, pattern in ipairs({"*", "*/*"}) do
        for _, filepath in ipairs(files.glob(path.join(tree, "..", layout.constants().SNAP_ROOT, pattern, "declarations.tsv"))) do
            table.insert(found, filepath)
        end
    end
    table.sort(found, order.less)
    return found
end

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
            if r.kind == "property" and string.find(r.usr, "(cpy)", 1, true) then
                side = "+"
            end
        if r.kind == "property" then
            local protocol = string.match(r.usr, "^c:objc%(pl%)([^%(]+)")
            if protocol then
                out.protocol_members[protocol .. "." .. name] = true
            end
        end
        if r.kind == "method" or r.kind == "property" then
            local cls = string.match(r.usr, "^c:objc%(cs%)([^%(]+)")
            if cls then
                local api = side .. "[" .. cls .. " " .. name .. "]"
                local alias = r.kind == "method" and api or (cls .. "." .. name)
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

local function ios_unavailable(availability)
    for entry in string.gmatch(availability or "", "[^,]+") do
        local value = string.match(entry, "^ios=(.*)$")
        if value and string.match(value, "[^/]*$") == "1" then
            return true
        end
    end
    return false
end

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
