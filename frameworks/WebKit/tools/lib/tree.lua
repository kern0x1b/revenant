function member(...)
    return path.join(path.normalize(path.absolute(path.join(os.scriptdir(), "..", ".."))), ...)
end

function revenant(...)
    return path.join(path.normalize(path.join(member(), "..", "..")), ...)
end

function modules(name)
    return import(name, {rootdir = member("modules"), anonymous = true})
end

function where(name)
    local found = os.iorunv(os.programfile(), {"where", "-P", revenant(), name}, {curdir = revenant()}):trim()
    local last
    for line in found:gmatch("[^\n]+") do
        last = line:trim()
    end
    if not last or not os.isdir(last) then
        raise("xmake where %s answered %s, which is not a folder; configure for iphoneos and install the packages first", name, found)
    end
    return last
end

function engine_source(given)
    if given then
        return path.absolute(given)
    end
    return path.join(where("webkit"), "src")
end

function patches()
    return revenant("third_party", "webkit", "patches")
end

function recipe()
    return revenant("third_party", "webkit", "xmake.lua")
end

function arguments(argv, flags)
    local found, rest = {}, {}
    local index = 1
    while index <= #argv do
        local given = argv[index]
        local name = given:match("^%-%-([%w%-]+)$")
        if name and flags[name] == "value" then
            found[name] = assert(argv[index + 1], "--" .. name .. " takes a value")
            index = index + 2
        elseif name and flags[name] == "switch" then
            found[name] = true
            index = index + 1
        elseif name then
            raise("unknown option --%s", name)
        else
            table.insert(rest, given)
            index = index + 1
        end
    end
    return found, rest
end
