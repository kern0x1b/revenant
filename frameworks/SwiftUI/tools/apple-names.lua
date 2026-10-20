local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})

local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
local here = tree.api()
local sdk, frameworks, stdlib
local scope = os.getenv("APPLE_26_SCOPE")
if scope == nil then
    scope = "SwiftUI,SwiftUICore"
end

local KINDS = {"struct", "class", "enum", "protocol", "typealias", "actor"}
local ACCESS = {"public", "open", "package"}
local MODIFIERS = {"final", "indirect", "@frozen"}

local function startswith(s, prefix, at)
    return text.startswith(s, prefix, at)
end

local function spaces_at(s, q)
    local _, e = string.find(s, "^%s+", q)
    return e and e + 1 or nil
end

local function keyword_at(s, q, word)
    if not startswith(s, word, q) then
        return nil
    end
    return spaces_at(s, q + #word)
end

local function declaration_at(s, q)
    local access_end = nil
    for _, word in ipairs(ACCESS) do
        access_end = keyword_at(s, q, word)
        if access_end then
            break
        end
    end
    if not access_end then
        return nil
    end
    local r = access_end
    local moved = true
    while moved do
        moved = false
        for _, word in ipairs(MODIFIERS) do
            local after = keyword_at(s, r, word)
            if after then
                r = after
                moved = true
                break
            end
        end
    end
    for _, kind in ipairs(KINDS) do
        local after = keyword_at(s, r, kind)
        if after then
            local name = string.match(s, "^[%w_]+", after)
            if not name then
                return nil
            end
            return {access = string.sub(s, q, access_end - 1), kind = kind, name = name, last = after + #name - 1}
        end
    end
    return nil
end

local function attribute_then(s, p, try)
    local _, longest = string.find(s, "^@[%w_%.%(%)]+", p)
    if not longest then
        return nil
    end
    for name_end = longest, p + 2, -1 do
        local after_name = name_end + 1
        local ws = spaces_at(s, after_name) or after_name
        local _, paren = string.find(s, "^%([^%)]*%)", ws)
        if paren then
            local resumed = spaces_at(s, paren + 1) or (paren + 1)
            local found = try(resumed)
            if found then
                return found
            end
        end
        local found = try(ws)
        if found then
            return found
        end
    end
    return nil
end

local function match_decl(s)
    local function from(q)
        local found = declaration_at(s, q)
        if found then
            found.start = q
            return found
        end
        if startswith(s, "@", q) then
            return attribute_then(s, q, from)
        end
        return nil
    end
    local found = from(1)
    if not found then
        return nil
    end
    return {attrs = string.sub(s, 1, found.start - 1), access = found.access, kind = found.kind, name = found.name}
end

local function interfaces()
    local out = {}
    for _, root in ipairs({frameworks, stdlib}) do
        local found = {}
        if os.isdir(root) then
            for _, file in ipairs(os.files(path.join(root, "*", "Modules", "*.swiftmodule", "*.swiftinterface"))) do
                local module = string.gsub(path.filename(path.directory(file)), "%.swiftmodule$", "")
                for wanted in string.gmatch(scope, "[^,]+") do
                    if module == wanted then
                        found[#found + 1] = file
                        break
                    end
                end
            end
        end
        table.sort(found)
        for _, file in ipairs(found) do
            out[#out + 1] = file
        end
    end
    return out
end

local function rows_text(rows)
    if #rows == 0 then
        return ""
    end
    return text.join("\n", rows) .. "\n"
end

local function unavailable_on_ios(attributes)
    return string.match(attributes, "@available%(%s*iOS%s*,%s*unavailable") ~= nil
end

local function sorted_keys(set)
    local keys = {}
    for k in pairs(set) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

local function types(...)
    sdk = nil
    for _, a in ipairs({...}) do
        sdk = sdk or a
    end
    sdk = sdk or tree.sdk()
    frameworks = path.join(sdk, "System", "Library", "Frameworks")
    stdlib = path.join(sdk, "usr", "lib", "swift")
    if not os.isdir(sdk) then
        io.stderr:write("types-surface: no SDK at " .. sdk .. "\n")
        os.exit(2)
    end
    local everything, on_ios, per_module = {}, {}, {}
    local module_order = {}
    for _, file in ipairs(interfaces()) do
        local module = string.gsub(path.filename(path.directory(file)), "%.swiftmodule$", "")
        local lines = text.split(io.readfile(file), "\n")
        local above = {}
        for _, line in ipairs(lines) do
            local stripped = text.lstrip(line)
            local m = match_decl(stripped)
            if text.startswith(stripped, "@") and not m then
                above[#above + 1] = stripped
            elseif not m then
                above = {}
            else
                if not per_module[module] then
                    per_module[module] = {}
                    module_order[#module_order + 1] = module
                end
                per_module[module][m.name] = m.kind
                everything[m.name] = m.kind
                local parts = {table.unpack(above)}
                parts[#parts + 1] = m.attrs
                if not unavailable_on_ios(text.join(" ", parts)) then
                    on_ios[m.name] = m.kind
                end
                above = {}
            end
        end
    end
    local previous = {}
    local path_out = path.join(here, "apple-types.txt")
    if os.isfile(path_out) then
        for _, line in ipairs(text.split(io.readfile(path_out), "\n")) do
            if text.strip(line) ~= "" then
                local name, _, kind = text.partition(line, "\t")
                previous[name] = kind
            end
        end
    end
    local added, removed = {}, {}
    for _, name in ipairs(sorted_keys(everything)) do
        if previous[name] == nil then
            added[#added + 1] = name
        end
    end
    for _, name in ipairs(sorted_keys(previous)) do
        if everything[name] == nil then
            removed[#removed + 1] = name
        end
    end
    local rows = {}
    for _, name in ipairs(sorted_keys(everything)) do
        rows[#rows + 1] = name .. "\t" .. everything[name]
    end
    io.writefile(path_out, rows_text(rows))
    io.writefile(path.join(here, "apple-types-ios.txt"), rows_text(sorted_keys(on_ios)))

    local function count_of(set)
        local n = 0
        for _ in pairs(set) do
            n = n + 1
        end
        return n
    end
    local function head_of(list)
        local shown = {}
        for i = 1, math.min(#list, 20) do
            shown[i] = list[i]
        end
        return text.join(" ", shown) .. (#list > 20 and " ..." or "")
    end
    print("apple-names types: " .. sdk)
    table.sort(module_order)
    for _, module in ipairs(module_order) do
        print("  " .. module .. ": " .. count_of(per_module[module]) .. " types")
    end
    print("  apple-types.txt: " .. count_of(everything) .. " types, " .. count_of(on_ios) .. " of them usable on iOS")
    print("  added " .. #added .. ": " .. head_of(added))
    print("  removed " .. #removed .. ": " .. head_of(removed))
end

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

local function modifiers()
    local interfaces = os.files(path.join(tree.run("fw"), "SwiftUI.framework", "Modules", "SwiftUI.swiftmodule", "*.swiftinterface"))
    if #interfaces == 0 then
        raise("no SwiftUI interface under %s: run ./xmakew l frameworks/SwiftUI/tools/api-surface.lua prepare first", tree.run("fw"))
    end
    table.sort(interfaces)
    local src = io.readfile(interfaces[1])

    local mods, mod_count = words_of(tree.api("apple-view-modifiers.txt"))
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
    io.writefile(tree.api("apple-view-modifiers-ios.txt"), text.join("\n", sorted_keys(usable_mods)) .. "\n")
    print(string.format("modifiers: %d -> %d usable on iOS", mod_count, #sorted_keys(usable_mods)))
end

local USAGE = [[usage: ./xmakew l frameworks/SwiftUI/tools/apple-names.lua [types [SDK] | modifiers]
  types      the type names of SwiftUI and SwiftUICore in the iOS 26.2 SDK, and those usable on iOS, into tests/data/api
  modifiers  the View modifiers of the copied SwiftUI interface (api-surface.lua prepare) usable on iOS, into tests/data/api
  (none)     both]]

function main(action, ...)
    if action == "types" then
        types(...)
    elseif action == "modifiers" then
        modifiers()
    elseif action == nil then
        types()
        modifiers()
    else
        raise(USAGE)
    end
end
