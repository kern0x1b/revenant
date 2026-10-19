-- The header facts of one framework, read from its declaration shard (ir.lua writes the shards; shard.lua decodes them). These are the
-- four kinds headers.lua produces today, so the generator can read the shard in place of the regex parse: members (the class members
-- of the framework's @interface and category declarations, one row per method or property), declared (the names of the framework's
-- declared entities), typedefs (name and underlying type) and superclasses (the superclass and the protocols of each class).
--
-- A member row: cls (the class, from the USR), kind (method or property), api (-[Cls sel], +[Cls sel] or -[Cls prop], the spec's key),
-- alias (the api for a method, Cls.prop for a property), avail and message (the IR's availability fields), text (the spec's
-- availability text, rendered from them by avail.lua, ruling D7), hash (the declaration hash, C++), key (the container: the category a
-- member is written in, or "-").
--
-- usage: facts(spec, framework) where spec is the spec folder (for example packages/a/apple-backports/spec)
local shard = import("shard", {rootdir = os.scriptdir(), anonymous = true})
local availability = import("avail", {rootdir = os.scriptdir(), anonymous = true})

-- The decoded rows of the framework's shard, or none when the framework has no shard (it has no declaration the extractor reads).
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

-- The class a member's USR names: c:objc(cs)Class(im)sel names the class of an instance or class member.
function class_of(usr)
    return usr:match("^c:objc%(cs%)([^%(]+)")
end

function members(spec, framework)
    local out = {}
    for _, r in ipairs(rows(spec, framework)) do
        -- the accessors clang synthesises from a property are not in the shards: the property is the member
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

-- The typedefs: their names and their underlying types (the type column, which only typedef rows carry). The written definition of a
-- typedef is not in a shard (ruling D8: decl is display only); the underlying type is what the shape needs.
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
