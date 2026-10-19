-- slice-diff.lua: what Apple's SDK 26.2 interface declares for a slice of types that our module does not.
--
--     xmake l slice-diff.lua ours.json TYPE [TYPE...]
--
-- Apple's side is parsed out of the 26.2 .swiftinterface (the only written-down shape of a 17+ declaration; the corpus
-- carries names only). Ours is the digester dump of the module this worktree builds, the same way bridge/api-diff.lua
-- reads it. A declaration counts as missing when our dump has nothing of that name under that type; Apple's declaration
-- is printed with it, so the shape to write is right there.

import("core.base.json")
local text = import("lib.text", {rootdir = path.join(os.scriptdir(), "..", ".."), anonymous = true})

-- the same blocks, keep and skip rules as decls.lua, and the same walk of the interfaces. KEEP here is
--     ^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |static |mutating |nonisolated |final )*
--         (?:func|var|let|init|subscript|typealias|associatedtype|case)\b
-- and the attributes come before the modifiers, never between them.
local MODIFIERS = {"public ", "internal ", "static ", "mutating ", "nonisolated ", "final "}
local KEEP_KEYWORDS = {"func", "var", "let", "init", "subscript", "typealias", "associatedtype", "case"}
local SKIP_PREFIXES = {"get", "set", "_read", "_modify", "return", "{", "}", "#if", "#endif", "@_Concurrency",
    "@_transparent", "@usableFromInline"}

-- one attribute at pos: @name, an optional (...) with no ) inside, then spaces; the position after it, or nil
local function attribute_at(line, pos)
    local _, e = string.find(line, "^@[%w_]+", pos)
    if not e then
        return nil
    end
    local after = e + 1
    local _, paren = string.find(line, "^%([^%)]*%)", after)
    if paren then
        after = paren + 1
    end
    local _, space = string.find(line, "^%s+", after)
    return space and space + 1 or nil
end

local function keep(line)
    local _, spaces = string.find(line, "^%s*")
    local pos = spaces + 1
    local attribute = attribute_at(line, pos)
    while attribute do
        pos = attribute
        attribute = attribute_at(line, pos)
    end
    local moved = true
    while moved do
        moved = false
        for _, modifier in ipairs(MODIFIERS) do
            if text.startswith(line, modifier, pos) then
                pos = pos + #modifier
                moved = true
                break
            end
        end
    end
    for _, keyword in ipairs(KEEP_KEYWORDS) do
        if text.startswith(line, keyword, pos) and not text.is_word(line, pos + #keyword) then
            return true
        end
    end
    return false
end

local function skip(line)
    local _, spaces = string.find(line, "^%s*")
    for _, prefix in ipairs(SKIP_PREFIXES) do
        if text.startswith(line, prefix, spaces + 1) then
            return true
        end
    end
    return false
end

-- the blocks of an interface, each {head, body}, as decls.lua reads them
local function interface_blocks(file)
    local lines = text.split(io.readfile(file), "\n")
    local out = {}
    local i = 1
    local n = #lines
    while i <= n do
        local first = string.sub(lines[i], 1, 1)
        if lines[i] == "" or first == " " or first == "\t" or first == "}" then
            i = i + 1
        else
            local start = i
            while i <= n and (text.startswith(lines[i], "@") or lines[i] == "") do
                i = i + 1
            end
            local head = {}
            if i <= n then
                for k = start, i do
                    head[#head + 1] = text.strip(lines[k])
                end
            end
            local body = {}
            local depth = 0
            while i <= n do
                body[#body + 1] = lines[i]
                local _, opened = string.gsub(lines[i], "{", "")
                local _, closed = string.gsub(lines[i], "}", "")
                depth = depth + opened - closed
                i = i + 1
                if depth <= 0 then
                    break
                end
            end
            out[#out + 1] = {head = text.join(" ", head), body = body}
        end
    end
    return out
end

-- re.search(r'(?:struct|class|enum|protocol|extension)\s+([A-Za-z_][\w.]*)', head): the name, or nil
local function declared_name(head)
    for at = 1, #head do
        for _, kind in ipairs({"struct", "class", "enum", "protocol", "extension"}) do
            if text.startswith(head, kind, at) then
                local _, space = string.find(head, "^%s+", at + #kind)
                local name = space and string.match(head, "^[%a_][%w_%.]*", space + 1)
                if name then
                    return name
                end
            end
        end
    end
    return nil
end

-- re.search(r'@available\(iOS ([\d.]+)', head): the version, or ""
local function available_version(head)
    return string.match(head, "@available%(iOS ([%d%.]+)") or ""
end

local function sdk_path()
    local env = os.getenv("APPLE_26_SDK")
    if env and env ~= "" then
        return env
    end
    return path.join(os.getenv("HOME"), "Git", "projects", "ios", "charon", ".agent-work", "sdk-26.2", "iPhoneOS26.2.sdk")
end

-- [owner, declaration, version] for the types asked for
local function apple(types)
    local frameworks = path.join(sdk_path(), "System", "Library", "Frameworks")
    local files = {
        path.join(frameworks, "SwiftUI.framework", "Modules", "SwiftUI.swiftmodule", "arm64e-apple-ios.swiftinterface"),
        path.join(frameworks, "SwiftUICore.framework", "Modules", "SwiftUICore.swiftmodule", "arm64e-apple-ios.swiftinterface"),
    }
    local out = {}
    for _, file in ipairs(files) do
        for _, block in ipairs(interface_blocks(file)) do
            local name = declared_name(block.head)
            if name then
                local owner = text.partition(string.reverse(name), ".")
                owner = string.reverse(owner)
                if types[owner] then
                    local avail = available_version(block.head)
                    for _, line in ipairs(block.body) do
                        if keep(line) and not skip(line) then
                            local decl = text.strip(line)
                            if not (text.startswith(decl, "nonisolated public static func _")
                                or text.startswith(decl, "public static func _")) then
                                out[#out + 1] = {owner, decl, avail}
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

-- {path: {name...}} as a list of {path = {...}, name = "..."}, for each declaration of ours the digester dump holds
local function ours_of(file)
    local root = json.decode(io.readfile(file))["ABIRoot"]
    local found = {}
    local function walk(node, trail)
        if type(node) ~= "table" then
            return
        end
        local printed = node["printedName"]
        if printed and printed ~= "" then
            local base = text.partition(string.gsub(printed, "<[^<>]*>", ""), "(")
            found[#found + 1] = {path = trail, name = base}
        end
        local nested = trail
        if node["kind"] == "TypeDecl" then
            local extended = {}
            for i, part in ipairs(trail) do
                extended[i] = part
            end
            extended[#extended + 1] = node["name"] or node["printedName"] or ""
            nested = extended
        end
        for _, child in ipairs(node["children"] or {}) do
            walk(child, nested)
        end
    end
    walk(root, {})
    return found
end

local function has_member(ours, name, owner)
    for _, row in ipairs(ours) do
        if row.name == name and #row.path > 0 then
            for _, part in ipairs(row.path) do
                if part == owner then
                    return true
                end
            end
        end
    end
    return false
end

-- the name a declaration names: `func`, `var`, `let`, `init`, `subscript` or `case`, else a typealias, else nil
local function declaration_name(decl)
    for at = 1, #decl do
        for _, keyword in ipairs({"func", "var", "let", "init", "subscript", "case"}) do
            if text.startswith(decl, keyword, at) then
                local _, space = string.find(decl, "^%s+", at + #keyword)
                local name = space and string.match(decl, "^[%a_][%w_]*", space + 1)
                if name then
                    return name
                end
            end
        end
    end
    if string.find(decl, "typealias", 1, true) then
        return string.match(decl, "typealias%s+(%w+)")
    end
    return nil
end

function main(...)
    local args = {...}
    if args[1] == nil then
        io.stderr:write("usage: slice-diff.lua ours.json TYPE [TYPE...]\n")
        os.exit(2)
    end
    local ours = ours_of(args[1])
    local types = {}
    for i = 2, #args do
        types[args[i]] = true
    end
    local count = 0
    local missing = 0
    for _, row in ipairs(apple(types)) do
        count = count + 1
        local owner, decl, avail = row[1], row[2], row[3]
        local name = declaration_name(decl)
        if name == "Self" or name == "get" or name == "set" then
            name = nil
        end
        -- a member of a nested type lives under a path that ends with the owner, so the path is searched for it, not
        -- compared with it
        if name ~= nil and not text.startswith(name, "_") and not has_member(ours, name, owner) then
            missing = missing + 1
            print(string.format("%s %s %s", text.ljust(owner, 28), text.ljust(avail, 6), decl))
        end
    end
    local type_count = 0
    for _ in pairs(types) do
        type_count = type_count + 1
    end
    io.stderr:write(string.format("# %d declarations of %d types, %d with no declaration of that name in ours\n",
        count, type_count, missing))
end
