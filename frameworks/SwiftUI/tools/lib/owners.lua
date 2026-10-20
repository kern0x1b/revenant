local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local MODULES = {Swift = true, SwiftUI = true, SwiftUICore = true, Foundation = true, CoreGraphics = true,
    UIKit = true, Combine = true, Observation = true, CoreTransferable = true, DeveloperToolsSupport = true,
    Darwin = true, ObjectiveC = true}

local MODIFIERS = {"public", "open", "package", "@usableFromInline", "@inlinable", "@_alwaysEmitIntoClient",
    "@MainActor", "@preconcurrency", "nonisolated", "final", "indirect", "@frozen", "static"}

local KINDS = {"struct", "class", "enum", "protocol", "actor", "typealias", "extension"}

local function attribute_end(s, pos)
    local _, e = string.find(s, "^@[%w_]+", pos)
    if not e then
        return nil
    end
    local _, paren = string.find(s, "^%([^%)]*%)", e + 1)
    if paren then
        e = paren
    end
    local _, space = string.find(s, "^%s+", e + 1)
    return space and space + 1 or nil
end

local function declaration(s)
    local pos = 1
    local attribute = attribute_end(s, pos)
    while attribute do
        pos = attribute
        attribute = attribute_end(s, pos)
    end
    local matched = true
    while matched do
        matched = false
        for _, modifier in ipairs(MODIFIERS) do
            if text.startswith(s, modifier, pos) then
                pos = pos + #modifier
                matched = true
                break
            end
        end
    end
    local _, space = string.find(s, "^%s*", pos)
    pos = space + 1
    for _, kind in ipairs(KINDS) do
        if text.startswith(s, kind, pos) then
            local _, after = string.find(s, "^%s+", pos + #kind)
            if after then
                local name = string.match(s, "^([%w_%.]+)", after + 1)
                if name then
                    return kind, name
                end
            end
            return nil
        end
    end
    return nil
end

function unmodule(name)
    local parts = text.split(name, ".")
    if MODULES[parts[1]] then
        local rest = {}
        for i = 2, #parts do
            rest[#rest + 1] = parts[i]
        end
        return text.join(".", rest)
    end
    return name
end

function indent_of(line)
    if not string.find(line, "%S") then
        return nil
    end
    return #string.match(line, "^ *")
end

function is_declaration(line)
    local stripped = text.strip(line)
    if stripped == "" or text.startswith(stripped, "//") then
        return nil
    end
    local kind, name = declaration(stripped)
    if not kind then
        return nil
    end
    return kind, unmodule(name)
end

function walk(lines)
    local stack = {}
    local out = {}
    for number, line in ipairs(lines) do
        local indent = indent_of(line)
        local stripped = text.strip(line)
        local preprocessor = text.startswith(stripped, "#")
        local attribute = text.startswith(stripped, "@")
        local kind, name = nil, nil
        if not preprocessor then
            kind, name = is_declaration(line)
        end
        attribute = attribute and kind == nil
        local owner
        if kind and indent ~= nil then
            while #stack > 0 and stack[#stack].indent >= indent do
                stack[#stack] = nil
            end
            stack[#stack + 1] = {indent = indent, name = name}
        else
            if indent ~= nil and not preprocessor and not attribute then
                while #stack > 0 and stack[#stack].indent >= indent do
                    stack[#stack] = nil
                end
            end
        end
        if #stack > 0 then
            local names = {}
            for _, entry in ipairs(stack) do
                names[#names + 1] = entry.name
            end
            owner = text.join(".", names)
        end
        out[#out + 1] = {number = number, line = line, owner = owner}
    end
    return out
end
