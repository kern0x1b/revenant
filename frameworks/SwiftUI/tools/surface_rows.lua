local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})
local owners = import("lib.owners", {rootdir = os.scriptdir(), anonymous = true})
local braces = import("lib.braces", {rootdir = os.scriptdir(), anonymous = true})


local MODULES = {Swift = true, SwiftUI = true, SwiftUICore = true, Foundation = true, UIKit = true, Combine = true}

local KINDS = {"struct", "class", "enum", "protocol", "typealias", "actor"}

local PREFIXES = {"public ", "internal ", "private ", "fileprivate ", "open ", "final ", "@frozen ", "indirect "}

local SKIP = {["{"] = true, ["}"] = true, get = true, set = true, ["get set"] = true, willSet = true, didSet = true}

local function type_head(s)
    local pos = 1
    local moved = true
    while moved do
        moved = false
        for _, prefix in ipairs(PREFIXES) do
            if text.startswith(s, prefix, pos) then
                pos = pos + #prefix
                moved = true
                break
            end
        end
    end
    for _, kind in ipairs(KINDS) do
        if text.startswith(s, kind, pos) then
            local _, space = string.find(s, "^%s+", pos + #kind)
            local name = space and string.match(s, "^[%w_]+", space + 1)
            if name then
                return kind, name
            end
            return nil
        end
    end
    return nil
end

local function extension_name(s)
    local _, space = string.find(s, "^extension%s+")
    return space and string.match(s, "^[%w_%.]+", space + 1) or nil
end

local function owner_of(extended)
    local head, rest = string.match(extended, "^([^%.]+)%.(.*)$")
    if head and MODULES[head] then
        return rest
    end
    return extended
end

local function case_runs(s, class)
    for _, at in ipairs(text.positions(s, "case ")) do
        if text.boundary(s, at) then
            local run = string.sub(s, at + 5)
            if run ~= "" and not string.find(run, "[^" .. class .. "]") then
                return {run}
            end
        end
    end
    return {}
end

local function static_members(s)
    local names = {}
    local from = 1
    while true do
        local at = string.find(s, "static ", from, true)
        if not at then
            return names
        end
        local matched = false
        if text.boundary(s, at) then
            for _, keyword in ipairs({"let", "var", "func"}) do
                local _, e = string.find(s, "^" .. keyword .. "%s+", at + 7)
                local name = e and string.match(s, "^[%w_]+", e + 1)
                if name then
                    names[#names + 1] = name
                    from = e + #name + 1
                    matched = true
                    break
                end
            end
        end
        if not matched then
            from = at + 1
        end
    end
end

local function kind_name(s)
    for at = 1, #s do
        for _, kind in ipairs(KINDS) do
            if text.startswith(s, kind, at) then
                local _, space = string.find(s, "^%s+", at + #kind)
                local name = space and string.match(s, "^[%w_]+", space + 1)
                if name then
                    return name
                end
            end
        end
    end
    return nil
end

local function alias_target(s)
    for at = 1, #s do
        for _, kind in ipairs(KINDS) do
            if text.startswith(s, kind, at) then
                local _, space = string.find(s, "^%s+", at + #kind)
                local name = space and string.match(s, "^[%w_]+", space + 1)
                if name then
                    local _, equals = string.find(s, "^%s*=%s*", space + #name + 1)
                    local target = equals and string.match(s, "^[%w_]+", equals + 1)
                    if target then
                        return target
                    end
                end
            end
        end
    end
    return nil
end

local function conformance(s)
    for _, at in ipairs(text.positions(s, "extension")) do
        if text.boundary(s, at) then
            local _, space = string.find(s, "^%s+", at + 9)
            local extended = space and string.match(s, "^[%w_%.]+", space + 1)
            local colon = nil
            if extended then
                local _, found = string.find(s, "^%s*:", space + #extended + 1)
                colon = found
            end
            if colon then
                local _, spaces = string.find(s, "^%s*", colon + 1)
                if string.find(string.sub(s, spaces + 1, spaces + 1), "^[%w_]") then
                    return extended, string.match(s, "^[%w_, ]+", spaces + 1)
                end
            end
        end
    end
    return nil
end

local function scan(file, out)
    local base = path.filename(file)
    local add = function(owner, kind, name)
        out[#out + 1] = {owner = owner, kind = kind, name = name, file = base}
    end
    local depth = 0
    local owner = nil
    local in_block, in_multiline, hashes = false, false, 0
    for _, line in ipairs(text.split(io.readfile(file), "\n")) do
        local s = text.strip(line)
        if depth == 0 then
            local kind, name = type_head(s)
            if kind then
                owner = name
                add(owner, "type", name)
                local open = string.find(s, "{", 1, true)
                if open and string.find(string.sub(s, open + 1), "}", 1, true) then
                    local close = nil
                    local from = 1
                    while true do
                        local at = string.find(s, "}", from, true)
                        if not at then
                            break
                        end
                        close = at
                        from = at + 1
                    end
                    local inline = string.sub(s, open + 1, close - 1)
                    for _, run in ipairs(case_runs(text.strip(inline), "%w_,` ")) do
                        for _, part in ipairs(text.split(run, ",")) do
                            if text.strip(part) ~= "" then
                                local name_in_case = string.gsub(text.strip(part), "^`+", "")
                                name_in_case = string.gsub(name_in_case, "`+$", "")
                                add(owner, "const", name_in_case)
                                add(owner, "var", name_in_case)
                                add(owner, "func", name_in_case)
                            end
                        end
                    end
                    for _, name_in_static in ipairs(static_members(inline)) do
                        add(owner, "var", name_in_static)
                    end
                    local target = alias_target(inline)
                    if target then
                        add(owner, "type", target)
                    end
                end
            else
                local extended = extension_name(s)
                if extended then
                    owner = owner_of(extended)
                else
                    owner = nil
                end
            end
        elseif extension_name(s) then
            owner = owner_of(extension_name(s))
        elseif owner and owner ~= "" and s ~= "" and not text.startswith(s, "//") and not SKIP[s] then
            local body = s
            local brace = string.find(s, "{", 1, true)
            if brace then
                body = string.sub(s, 1, brace - 1)
            end
            local conformed, protocols = conformance(s)
            local func_name = text.name_after(body, "func ")
            if func_name then
                add(owner, "func", func_name)
            elseif text.has_word(body, "init") then
                add(owner, "init", "init")
            elseif text.name_after(body, "var ") then
                add(owner, "var", text.name_after(body, "var "))
            elseif text.name_after(body, "let ") then
                add(owner, "var", text.name_after(body, "let "))
            elseif text.name_after(body, "case ") then
                for _, run in ipairs(case_runs(text.strip(body), "%w_, ")) do
                    for _, part in ipairs(text.split(run, ",")) do
                        local name_in_case = text.strip(part)
                        if name_in_case ~= "" then
                            add(owner, "const", name_in_case)
                            add(owner, "var", name_in_case)
                            add(owner, "func", name_in_case)
                        end
                    end
                end
            elseif conformed then
                owner = owner_of(conformed)
                if string.find(protocols, "Hashable", 1, true) then
                    add(owner, "func", "hash")
                    add(owner, "var", "hashValue")
                end
                if string.find(protocols, "Equatable", 1, true) then
                    add(owner, "func", "==")
                end
            elseif text.has_word(body, "subscript") then
                add(owner, "subscript", "subscript")
            else
                local type_name = kind_name(body)
                if type_name then
                    add(owner, "type", type_name)
                end
            end
        end
        local opened, closed
        opened, closed, in_block, in_multiline, hashes = braces.braces(s, in_block, in_multiline, hashes)
        depth = depth + opened - closed
        if depth == 0 then
            owner = nil
        end
    end
end

function collect()
    local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})
    local files = os.files(path.join(tree.sources(), "*.swift"))
    table.sort(files)
    local out = {}
    for _, file in ipairs(files) do
        scan(file, out)
    end
    return out
end

local function tree_rows()
    for _, row in ipairs(collect()) do
        print(row.owner .. "\t" .. row.kind .. "\t" .. row.name .. "\t" .. row.file)
    end
end


local KEYWORDS = {"struct", "class", "enum", "protocol", "actor", "typealias"}

local function type_name(body)
    for at = 1, #body do
        if text.boundary(body, at) then
            for _, keyword in ipairs(KEYWORDS) do
                if text.startswith(body, keyword, at) then
                    local _, space = string.find(body, "^%s+", at + #keyword)
                    local name = space and string.match(body, "^[%w_]+", space + 1)
                    if name then
                        return name
                    end
                end
            end
        end
    end
    return nil
end

local function declaration(body)
    if text.has_word(body, "subscript") then
        return "subscript", "subscript"
    end
    if text.has_word(body, "init") then
        return "init", "init"
    end
    local func_name = text.name_after(body, "func ")
    if func_name then
        return "func", func_name
    end
    local var_name = text.name_after(body, "var ")
    if var_name then
        return "var", var_name
    end
    local case_name = text.name_after(body, "case ")
    if case_name then
        return "const", case_name
    end
    local type = type_name(body)
    if type then
        return "type", type
    end
    return nil
end

local function scan_sdk(file, want, out, seen)
    local lines = text.split(io.readfile(file), "\n")
    local pending = ""
    for _, row in ipairs(owners.walk(lines)) do
        local s = text.strip(row.line)
        if s == "" or text.startswith(s, "#") then
            pending = ""
        elseif row.owner == nil then
            if text.startswith(s, "@") then
                pending = s
            end
        else
            local first = text.partition(row.owner, ".")
            if want[first] then
                if string.find(pending, "@available%(iOS,%s*unavailable") then
                    pending = ""
                else
                    local brace = string.find(s, "{", 1, true)
                    local body = brace and string.sub(s, 1, brace - 1) or s
                    if body ~= "" then
                        local kind, name = declaration(body)
                        if kind then
                            local key = row.owner .. "\t" .. kind .. "\t" .. name
                            if not seen[key] then
                                seen[key] = true
                                out[#out + 1] = {row.owner, kind, name}
                            end
                        end
                        pending = ""
                    end
                end
            end
        end
    end
end

local function sdk_rows(want_file)
    local sdk = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true}).sdk()
    local swiftui = path.join(sdk, "System", "Library", "Frameworks", "SwiftUI.framework", "Modules",
        "SwiftUI.swiftmodule", "arm64e-apple-ios.swiftinterface")
    local swiftuicore = path.join(sdk, "System", "Library", "Frameworks", "SwiftUICore.framework", "Modules",
        "SwiftUICore.swiftmodule", "arm64e-apple-ios.swiftinterface")

    local want = {}
    for _, line in ipairs(text.split(io.readfile(want_file), "\n")) do
        local s = text.strip(line)
        if s ~= "" and not text.startswith(s, "#") then
            want[s] = true
        end
    end

    local out, seen = {}, {}
    scan_sdk(swiftui, want, out, seen)
    scan_sdk(swiftuicore, want, out, seen)
    for _, row in ipairs(out) do
        print(text.join("\t", row))
    end
end

local COLUMNS = 3
local OURS = 4

local function convert(file)
    local rows, keys = {}, {}
    for number, line in ipairs(text.lines(io.readfile(file))) do
        if text.strip(line) ~= "" then
            local parts = text.split(line, "\t")
            local row = nil
            if #parts == OURS then
                row = {parts[1], parts[2], parts[3]}
            elseif #parts == COLUMNS then
                row = parts
            else
                io.stderr:write(string.format(
                    "%s: line %d has %d columns, the %d ours.lua writes or the %d surf-diff reads. Refusing.\n",
                    file, number, #parts, OURS, COLUMNS))
                os.exit(1)
            end
            local key = text.join("\t", row)
            if not keys[key] then
                keys[key] = row
                rows[#rows + 1] = row
            end
        end
    end
    table.sort(rows, function(a, b)
        for i = 1, COLUMNS do
            if a[i] ~= b[i] then
                return a[i] < b[i]
            end
        end
        return false
    end)
    return rows
end

local function collapse(file)
    local rows = convert(file)
    for _, row in ipairs(rows) do
        print(text.join("\t", row))
    end
    io.stderr:write(string.format("# %d rows of three columns from %s\n", #rows, file))
end

local USAGE = "usage: ./xmakew l frameworks/SwiftUI/tools/surface_rows.lua sdk WANT | tree | collapse OURS.tsv"

function main(action, argument)
    if action == "sdk" and argument then
        sdk_rows(argument)
    elseif action == "tree" and argument == nil then
        tree_rows()
    elseif action == "collapse" and argument then
        collapse(argument)
    else
        raise(USAGE)
    end
end
