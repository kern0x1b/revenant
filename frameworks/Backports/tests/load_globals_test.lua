local backports = path.absolute(path.join(os.scriptdir(), ".."))

local SUFFIXES = {"Key", "Keys", "Name", "Domain", "Number", "Reason", "Attribute", "Zero", "Exception", "Mode"}

local function without_comments_and_strings(text)
    text = text:gsub("//[^\n]*", "")
    return (text:gsub('"[^"\n]*"', '""'))
end

local function without_blocks(text)
    local out, i = {}, 1
    while i <= #text do
        local open = text:sub(i, i) == "^" and text:find("{", i, true)
        if open then
            local depth, j = 0, open
            repeat
                local c = text:sub(j, j)
                if c == "{" then
                    depth = depth + 1
                elseif c == "}" then
                    depth = depth - 1
                end
                j = j + 1
            until depth == 0 or j > #text
            i = j
        else
            table.insert(out, text:sub(i, i))
            i = i + 1
        end
    end
    return table.concat(out)
end

local function is_generated_global(name)
    if name:match("^k%u") then
        return true
    end
    if not name:match("^[A-Z][A-Z]") then
        return false
    end
    for _, suffix in ipairs(SUFFIXES) do
        if name:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

local function constants_in(text)
    local clean = without_blocks(without_comments_and_strings(text:gsub("BACKPORT_IMPL%(([%w_]+)%)", "__revenant_fb_%1")))
    local found = {}
    for start, name, finish in clean:gmatch("()([%a_][%w_]*)()") do
        local after = clean:sub(finish)
        local before = start > 1 and clean:sub(start - 1, start - 1) or ""
        local declared = after:match("^%s+[%*%a_]") ~= nil or after:match("^%*") ~= nil
        local member = before == "." or before == ">" or before == "@"
        if not declared and not member and is_generated_global(name) then
            found[name] = true
        end
    end
    return found
end

local function load_bodies(source)
    local bodies, body = {}, nil
    for line in (source .. "\n"):gmatch("(.-)\n") do
        if body then
            if line == "}" then
                table.insert(bodies, table.concat(body, "\n"))
                body = nil
            else
                table.insert(body, line)
            end
        elseif line:match("^%+ ?%(void%)load") then
            body = {}
        end
    end
    return bodies
end

local function definitions(source)
    local defs, name, body = {}, nil, {}
    for line in (source .. "\n"):gmatch("(.-)\n") do
        if name then
            if line == "}" then
                defs[name] = table.concat(body, "\n")
                name, body = nil, {}
            else
                table.insert(body, line)
            end
        else
            local found = line:match("^[%a_][%w_%s%*<>]*[%s%*]([%a_][%w_]*)%s*%(")
            if found and not line:find(";%s*$") then
                name = found
            end
        end
    end
    return defs
end

local function violations(file)
    local source = io.readfile(file)
    local defs = definitions(source)
    local found = {}
    for _, body in ipairs(load_bodies(source)) do
        local texts = {body}
        for callee in without_blocks(without_comments_and_strings(body)):gmatch("([%a_][%w_]*)%s*%(") do
            if defs[callee] then
                table.insert(texts, defs[callee])
            end
        end
        for _, text in ipairs(texts) do
            for name in pairs(constants_in(text)) do
                table.insert(found, name)
            end
        end
    end
    return found
end

local function empty(found)
    for _ in pairs(found) do
        return false
    end
    return true
end

assert(constants_in("[NSError setX:NSLocalizedDescriptionKey];").NSLocalizedDescriptionKey, "the scan misses a direct read in +load")
assert(constants_in("[NSProgress x:NSFoundationVersionNumber];").NSFoundationVersionNumber, "the scan misses a version read in +load")
assert(empty(constants_in("id b = ^{ return NSLocalizedDescriptionKey; };")), "the scan flags a read inside a block, which runs after the constructor")
assert(empty(constants_in("NSErrorUserInfoKey key = nil; NSString *name = @\"NSLocalizedDescriptionKey\";")), "the scan flags a declaration or a string")

local IMAGE = path.join(backports, "src", "Foundation")
local files = table.join2(os.files(path.join(IMAGE, "**.m")), os.files(path.join(IMAGE, "**.mm")))
assert(#files > 0, "no Backports sources found under src/Foundation")

local problems = {}
for _, file in ipairs(files) do
    for _, name in ipairs(violations(file)) do
        table.insert(problems, string.format("%s reads %s in +load", path.relative(file, backports), name))
    end
end
assert(#problems == 0, "a +load reads a generated global, which is still zero until the library's constructor runs: " .. table.concat(problems, "; "))

print(string.format("load_globals: no +load in %d sources of src/Foundation reads a generated global", #files))
