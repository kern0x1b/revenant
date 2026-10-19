local shard = import("shard", {rootdir = os.scriptdir(), anonymous = true})
local availability = import("avail", {rootdir = os.scriptdir(), anonymous = true})

function rows(spec, framework)
    local file = path.join(spec, framework, "declarations.tsv")
    local out = {}
    if not os.isfile(file) then return out end
    for line in io.lines(file) do
        if not line:find("^#") then
            local c = {}
            for cell in (line .. "\t"):gmatch("([^\t]*)\t") do table.insert(c, cell) end
            local name, side = shard.decode(c[1], c[2], c[4], c[5])
            table.insert(out, {kind = c[1], usr = c[2], key = c[3], name = name, side = side, type = c[6], params = c[7],
                attrs = c[8], avail = c[9], message = c[10], hash = c[11]})
        end
    end
    return out
end

function class_of(usr)
    return usr:match("^c:objc%(cs%)([^%(]+)")
end

function members(spec, framework)
    local out = {}
    for _, r in ipairs(rows(spec, framework)) do
        local cls = (r.kind == "method" or r.kind == "property") and class_of(r.usr)
        if cls then
            local api, alias
            if r.kind == "method" then
                api = r.side .. "[" .. cls .. " " .. r.name .. "]"
                alias = api
            else
                api = "-[" .. cls .. " " .. r.name .. "]"
                alias = cls .. "." .. r.name
            end
            table.insert(out, {cls = cls, kind = r.kind, api = api, alias = alias, avail = r.avail, message = r.message,
                text = availability.render(r.avail, r.message), hash = r.hash, key = r.key})
        end
    end
    return out
end

function declared(spec, framework)
    local out = {}
    local entities = {var = true, ["function"] = true, typedef = true, enum = true, struct = true, union = true, enumconst = true}
    for _, r in ipairs(rows(spec, framework)) do
        if entities[r.kind] and r.name ~= "-" then table.insert(out, {kind = r.kind, name = r.name}) end
    end
    return out
end

function typedefs(spec, framework)
    local out = {}
    for _, r in ipairs(rows(spec, framework)) do
        if r.kind == "typedef" then table.insert(out, {name = r.name, type = r.type}) end
    end
    return out
end

function superclasses(spec, framework)
    local out = {}
    for _, r in ipairs(rows(spec, framework)) do
        if r.kind == "super" then table.insert(out, {cls = r.key, superclass = r.name}) end
    end
    return out
end

function conformances(spec, framework)
    local out = {}
    for _, r in ipairs(rows(spec, framework)) do
        if r.kind == "conforms" then table.insert(out, {cls = r.key, protocol = r.name}) end
    end
    return out
end
