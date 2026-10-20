local text = import("lib.text", {rootdir = os.scriptdir(), anonymous = true})
local tree = import("lib.tree", {rootdir = os.scriptdir(), anonymous = true})

local function sdk_path()
    return tree.sdk()
end

local KEEP_PREFIXES = {"public ", "@availability", "@_availability", "@MainActor", "@Sendable", "@preconcurrency",
    "@ViewBuilder", "@frozen", "@inlinable", "static ", "mutating ", "nonisolated "}
local KEEP_KEYWORDS = {"func", "var", "let", "init", "subscript", "typealias", "associatedtype", "case"}

local function keep(line)
    local _, spaces = string.find(line, "^%s*")
    local pos = spaces + 1
    local moved = true
    while moved do
        moved = false
        for _, prefix in ipairs(KEEP_PREFIXES) do
            if text.startswith(line, prefix, pos) then
                pos = pos + #prefix
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

local SKIP_PREFIXES = {"get", "set", "_read", "_modify", "return", "{", "}", "#if", "#endif", "@_Concurrency",
    "@_transparent", "@usableFromInline", "@_opaqueReturnTypeOf"}

local function skip(line)
    local _, spaces = string.find(line, "^%s*")
    for _, prefix in ipairs(SKIP_PREFIXES) do
        if text.startswith(line, prefix, spaces + 1) then
            return true
        end
    end
    return false
end

local function blocks(file)
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

local function view_extension(head)
    local from = 1
    while true do
        local at = string.find(head, "extension ", from, true)
        if not at then
            return false
        end
        local start = at + 10
        local candidates = {start}
        if text.startswith(head, "SwiftUI.", start) then
            candidates[#candidates + 1] = start + 8
        end
        for _, c in ipairs(candidates) do
            if text.startswith(head, "View", c) and not text.is_word(head, c + 4) then
                return true
            end
            if text.startswith(head, "some SwiftUI.View", c) and not text.is_word(head, c + 17) then
                return true
            end
        end
        from = at + 1
    end
end

local DECL_KINDS = {"struct", "class", "enum", "protocol", "extension"}

local function declared_name(head)
    for at = 1, #head do
        for _, kind in ipairs(DECL_KINDS) do
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

local function last_component(name)
    local parts = text.split(name, ".")
    return parts[#parts]
end

function main(...)
    local args = {...}
    local root = sdk_path()
    local frameworks = path.join(root, "System", "Library", "Frameworks")
    local interfaces = {
        {path.join(frameworks, "SwiftUI.framework", "Modules", "SwiftUI.swiftmodule", "arm64e-apple-ios.swiftinterface"), "SwiftUI"},
        {path.join(frameworks, "SwiftUICore.framework", "Modules", "SwiftUICore.swiftmodule", "arm64e-apple-ios.swiftinterface"), "Core"},
    }
    local all = {}
    for _, interface in ipairs(interfaces) do
        for _, block in ipairs(blocks(interface[1])) do
            all[#all + 1] = {head = block.head, body = block.body, module = interface[2]}
        end
    end

    if args[1] == "--view" then
        local needle = args[2]
        for _, block in ipairs(all) do
            if view_extension(block.head) then
                for _, line in ipairs(block.body) do
                    if string.find(line, needle, 1, true) and keep(line) and not skip(line) then
                        print(text.strip(line))
                    end
                end
            end
        end
        return
    end

    if args[1] == "--grep" then
        local needle = args[2]
        for _, block in ipairs(all) do
            local hit = string.find(block.head, needle, 1, true) ~= nil
            for _, line in ipairs(block.body) do
                if string.find(line, needle, 1, true) then
                    hit = true
                end
            end
            if hit then
                print("--- " .. string.sub(block.head, 1, 150))
                for _, line in ipairs(block.body) do
                    if keep(line) and not skip(line) then
                        print("    " .. text.strip(line))
                    end
                end
            end
        end
        return
    end

    local names = {}
    for _, a in ipairs(args) do
        names[a] = true
    end
    local seen = {}
    for _, block in ipairs(all) do
        local name = declared_name(block.head)
        if name and names[last_component(name)] then
            local key = name .. "\t" .. string.sub(block.head, 1, 60)
            if not seen[key] then
                seen[key] = true
                print("--- [" .. block.module .. "] " .. string.sub(block.head, 1, 200))
                for _, line in ipairs(block.body) do
                    if keep(line) and not skip(line) then
                        print("    " .. text.strip(line))
                    end
                end
            end
        end
    end
end
