-- types-surface.lua: write bridge/apple-types.txt from the SDK's own 26.2 interfaces, so the list the ledger counts
-- against is generated rather than kept by hand.
--
-- The list used to be hand-kept and had been since the repository's first commit, which is how a family the interface
-- declares - `TextEditorStyle` and its three styles - was missing from it. It is now every public type and typealias
-- the SDK of 26.2 declares in the module of this framework, and apple-types-ios.txt the part of it an iOS app can
-- actually use.
--
-- The source is the SDK of 26.2, not fw/: fw/ is the interface of 16.4, which has no widget, no `TextEditorStyle` and
-- no window, and generating from it would drop every type this port exists to carry.
--
--     xmake l types-surface.lua [SDK26]        (default: the charon SDK 26.2 checkout)

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local here = os.scriptdir()
-- set by main: the SDK, and the two roots its interfaces are read from
local sdk, frameworks, stdlib
-- the modules the inventory covers: SwiftUI's own surface, which is what an app writes against. The standard library,
-- Foundation and UIKit are reachable through it and are not listed here - the hand-kept list never had them, and
-- SCOPE widens the list when a review asks for it.
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

-- \s+ at position q: the position after the whitespace, or nil
local function spaces_at(s, q)
    local _, e = string.find(s, "^%s+", q)
    return e and e + 1 or nil
end

-- the keyword at q, followed by whitespace: the position after that whitespace, or nil
local function keyword_at(s, q, word)
    if not startswith(s, word, q) then
        return nil
    end
    return spaces_at(s, q + #word)
end

-- The rest of DECL after its attribute group, from q: the access group, the kind, the name, and the last position.
--     ((?:public|open|package)\s+)(?:final\s+|indirect\s+|@frozen\s+)*(struct|class|enum|protocol|typealias|actor)\s+(\w+)
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

-- One attribute of the group, `@[\w.()]+\s*(?:\([^)]*\)\s*)?`, at p. The regex tries the longest run of name characters
-- first, then the parenthesised argument before none; every way it can end is handed to try, in that order, and the
-- first one try accepts wins.
local function attribute_then(s, p, try)
    local _, longest = string.find(s, "^@[%w_%.%(%)]+", p)
    if not longest then
        return nil
    end
    -- `[\w.()]+` takes at least one character after the @
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

-- DECL.match(s): the attribute text, the access group, the kind and the name, or nil. The attribute group is
-- `(?:ATTRIBUTE)*`, greedy: each way of taking one more attribute is tried before the way of taking none.
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

-- the interfaces of the modules in scope: the frameworks' first, then the stdlib's, each in sorted order
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

-- the text of a file of one line per row: nothing for no rows, else each row ends in a newline
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

function main(...)
    sdk = nil
    for _, a in ipairs({...}) do
        sdk = sdk or a
    end
    sdk = sdk or os.getenv("APPLE_26_SDK")
    if sdk == nil then
        sdk = path.join(os.getenv("HOME"), "Git", "projects", "ios", "charon", ".agent-work", "sdk-26.2", "iPhoneOS26.2.sdk")
    end
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
        -- a type declared inside another is not a module-level name, and a doc or comment line is not a declaration:
        -- take only lines that start with an attribute or a public keyword at the left. The SDK writes @available on
        -- the line above the declaration it belongs to and on no declaration's own line at all, so a declaration's
        -- attributes are its own line and the @-lines above it.
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
    print("types-surface: " .. sdk)
    table.sort(module_order)
    for _, module in ipairs(module_order) do
        print("  " .. module .. ": " .. count_of(per_module[module]) .. " types")
    end
    print("  apple-types.txt: " .. count_of(everything) .. " types, " .. count_of(on_ios) .. " of them usable on iOS")
    print("  added " .. #added .. ": " .. head_of(added))
    print("  removed " .. #removed .. ": " .. head_of(removed))
end
