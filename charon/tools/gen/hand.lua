-- The hand-written sources of the package, read once per tree: the methods and synthesized or dynamic properties the hand code
-- defines (a stub must not replace them), the classes it defines with @implementation (the trace layer generates no class
-- object for them), and the C functions it defines (a stub must not replace them either). The scans leave different directories
-- out, as the oracle's do, and each keeps its own list.

local layout = import("layout", {anonymous = true})
local strings = import("strings", {anonymous = true})
local decl = import("decl", {anonymous = true})
local files = import("files", {anonymous = true})

-- The package's root, where the hand sources are (SOURCES_ROOT of tools/gen.py@52253c0650).
local SOURCES_ROOT = layout.constants().SOURCES_ROOT
-- The directories the implementation scan leaves out, at every level.
local IMPLEMENTATION_SKIP = strings.set({".gen", "spec", "registry", "facts", "overrides", "gen"})
-- The directories the class scan leaves out, at every level.
local CLASS_SKIP = strings.set({".gen", "spec", "overrides", "registry", ".agent-work"})

local memo = {}

-- The paths of the .m and .mm files under a directory (and its .c files when with_c), the directories named in skip left out at every
-- level. A symbolic link to a directory is not entered, as os.walk does not enter one.
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

-- The class names an @implementation names in a text: the name must be followed, after whitespace that may run over lines, by a
-- line break, by { or by the end of the text (the lookahead of the oracle's regular expression).
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

-- True when the character at position i of the line is a word character (the \b after an @end).
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

-- The methods, synthesized and dynamic properties one source defines, into found (cls -> selector -> true). A method signature
-- spans lines until its brace or semicolon.
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

-- The name of the function a definition's head names (its text before the first brace): the identifier before the first parenthesis,
-- which a return type comes before. nil for a static or typedef head, an assignment, and a head with no parameter list or no type.
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

-- The non-static C functions one source defines into found (name -> true). A definition's signature starts at a line's start and spans
-- the lines until its first brace or semicolon: a brace makes it a definition, a semicolon a prototype.
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

-- cls -> set of selectors (and synthesized or dynamic property names) the hand sources of the package define.
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

-- The set of class names the hand sources of the package define with @implementation.
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

-- The set of C function names the hand sources of the package define (not static): name -> true. The .c files are scanned too.
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
