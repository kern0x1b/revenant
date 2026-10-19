local json = import("core.base.json")
local order = import("order", {anonymous = true})

local COL = {framework = 1, kind = 2, usr = 3, container = 4, name = 5, side = 6, header = 7, line = 8, avail = 9, type = 11,
             params = 12}

local BOOKKEEPING = {census = true, unparsed = true, meta = true, super = true, conforms = true, accessor = true}
local TYPE_KINDS = {typedef = true, enum = true, struct = true, union = true}
local USER_KINDS = {method = true, property = true, ["function"] = true, var = true, field = true}

local function numbers_of(release)
    local out = {}
    for part in string.gmatch(release, "[^%.]+") do
        out[#out + 1] = tonumber(part) or 0
    end
    return out
end

local function later(a, b)
    local x, y = numbers_of(a), numbers_of(b)
    for index = 1, math.max(#x, #y) do
        local p, q = x[index] or 0, y[index] or 0
        if p ~= q then return p > q end
    end
    return false
end

local function latest(a, b)
    if a == nil then return b end
    if b == nil then return a end
    return later(b, a) and b or a
end

local function ios_intro(text)
    if text == nil or text == "-" then return nil end
    for token in string.gmatch(text, "[^,]+") do
        local intro = string.match(token, "%f[%w_]ios=([^/]+)/")
        if intro then return intro ~= "-" and intro or nil end
    end
    return nil
end

local function with_ios_intro(text, intro)
    local out, found = {}, false
    for token in string.gmatch(text, "[^,]+") do
        if string.find(token, "%f[%w_]ios=") then found = true end
        out[#out + 1] = (string.gsub(token, "%f[%w_]ios=[^/]+/", "ios=" .. intro .. "/", 1))
    end
    if not found then out[#out + 1] = "ios=" .. intro .. "/-/-/0" end
    return table.concat(out, ",")
end

local function owner_of(usr)
    local owner, tag = string.match(usr or "", "^c:objc%(%a+%)([%w_]+)%(([%a]+)%)")
    return owner, tag
end

local function spellings_of(row)
    local kind, name = row[COL.kind], row[COL.name]
    if kind == "interface" or kind == "protocol" then
        return {name}
    elseif kind == "method" then
        local owner, tag = owner_of(row[COL.usr])
        if owner == nil then return nil end
        return {(tag == "cm" and "+" or "-") .. "[" .. owner .. " " .. name .. "]"}
    elseif kind == "property" then
        local owner, tag = owner_of(row[COL.usr])
        if owner == nil then return nil end
        local getter = (tag == "cpy" and "+" or "-") .. "[" .. owner .. " " .. name .. "]"
        return {owner .. "." .. name, getter}
    elseif kind == "function" then
        return {name, name .. "()"}
    elseif kind == "var" or kind == "enumconst" or TYPE_KINDS[kind] then
        return {name}
    end
    return nil
end

local function class_of(row, listed)
    if row[COL.kind] ~= "method" and row[COL.kind] ~= "property" then return nil end
    local owner = owner_of(row[COL.usr])
    return owner and listed[owner] or nil
end

local function words_of(text, into)
    for word in string.gmatch(text or "", "[%a_][%w_]*") do
        into[word] = true
    end
    return into
end

function read_registry(root)
    local listed = {}
    local found = table.join(os.files(path.join(root, "registry", "*.json")), os.files(path.join(root, "registry", "*", "*.json")))
    table.sort(found, order.less)
    for _, file in ipairs(found) do
        local data = json.decode(io.readfile(file))
        for _, entry in ipairs(data.entries or data) do
            if listed[entry.api] == nil then
                listed[entry.api] = entry
            end
        end
    end
    return listed
end

function plan(rows, listed, release)
    local changes, counts = {}, {}
    local lowered = {}
    local function record(row, to, cause)
        local from = ios_intro(row[COL.avail])
        if from == nil or not later(from, to) then return end
        lowered[row] = to
        changes[#changes + 1] = {row = row, from = from, to = to, cause = cause}
        counts[cause] = (counts[cause] or 0) + 1
    end
    local function target_of(entry)
        return latest(release, entry.minimum)
    end

    local types, type_names = {}, {}
    for _, row in ipairs(rows) do
        if TYPE_KINDS[row[COL.kind]] and row[COL.name] ~= "-" then
            local list = types[row[COL.name]] or {}
            list[#list + 1] = row
            types[row[COL.name]] = list
            type_names[#type_names + 1] = row[COL.name]
        end
    end
    table.sort(type_names, order.less)

    local users_of = {}
    for _, row in ipairs(rows) do
        if USER_KINDS[row[COL.kind]] then
            local words = words_of(row[COL.type], {})
            words_of(row[COL.params], words)
            for word in pairs(words) do
                if types[word] then
                    local list = users_of[word] or {}
                    list[#list + 1] = row
                    users_of[word] = list
                end
            end
        end
    end

    local class_mark = {}
    for _, row in ipairs(rows) do
        if row[COL.kind] == "interface" then class_mark[row[COL.name]] = row[COL.avail] end
    end

    local type_target, blocked_by = {}, {}
    local members_of = {}
    for _, row in ipairs(rows) do
        if (row[COL.kind] == "enumconst" or row[COL.kind] == "field") and row[COL.container] ~= "-" then
            local list = members_of[row[COL.container]] or {}
            list[#list + 1] = row
            members_of[row[COL.container]] = list
        end
    end
    for _, name in ipairs(type_names) do
        if type_target[name] == nil then
            local own = listed[name]
            local declared = types[name]
            local above = false
            for _, row in ipairs(table.join(declared, members_of[name] or {})) do
                local intro = ios_intro(row[COL.avail])
                if intro and later(intro, release) then above = true end
            end
            if above and (own == nil or own.status == "implemented") then
                local target, blocked, carried = release, nil, 0
                for _, user in ipairs(users_of[name] or {}) do
                    local intro = ios_intro(user[COL.avail])
                    local owner = owner_of(user[COL.usr])
                    local inherited = (user[COL.kind] == "method" or user[COL.kind] == "property") and owner ~= nil
                        and class_mark[owner] == user[COL.avail]
                    if intro and later(intro, release) and blocked == nil and not inherited then
                        local own_user = nil
                        for _, spelling in ipairs(spellings_of(user) or {}) do
                            if listed[spelling] then
                                own_user = listed[spelling]
                                break
                            end
                        end
                        local class = class_of(user, listed)
                        if own_user then
                            if own_user.status == "implemented" or own_user.status == "inert" then
                                carried = carried + 1
                                if own_user.status == "implemented" then target = latest(target, own_user.minimum) end
                            else
                                blocked = string.format("%s %s in %s is %s", user[COL.kind], user[COL.name], user[COL.framework], own_user.status)
                            end
                        elseif class and (class.status == "implemented" or class.status == "inert") then
                            carried = carried + 1
                        else
                            blocked = string.format("%s %s in %s has no entry", user[COL.kind], user[COL.name], user[COL.framework])
                        end
                    end
                end
                if blocked then
                    type_target[name] = false
                    blocked_by[name] = blocked_by[name] or {}
                    table.insert(blocked_by[name], blocked)
                else
                    type_target[name] = target
                end
            else
                type_target[name] = false
            end
            if type_target[name] then
                for _, row in ipairs(declared) do
                    record(row, type_target[name], "type")
                end
            end
        end
    end

    for _, row in ipairs(rows) do
        local kind = row[COL.kind]
        if not BOOKKEEPING[kind] and not TYPE_KINDS[kind] then
            local own = nil
            for _, spelling in ipairs(spellings_of(row) or {}) do
                if listed[spelling] then
                    own = listed[spelling]
                    break
                end
            end
            if own ~= nil then
                if own.status == "implemented" then
                    local avail = row[COL.avail] or "-"
                    local owner = (kind == "method" or kind == "property") and owner_of(row[COL.usr]) or nil
                    local class_intro = owner and class_mark[owner] and ios_intro(class_mark[owner])
                    if ios_intro(avail) == nil and not string.find(avail, "%f[%w_]ios=") and class_intro and later(class_intro, target_of(own)) then
                        local to = target_of(own)
                        lowered[row] = to
                        changes[#changes + 1] = {row = row, from = class_intro, to = to, cause = "redeclared"}
                        counts.redeclared = (counts.redeclared or 0) + 1
                    else
                        record(row, target_of(own), "own")
                    end
                end
            elseif kind == "method" or kind == "property" then
                local class = class_of(row, listed)
                if class and class.status == "implemented" then
                    record(row, target_of(class), "class")
                end
            elseif kind == "category" then
                local owner = string.match(row[COL.usr] or "", "^c:objc%(cy%)([%w_]+)@")
                local class = owner and listed[owner]
                if class and class.status == "implemented" then
                    record(row, target_of(class), "category")
                end
            elseif (kind == "enumconst" or kind == "field") and type_target[row[COL.container]] then
                record(row, type_target[row[COL.container]], "type-member")
            end
        end
    end
    return changes, counts, lowered, blocked_by
end

function apply(rows, listed, release)
    local changes = plan(rows, listed, release)
    for _, change in ipairs(changes) do
        change.row[COL.avail] = with_ios_intro(change.row[COL.avail], change.to)
    end
    return #changes
end

function lowered_copy(rows, listed, release)
    local copies = {}
    for index, row in ipairs(rows) do
        copies[index] = table.clone(row)
    end
    return copies, apply(copies, listed, release)
end
