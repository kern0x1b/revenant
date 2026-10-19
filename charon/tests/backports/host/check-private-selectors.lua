-- Lua port of check-private-selectors.py, the same check with the same output and the same exit status.
--
--    xmake l tests/backports/host/check-private-selectors.lua [--prefix PREFIX]... [--source SOURCE]... <test object or binary> <port object>...
--
-- Check that every selector a host differential renames for its own port is one the port defines.
--
-- A differential compiles the backport's sources into the same process as the framework they sit beside, so
-- the port's classes and the selectors its categories carry are renamed and the test drives the port's answer
-- and the host's side by side. Nothing checks the two halves against each other: a selector the test declares
-- in its own category and calls, and that no port object defines, is a link-time no-op and an
-- "unrecognized selector sent to instance" at run time - after the build, and with nothing in the gate to see
-- it, because the gate reads the registry of what the backports carry, not what a test asks for.
--
-- So this asks the two binaries themselves. The test holds every selector it names as a string; the port
-- objects hold every selector they define in their method symbols. A string with one of the renaming prefixes
-- that no port object defines is the failure above, and it is reported with the selector and the objects it
-- was looked for in. Prefixes default to the four this tree renames with; a differential that renames with
-- another one passes it. `--source` names a source of the test, and a prefixed literal that source concatenates
-- (`[@"charonHostSet" stringByAppendingString:...]`) is a piece of a name rather than a name of its own, so it
-- is not judged: see fragments() for the measurement that made that distinction necessary.

local DEFAULT_PREFIXES = {"charonHost", "charonHost_", "charon_host_", "CharonHost"}

-- The first -[Class(Category) selector] or +[Class selector] on a line: the selector, or nil. The category part
-- is optional and the selector is what follows the single space.
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

-- A renamed class is a class, not a selector: the test holds its name as a string too, and it is answered.
local function class_symbol(stripped)
    return stripped:match("_OBJC_CLASS_%$_([%a_][%w_]*)$") or stripped:match("_OBJC_METACLASS_%$_([%a_][%w_]*)$")
end

-- A name a C symbol carries as well as a method does: dlsym(RTLD_DEFAULT, "CharonHostUICommandTagShare") finds a
-- renamed constant, which is what a test asks for when it looks a constant up that way.
local function defined_symbol(stripped)
    return stripped:match("^%x*%s*%a%s+_?([%a_][%w_:]*)$")
end

-- Every selector the objects define, whole, every selector they send, and every selector name they hold as a
-- string - which is how a test that builds a name at run time spells it.
local function selectors(paths)
    local defined, named, sent_by = {}, {}, {}
    for _, path in ipairs(paths) do
        -- a tool that fails stops the check: an object read as empty would pass as a clean run
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

-- Whether a string that starts with a prefix is a whole selector rather than a piece of one. A differential that
-- builds selector names at run time holds the prefix and the format in the test's strings, and those are not
-- selectors anything has to define.
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

-- The prefixed strings the sources build a longer name out of, which are not selectors of their own.
--
-- A differential that renames with a prefix often spells the name it sends at run time, and the pieces of it are
-- literals in the source: `[@"charonHostSet" stringByAppendingString:...]` builds
-- charonHostSetAllowsExpensiveNetworkAccess: and never sends the bare charonHostSet. The strings pass cannot tell
-- a whole selector from a piece of one - both are a token that starts with a prefix - so it reported "names the
-- selector charonHostSet, which none of ... defines", which is a name nothing sends. Only a literal the source
-- concatenates is dropped: every other prefixed string is judged as before, so a test that names a selector no
-- port object defines is still reported.
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

-- Parses the arguments the way argparse would: --prefix and --source take one value, either as the next word or
-- after an equals sign; everything else is an object, the test first.
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
    -- the status is the process's, as the Python tool's sys.exit was: a red run must fail the caller
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
    -- the test is asked what it names, every object is asked what it defines: a selector the test's own code
    -- defines is answered as legitimately as one the port's is
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
