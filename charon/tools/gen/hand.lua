local layout = import("layout", {anonymous = true})
local strings = import("strings", {anonymous = true})
local decl = import("decl", {anonymous = true})
local files = import("files", {anonymous = true})

local SOURCES_ROOT = layout.constants().SOURCES_ROOT
local IMPLEMENTATION_SKIP = strings.set({".gen", "spec", "registry", "facts", "overrides", "gen"})
local CLASS_SKIP = strings.set({".gen", "spec", "overrides", "registry", ".agent-work"})

local memo = {}

local function sources(root, skip, with_c)
    local found = {}
    local function walk(dir)
        for _, filepath in ipairs(files.glob(path.join(dir, "*"))) do
            if string.match(filepath, "%.mm?$") or (with_c and string.match(filepath, "%.c$")) then
                table.insert(found, filepath)
            end
        end
        for _, sub in ipairs(os.dirs(path.join(dir, "*"))) do
            if not skip[path.filename(sub)] and not os.islink(sub) then
                walk(sub)
            end
        end
    end
    walk(root)
    return found
end

local function class_names_in(text, names)
    local pos = 1
    while true do
        local at = string.find(text, "@implementation", pos, true)
        if at == nil then
            return
        end
        local name, after = string.match(text, "^%s+([%w_]+)()", at + 15)
        if name then
            local first = string.match(text, "^%s*()", after)
            local run = string.sub(text, after, first - 1)
            local nextc = string.sub(text, first, first)
            if string.find(run, "\n", 1, true) or nextc == "{" or nextc == "" then
                names[name] = true
            end
        end
        pos = at + 1
    end
end

local function is_word_after(line, i)
    local c = string.sub(line, i, i)
    return c ~= "" and string.find(c, "[%w_]") ~= nil
end

local function add_selector(found, cls, selector)
    if selector ~= nil and selector ~= "" then
        found[cls] = found[cls] or {}
        found[cls][selector] = true
    end
end

local function implementations_in(text, found)
    local current, signature = nil, nil
    for _, line in ipairs(strings.lines(text)) do
        if signature ~= nil then
            signature = signature .. " " .. strings.strip(line)
            if string.find(line, "{", 1, true) or string.find(line, ";", 1, true) then
                add_selector(found, current, decl.selector_of(strings.before(strings.before(signature, "{"), ";")))
                signature = nil
            end
        else
            local cls = string.match(line, "^%s*@implementation%s+([%w_]+)")
            local endstop = string.match(line, "^%s*@end()")
            if cls then
                current = cls
            elseif endstop and not is_word_after(line, endstop) then
                current = nil
            elseif current ~= nil then
                local name = string.match(line, "^%s*@synthesize%s+([%w_]+)") or string.match(line, "^%s*@dynamic%s+([%w_]+)")
                if name then
                    found[current] = found[current] or {}
                    found[current][name] = true
                end
                if string.match(line, "^%s*[%-%+]%s*%(") then
                    if string.find(line, "{", 1, true) or string.find(line, ";", 1, true) then
                        add_selector(found, current, decl.selector_of(strings.before(strings.before(line, "{"), ";")))
                    else
                        signature = strings.strip(line)
                    end
                end
            end
        end
    end
end

local function defined_name(head)
    if string.match(head, "^%s*static%f[^%w_]") or string.match(head, "^%s*typedef%f[^%w_]") or string.find(head, "=", 1, true) then
        return nil
    end
    if string.find(head, "(", 1, true) == nil then
        return nil
    end
    local lead, name = string.match(strings.before(head, "("), "^(.-)([%a_][%w_]*)%s*$")
    if name and string.match(lead, "[%a_%*]") then
        return name
    end
    return nil
end

local function functions_in(text, found)
    local signature = nil
    for _, line in ipairs(strings.lines(text)) do
        if signature ~= nil then
            signature = signature .. " " .. strings.strip(line)
        elseif string.match(line, "^[%a_]") then
            signature = strings.strip(line)
        end
        if signature ~= nil and (string.find(signature, "{", 1, true) or string.find(signature, ";", 1, true)) then
            local at = string.find(signature, "[{;]")
            local name = string.sub(signature, at, at) == "{" and defined_name(string.sub(signature, 1, at - 1)) or nil
            if name ~= nil then
                found[name] = true
            end
            signature = nil
        end
    end
end

local function state(tree)
    if memo[tree] == nil then
        memo[tree] = {}
    end
    return memo[tree]
end

function implementations(tree)
    local cache = state(tree)
    if cache.implementations == nil then
        local found = {}
        for _, filepath in ipairs(sources(path.join(tree, SOURCES_ROOT), IMPLEMENTATION_SKIP)) do
            implementations_in(strings.universal(files.read_text(filepath)), found)
        end
        cache.implementations = found
    end
    return cache.implementations
end

function class_names(tree)
    local cache = state(tree)
    if cache.classes == nil then
        local names = {}
        for _, filepath in ipairs(sources(path.join(tree, SOURCES_ROOT), CLASS_SKIP)) do
            class_names_in(strings.universal(files.read_text(filepath)), names)
        end
        cache.classes = names
    end
    return cache.classes
end

function functions(tree)
    local cache = state(tree)
    if cache.functions == nil then
        local found = {}
        for _, filepath in ipairs(sources(path.join(tree, SOURCES_ROOT), IMPLEMENTATION_SKIP, true)) do
            functions_in(strings.universal(files.read_text(filepath)), found)
        end
        cache.functions = found
    end
    return cache.functions
end
