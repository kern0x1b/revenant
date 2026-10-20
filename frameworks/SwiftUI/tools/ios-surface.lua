local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})
local sets = import("lib.sets", {rootdir = os.scriptdir(), anonymous = true})
local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

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

function main()
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
    io.writefile(tree.api("apple-view-modifiers-ios.txt"), text.join("\n", sets.sorted_keys(usable_mods)) .. "\n")
    print(string.format("modifiers: %d -> %d usable on iOS", mod_count, #sets.sorted_keys(usable_mods)))
end
