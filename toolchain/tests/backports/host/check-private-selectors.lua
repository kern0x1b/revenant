local DEFAULT_PREFIXES = {"charonHost", "charonHost_", "charon_host_", "CharonHost"}

local function defined_selector(line)
    for sign_at in line:gmatch("()[-+]%[") do
        local at = sign_at + 2
        local class = line:match("^[%a_][%w_]*", at)
        if class then
            at = at + #class
            local category = line:match("^%([%w_]*%)", at)
            if category then
                at = at + #category
            end
            if line:sub(at, at) == " " then
                local selector = line:match("^[%a_][%w_:]*", at + 1)
                if selector and line:sub(at + 1 + #selector, at + 1 + #selector) == "]" then
                    return selector
                end
            end
        end
    end
    return nil
end

local function class_symbol(stripped)
    return stripped:match("_OBJC_CLASS_%$_([%a_][%w_]*)$") or stripped:match("_OBJC_METACLASS_%$_([%a_][%w_]*)$")
end

local function defined_symbol(stripped)
    return stripped:match("^%x*%s*%a%s+_?([%a_][%w_:]*)$")
end

local function selectors(paths)
    local defined, named, sent_by = {}, {}, {}
    for _, path in ipairs(paths) do
        local symbols = os.iorunv("xcrun", {"nm", path})
        do
            for line in symbols:gmatch("[^\n]+") do
                local stripped = line:match("^%s*(.-)%s*$")
                local exported = defined_symbol(stripped)
                if exported then
                    defined[exported] = true
                end
                local selector = defined_selector(line)
                if selector then
                    defined[selector] = true
                end
                local class = class_symbol(stripped)
                if class then
                    defined[class] = true
                end
                local sent = stripped:match("_objc_msgSend%$([%a_][%w_:]*)")
                if sent then
                    sent_by[sent] = true
                end
            end
        end
        local strings = os.iorunv("xcrun", {"strings", "-a", path})
        for word in strings:gmatch("%S+") do
            named[word] = true
        end
    end
    return defined, named, sent_by
end

local function whole(name, prefixes)
    for _, prefix in ipairs(prefixes) do
        if name:sub(1, #prefix) == prefix and #name > #prefix then
            if name:find("%", 1, true) or name:find("@", 1, true) then
                return false
            end
            if name:find(":", 1, true) then
                return true
            end
            local rest = name:sub(#prefix + 1)
            return prefix:sub(-1) == "_" or rest:sub(1, 1):match("%u") ~= nil
        end
    end
    return false
end

local function fragments(sources)
    local found = {}
    for _, path in ipairs(sources) do
        local text = os.isfile(path) and io.readfile(path) or ""
        local pos = 1
        while true do
            local _, last, name = text:find('@"([%a_][%w_]*)"', pos)
            if not last then
                break
            end
            if text:match("^%s*stringByAppending", last + 1) then
                found[name] = true
            end
            pos = last + 1
        end
    end
    return found
end

local function set_of(keys)
    local out = {}
    for key in pairs(keys) do
        table.insert(out, key)
    end
    table.sort(out)
    return out
end

local function parse(args)
    local options = {prefix = {}, source = {}, objects = {}}
    local index = 1
    while index <= #args do
        local word = args[index]
        local name, value = word:match("^%-%-(%a+)=(.*)$")
        if not name then
            name = word:match("^%-%-(%a+)$")
        end
        if name == "prefix" or name == "source" then
            if not value then
                index = index + 1
                value = args[index]
                if value == nil then
                    error(name .. " needs a value")
                end
            end
            table.insert(options[name], value)
        else
            table.insert(options.objects, word)
        end
        index = index + 1
    end
    return options
end

function main(...)
    os.exit(check(parse({...})))
end

function check(options)
    if #options.objects < 2 then
        raise("a test and at least one port object, so there is something to compare")
    end
    local prefixes = {}
    for _, prefix in ipairs(options.prefix) do
        table.insert(prefixes, prefix)
    end
    for _, prefix in ipairs(DEFAULT_PREFIXES) do
        table.insert(prefixes, prefix)
    end
    local defined, named, sent_by = selectors(options.objects)
    local pieces = fragments(options.source)
    local renamed = {}
    for name in pairs(sent_by) do
        if whole(name, prefixes) then
            renamed[name] = true
        end
    end
    for name in pairs(named) do
        if whole(name, prefixes) then
            renamed[name] = true
        end
    end
    local renamed_count = 0
    for _ in pairs(renamed) do
        renamed_count = renamed_count + 1
    end
    local wanted = {}
    for name in pairs(renamed) do
        if not defined[name] and not pieces[name] then
            wanted[name] = true
        end
    end
    local wanted_list = set_of(wanted)
    if #wanted_list == 0 then
        print(string.format("note %d renamed selectors are named, all of them defined by %s",
                            renamed_count, table.concat(options.objects, ", ")))
        return 0
    end
    for _, name in ipairs(wanted_list) do
        print(string.format("FAIL %s names the selector %s, which none of %s defines: it would be an unrecognized selector at run time",
                            options.objects[1], name, table.concat(options.objects, ", ")))
    end
    print(string.format("%d of the %d renamed selectors are named and not defined", #wanted_list, renamed_count))
    return 1
end
