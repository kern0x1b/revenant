local RAISE_HEAD = "[NSException raise:NSInternalInconsistencyException"
local RAISE_TAIL = "^%s*\n[ \t]*format:@\"%-init results in undefined behavior for NSBatchInsertRequest\"%];"
local RAISE_REPLACEMENT = "    return [super init];"

local IVAR_ANCHORS = {
    {
        which = "Dictionary",
        anchor = "        _revenantEntityName = [entity.name copy];\n        _revenantDictionaryHandler = [handler copy];\n",
        name = "_revenantManagedObjectHandler",
        wrong = "        _revenantManagedObjectHandler = [handler copy];\n",
    },
    {
        which = "ManagedObject",
        anchor = "        _revenantEntityName = [entity.name copy];\n        _revenantManagedObjectHandler = [handler copy];\n",
        name = "_revenantDictionaryHandler",
        wrong = "        _revenantDictionaryHandler = [handler copy];\n",
    },
}

local function count_plain(text, needle)
    local found, at = 0, 1
    while true do
        local first, last = text:find(needle, at, true)
        if not first then
            return found
        end
        found = found + 1
        at = last + 1
    end
end

local function show_diff(source, output)
    os.execv("diff", {"-u", source, output}, {try = true})
end

local function mutate_init(source, output)
    local text = io.readfile(source, {encoding = "binary"})
    local matches = {}
    local at = 1
    while true do
        local first = text:find(RAISE_HEAD, at, true)
        if not first then
            break
        end
        local start = first
        while start > 1 and text:sub(start - 1, start - 1):match("[ \t]") do
            start = start - 1
        end
        local _, last = text:find(RAISE_TAIL, first + #RAISE_HEAD)
        if last then
            table.insert(matches, {start = start, last = last})
        end
        at = first + #RAISE_HEAD
    end
    if #matches ~= 1 then
        raise("mutant-init: found %d occurrences of the raise, and exactly one is required", #matches)
    end
    local hit = matches[1]
    print("mutant-init: the ONE statement it replaces, exactly:")
    local shown = text:sub(hit.start, hit.last)
    local at = 1
    while at <= #shown + 1 do
        local newline = shown:find("\n", at, true) or (#shown + 1)
        print("    | " .. shown:sub(at, newline - 1))
        at = newline + 1
    end
    io.writefile(output, text:sub(1, hit.start - 1) .. RAISE_REPLACEMENT .. text:sub(hit.last + 1), {encoding = "binary"})
    show_diff(source, output)
end

local function mutate_ivar(source, output)
    local text = io.readfile(source, {encoding = "binary"})
    local found = {}
    for _, item in ipairs(IVAR_ANCHORS) do
        local hits = count_plain(text, item.anchor)
        if hits ~= 1 then
            raise("mutant-ivar: the %s initialiser's anchor is in the source %d times, and once is required", item.which, hits)
        end
        table.insert(found, item)
    end
    for _, item in ipairs(found) do
        local _, last = text:find(item.anchor, 1, true)
        text = text:sub(1, last) .. item.wrong .. text:sub(last + 1)
        print(string.format("mutant-ivar: %s initialiser now sets %s as well", item.which, item.name))
    end
    io.writefile(output, text, {encoding = "binary"})
    show_diff(source, output)
end

function main(command, source, output)
    if command == "init" then
        mutate_init(source, output)
    elseif command == "ivar" then
        mutate_ivar(source, output)
    else
        raise("usage: mutants.lua init|ivar <source> <output>")
    end
end
