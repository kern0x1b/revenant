function paths(directory)
    local member = path.normalize(path.absolute(path.join(directory, "..", "..")))
    local revenant = path.normalize(path.join(member, "..", ".."))
    return {
        member = function (...) return path.join(member, ...) end,
        revenant = function (...) return path.join(revenant, ...) end
    }
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
