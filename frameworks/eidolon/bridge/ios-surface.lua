import("core.base.json")
local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local KINDS = {"struct", "class", "enum", "protocol", "typealias", "actor"}
local FIRST_CHARS = "@pofisctea"

local function words_of(file)
    local set, count = {}, 0
    for word in string.gmatch(io.readfile(file), "%S+") do
        if not set[word] then
            set[word] = true
            count = count + 1
        end
    end
    return set, count
end

local function sorted_keys(set)
    local keys = {}
    for k in pairs(set) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

local function declaration_at(src, q)
    local r = q
    if text.startswith(src, "public ", r) then
        r = r + 7
    elseif text.startswith(src, "open ", r) then
        r = r + 5
    end
    if text.startswith(src, "final ", r) then
        r = r + 6
    end
    if text.startswith(src, "@frozen ", r) then
        r = r + 8
    end
    if text.startswith(src, "indirect ", r) then
        r = r + 9
    end
    local kind = nil
    for _, word in ipairs(KINDS) do
        if text.startswith(src, word, r) then
            kind = word
            break
        end
    end
    if not kind then
        return nil
    end
    local _, space = string.find(src, "^%s+", r + #kind)
    if not space then
        return nil
    end
    local name = string.match(src, "^[%w_]+", space + 1)
    if not name then
        return nil
    end
    return kind, name, space + #name
end

local function decl_at(src, p)
    local stops = {p}
    local q = p
    while string.sub(src, q, q) == "@" do
        local newline = string.find(src, "\n", q, true)
        if not newline then
            break
        end
        local _, space = string.find(src, "^%s*", newline + 1)
        q = space + 1
        stops[#stops + 1] = q
    end
    for k = #stops, 1, -1 do
        local kind, name, last = declaration_at(src, stops[k])
        if kind then
            return string.sub(src, p, stops[k] - 1), kind, name, last
        end
    end
    return nil
end

local function unavailable_on_ios(attributes)
    return string.match(attributes, "@available%(iOS,%s*unavailable") ~= nil
end

local function extends_view(s)
    local p = 1
    while true do
        local _, e = string.find(s, "^@%S+%s+", p)
        if not e then
            break
        end
        p = e + 1
    end
    local head = "extension SwiftUI.View"
    if not text.startswith(s, head, p) then
        return false
    end
    local after = string.sub(s, p + #head, p + #head)
    return after == "" or not string.match(after, "[%w_]")
end

local function find_func(s)
    local from = 1
    while true do
        local a = string.find(s, "func ", from, true)
        if not a then
            return nil
        end
        local boundary = a == 1 or not string.match(string.sub(s, a - 1, a - 1), "[%w_]")
        if boundary then
            local name = string.match(s, "^[%w_]+", a + 5)
            if name then
                return a, name
            end
        end
        from = a + 1
    end
end

local here = os.scriptdir()
local interfaces = os.files(path.join(here, "fw", "SwiftUI.framework", "Modules", "SwiftUI.swiftmodule", "*.swiftinterface"))
table.sort(interfaces)
local src = io.readfile(interfaces[1])

local types = words_of(path.join(here, "apple-types.txt"))
local usable = {}
local p = 1
while p <= #src do
    local c = string.sub(src, p, p)
    local attributes, kind, name, last = nil, nil, nil, nil
    if string.find(FIRST_CHARS, c, 1, true) then
        attributes, kind, name, last = decl_at(src, p)
    end
    if kind then
        if types[name] and not unavailable_on_ios(attributes) then
            usable[name] = true
        end
        p = last + 1
    else
        p = p + 1
    end
end
io.writefile(path.join(here, "apple-types-ios.txt"), text.join("\n", sorted_keys(usable)) .. "\n")

local mods, mod_count = words_of(path.join(here, "apple-view-modifiers.txt"))
local usable_mods = {}
local depth = 0
local in_view = false
local attrs = {}
for _, line in ipairs(text.split(src, "\n")) do
    local stripped = text.strip(line)
    if depth == 0 and extends_view(stripped) then
        in_view = true
    end
    local at, name = find_func(stripped)
    if at then
        if in_view and depth == 1 and mods[name] then
            local own = string.sub(stripped, 1, at - 1)
            local hidden = unavailable_on_ios(own)
            for _, a in ipairs(attrs) do
                hidden = hidden or unavailable_on_ios(a)
            end
            if not hidden then
                usable_mods[name] = true
            end
        end
        attrs = {}
    elseif text.startswith(stripped, "@") then
        attrs[#attrs + 1] = stripped
    elseif stripped ~= "" and not text.startswith(stripped, "#") then
        attrs = {}
    end
    local _, opened = string.gsub(line, "{", "")
    local _, closed = string.gsub(line, "}", "")
    depth = depth + opened - closed
    if depth == 0 then
        in_view = false
    end
end
io.writefile(path.join(here, "apple-view-modifiers-ios.txt"), text.join("\n", sorted_keys(usable_mods)) .. "\n")

local type_count = 0
for _ in pairs(types) do
    type_count = type_count + 1
end
local usable_count = 0
for _ in pairs(usable) do
    usable_count = usable_count + 1
end
local usable_mod_count = 0
for _ in pairs(usable_mods) do
    usable_mod_count = usable_mod_count + 1
end
print(string.format("types: %d -> %d usable on iOS; modifiers: %d -> %d usable on iOS",
    type_count, usable_count, mod_count, usable_mod_count))
