-- The declaration a line of a `.swiftinterface` stands in.
--
-- A `.swiftinterface` is machine-formatted: a nested declaration is indented two spaces per level, and the
-- braces are not a reliable guide because an interface is one flat list of top-level declarations with
-- members indented under them. So the owner is a stack by **indentation**: a declaration at indent i pops
-- every entry whose indent is i or deeper and pushes itself; an attribute line and a `where` continuation
-- change nothing; and a member's owner is the joined names on the stack at that line.
--
-- An `extension X` pushes `X` with the module prefix dropped - `extension SwiftUICore.Image` is `Image`, and
-- `extension SwiftUI.Anchor.Source` is `Anchor.Source` - so a member of `Anchor.Source` is never filed under
-- `Anchor` and a member of a nested `ResizingMode` is `Image.ResizingMode`.

local text = import("lib.text", {rootdir = path.join(os.scriptdir(), ".."), anonymous = true})

local MODULES = {Swift = true, SwiftUI = true, SwiftUICore = true, Foundation = true, CoreGraphics = true,
    UIKit = true, Combine = true, Observation = true, CoreTransferable = true, DeveloperToolsSupport = true,
    Darwin = true, ObjectiveC = true}

-- The modifiers the declaration pattern takes, in no particular order: they are matched one after another
-- with nothing between them, as the pattern's `(?:...)*` has them. The attributes with an @ are the ones a
-- line can start with after the attribute group has taken what it takes.
local MODIFIERS = {"public", "open", "package", "@usableFromInline", "@inlinable", "@_alwaysEmitIntoClient",
    "@MainActor", "@preconcurrency", "nonisolated", "final", "indirect", "@frozen", "static"}

local KINDS = {"struct", "class", "enum", "protocol", "actor", "typealias", "extension"}

-- One attribute of the pattern's first group: `@name`, an optional `(...)` with no `)` inside, then whitespace.
-- Returns the position after it, or nil when the attribute does not match there.
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

-- The pattern itself, `DECL.match(stripped)`: returns the keyword and the name, or nil.
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
    -- not "starts with @": a declaration may carry its own attributes, and the pattern already allows them;
    -- `@frozen public enum Orientation` is a declaration, not an attribute
    if stripped == "" or text.startswith(stripped, "//") then
        return nil
    end
    local kind, name = declaration(stripped)
    if not kind then
        return nil
    end
    return kind, unmodule(name)
end

-- Every line of an interface, as {number, line, owner}; owner is the owner as written, or nil at top level.
--
-- A preprocessor line and an attribute line are neither a declaration nor a member: they must not push and
-- must not pop, and `#if compiler(...)` in particular sits at the indent of the block it guards, so treating
-- it as one closes the block above it.
function walk(lines)
    local stack = {}
    local out = {}
    for number, line in ipairs(lines) do
        local indent = indent_of(line)
        local stripped = text.strip(line)
        local preprocessor = text.startswith(stripped, "#")
        local attribute = text.startswith(stripped, "@")
        -- a line may begin with an attribute and still be the declaration itself: `@frozen public enum
        -- Orientation` is one, and reading it as an attribute left the stack on `Image`
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
